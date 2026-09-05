#!/usr/bin/env python3
"""Link cktk from one full checkout and diagnose installed skill provenance."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


DEFAULT_SOURCE = Path(__file__).resolve().parent.parent


def run(*args, cwd=None):
    # Some CLI runtimes exit before a large pipe-backed stdout has flushed.
    with tempfile.TemporaryFile(mode="w+") as output:
        subprocess.run(args, cwd=cwd, text=True, stdout=output, stderr=subprocess.PIPE, timeout=30, check=True)
        output.seek(0)
        return output.read().strip()


def read_json(path):
    return json.loads(path.read_text())


def is_checkout(path):
    try:
        return (read_json(path / "catalog.json")["name"] == "cktk"
                and read_json(path / ".claude-plugin/plugin.json")["name"] == "cktk")
    except (OSError, ValueError, KeyError, TypeError):
        return False


def owned_target(path):
    """Recognize a real cktk tree, never ownership from a skill name alone."""
    resolved = path.resolve()
    for parent in resolved.parents:
        if is_checkout(parent):
            relative = resolved.relative_to(parent)
            return relative.parts[0] in {"skills", ".agents", ".agent"}
    return False


def digest(path):
    """Hash payload bytes and executable bits, following shared resources."""
    result = hashlib.sha256()
    for directory, children, files in os.walk(path, followlinks=True):
        children.sort()
        for name in sorted(files):
            item = Path(directory) / name
            result.update(str(item.relative_to(path)).encode())
            result.update(bytes([bool(item.stat().st_mode & 0o111)]))
            result.update(item.read_bytes())
    return result.hexdigest()


def version(source):
    try:
        revision = run("git", "-C", str(source), "rev-parse", "HEAD")
        dirty = bool(run("git", "-C", str(source), "status", "--porcelain"))
    except (OSError, subprocess.SubprocessError):
        revision, dirty = None, None
    return {"revision": revision, "dirty": dirty, "payload_sha256": digest(source / "skills")}


def locations(home, isolated):
    def configured(key, default):
        return Path(os.environ.get(key, str(default))).expanduser() if not isolated else default
    return {
        "shared": home / ".agents/skills",
        "claude": home / ".claude/skills",
        "codex": configured("CODEX_HOME", home / ".codex") / "skills",
        "antigravity": configured("AGENT_HOME", home / ".agent") / "skills",
        "opencode": configured("OPENCODE_HOME", home / ".config/opencode") / "skills",
        "grok": home / ".grok/skills",
        "opencode_legacy": home / ".opencode/skills",
        "bin": home / ".local/bin",
    }


def source_skills(source):
    if not is_checkout(source):
        raise ValueError(f"not a full cktk checkout: {source}")
    skills = read_json(source / "catalog.json")["skills"]
    for skill in skills:
        name = skill["name"]
        for tree in ("skills", ".agents/skills", ".agent/skills"):
            if not (source / tree / name / "SKILL.md").is_file():
                raise ValueError(f"missing source: {tree}/{name}/SKILL.md")
        if skill.get("portable") and (source / ".agents/skills" / name).resolve() != source / "skills" / name:
            raise ValueError(f"portable Codex folder is not linked to its canonical source: {name}")
    return skills


def desired_links(source, paths, skills, mode="linked"):
    links, obsolete = {}, []
    for skill in skills:
        name = skill["name"]
        canonical = source / "skills" / name
        # These native compatibility entries are superseded by shared/Claude discovery.
        obsolete.extend(paths[key] / name for key in ("grok", "opencode_legacy"))
        if mode == "linked":
            links[paths["claude"] / name] = canonical
        else:
            obsolete.append(paths["claude"] / name)
        if skill.get("portable"):
            links[paths["shared"] / name] = canonical
            obsolete.extend(paths[key] / name for key in ("codex", "opencode"))
        else:
            links[paths["codex"] / name] = source / ".agents/skills" / name
            links[paths["opencode"] / name] = canonical
            obsolete.append(paths["shared"] / name)
    agy = paths["antigravity"]
    if not agy.exists() or agy.is_symlink():
        links[agy] = source / ".agent/skills"
    else:
        links.update({agy / s["name"]: source / ".agent/skills" / s["name"] for s in skills})
    for command, relative in {
        "codex-handoff": "codex-handoff/scripts/codex-handoff.sh",
        "grok-handoff": "grok-handoff/scripts/grok-handoff.sh",
        "opencode-handoff": "opencode-handoff/scripts/opencode-handoff.sh",
        "cktk-takeover": "takeover/scripts/find-handoff.sh",
    }.items():
        links[paths["bin"] / command] = source / "skills" / relative
    # A configured native root may itself be the shared root.
    return links, [p for p in obsolete if p not in links]


def same_link(destination, source):
    return destination.is_symlink() and destination.resolve() == source.resolve()


def replaceable(destination, source, receipt):
    if destination.is_symlink():
        recorded = receipt.get("links", {}).get(str(destination))
        return owned_target(destination) or str(destination.readlink()) == recorded
    # Existing copies are replaceable only when their entire payload matches.
    return (source is not None and destination.is_dir() and source.is_dir()
            and digest(destination) == digest(source))


def project_ignore(project):
    if not project:
        return
    try:
        root = Path(run("git", "-C", str(project), "rev-parse", "--show-toplevel"))
    except subprocess.SubprocessError:
        return
    path = root / ".gitignore"
    for entry in (".ai/handoffs/", ".ai/interactions/"):
        check = subprocess.run(["git", "-C", str(root), "check-ignore", "-q", entry], capture_output=True)
        if check.returncode == 1:
            previous = path.read_text() if path.exists() else ""
            path.write_text(previous + ("\n" if previous and not previous.endswith("\n") else "") + entry + "\n")
            print(f"Project ignore: added {entry} to {path}")
        elif check.returncode != 0:
            raise ValueError(f"cannot inspect ignore rules in {root}")


def install(source, paths, skills, receipt, state_path, project, mode):
    links, obsolete = desired_links(source, paths, skills, mode)
    changes, conflicts = [], []
    for destination, target in list(links.items()) + [(p, None) for p in obsolete]:
        exists = destination.exists() or destination.is_symlink()
        if target and not target.exists():
            conflicts.append(f"missing source: {target}")
        elif target and same_link(destination, target):
            continue
        elif not exists and target is None:
            continue
        elif exists and not any(replaceable(destination, candidate, receipt) for candidate in (
                (target,) if target else (source / "skills" / destination.name, source / ".agents/skills" / destination.name))):
            conflicts.append(f"refusing to replace unverified path: {destination}")
        else:
            # Do not write through a user-managed aggregate link into another tree.
            linked_parent = next((p for p in destination.parents if p.is_symlink()), None)
            if linked_parent:
                conflicts.append(f"destination parent is a symlink; use a dedicated skill directory: {linked_parent}")
            else:
                changes.append((destination, target))
    if conflicts:
        raise ValueError("\n".join(conflicts) + "\nNo installation paths were changed.")

    state_path.parent.mkdir(parents=True, exist_ok=True)
    backup = None
    for destination, target in changes:
        destination.parent.mkdir(parents=True, exist_ok=True)
        if destination.is_symlink():
            destination.unlink()
        elif destination.exists():
            if backup is None:
                backup = Path(tempfile.mkdtemp(prefix="copies-", dir=state_path.parent))
            shutil.move(str(destination), str(backup / f"{len(list(backup.iterdir()))}-{destination.name}"))
        if target:
            destination.symlink_to(target, target_is_directory=target.is_dir())

    state = {"format": 1, "mode": mode, "source_root": str(source), **version(source),
             "links": {str(p): str(p.readlink()) for p in links},
             "locations": {key: str(path) for key, path in paths.items()}}
    with tempfile.NamedTemporaryFile(mode="w", dir=state_path.parent, delete=False) as handle:
        json.dump(state, handle, indent=2)
        handle.write("\n")
    os.replace(handle.name, state_path)
    project_ignore(project)
    portable = sum(bool(s.get("portable")) for s in skills)
    print(f"Source: {source}\nPortable skills: {portable} shared workflows under {paths['shared']}")
    print(f"Claude skills: {len(skills)} ({mode}); Codex skills: {portable} shared + {len(skills)-portable} native")
    print(f"OpenCode/Grok: shared discovery; Antigravity skills: {len(skills)}; Shell helpers: 4")
    print(f"Reconciled {len(changes)} path(s). Source receipt: {state_path}")
    if backup:
        print(f"Replaced identical copies were preserved in {backup}")
    if str(paths["bin"]) not in os.environ.get("PATH", "").split(os.pathsep):
        print(f"{paths['bin']} is not currently in PATH; add it to your shell profile.")


def doctor(source, paths, skills, receipt, state_path):
    links, obsolete = desired_links(source, paths, skills, receipt.get("mode", "linked"))
    problems = []
    if not receipt:
        problems.append(f"no registered source; run install: {state_path}")
    elif Path(receipt["source_root"]).resolve() != source:
        problems.append(f"registered source differs: {receipt['source_root']}")
    for destination, target in links.items():
        if not same_link(destination, target):
            problems.append(f"missing or different source: {destination} (expected {target})")
    for path in obsolete:
        if path.exists() or path.is_symlink():
            problems.append(f"duplicate skill entry: {path} -> {path.resolve()}")
    current = version(source)
    print(f"Source: {source}\nRevision: {current['revision']} (dirty={current['dirty']})")
    print(f"Skill payload SHA-256: {current['payload_sha256']}")
    for skill in skills:
        if skill.get("portable"):
            print(f"{skill['name']}: {source / 'skills' / skill['name']}")
    for problem in problems:
        print(f"ERROR: {problem}")
    print(f"Filesystem doctor: {len(problems)} problem(s). Use --runtime to inspect enabled host/plugin sources.")
    return problems


def runtime_doctor(source, skills, mode):
    """Read host inventories, emitting only relevant skill provenance."""
    names = {s["name"] for s in skills if s.get("portable")}
    problems = []
    unavailable = [cli for cli in ("claude", "grok", "opencode") if not shutil.which(cli)]
    if unavailable:
        print(f"UNVERIFIED (CLI unavailable): {', '.join(unavailable)}")
    if shutil.which("claude"):
        entries = json.loads(run("claude", "plugin", "list", "--json"))
        active = 0
        for entry in entries:
            if entry.get("id") != "cktk@cktk" or not entry.get("enabled"):
                continue
            active += 1
            path = Path(entry["installPath"]) / "skills"
            if mode == "linked" or digest(path) != digest(source / "skills"):
                problem = f"enabled cktk Claude plugin ({entry.get('scope')}): {entry.get('installPath')}; conflicts with {mode} source"
                problems.append(problem)
        if mode == "plugin" and not active:
            problems.append("plugin mode has no enabled cktk Claude plugin in this context")
    if shutil.which("grok"):
        data = json.loads(run("grok", "inspect", "--json"))
        seen = set()
        for entry in data.get("skills", []):
            name = entry.get("name", "").removeprefix("cktk:")
            if name not in names:
                continue
            seen.add(name)
            path = Path(entry["source"]["path"])
            expected = source / "skills" / name / "SKILL.md"
            same = path.resolve() in {expected, expected.parent}
            print(f"Grok {name}: {path} ({'same source' if same else 'other source'})")
            if not same and (owned_target(path) or entry["source"].get("plugin_name") == "cktk"):
                if mode != "plugin" or digest(path.parent) != digest(expected.parent):
                    problems.append(f"Grok loads another cktk source: {path}")
            elif not same:
                print(f"NOTICE: unrelated same-name Grok skill preserved: {name}; select the cktk source explicitly")
        problems.extend(f"Grok did not discover {name}" for name in sorted(names - seen))
    if shutil.which("opencode"):
        entries = json.loads(run("opencode", "debug", "skill"))
        seen = set()
        for entry in entries:
            name = entry.get("name")
            if name not in names:
                continue
            seen.add(name)
            path = Path(entry["location"])
            expected = source / "skills" / name / "SKILL.md"
            print(f"OpenCode {name}: {path}")
            if path.resolve() != expected:
                problems.append(f"OpenCode selects another source for {name}: {path}")
        problems.extend(f"OpenCode did not discover {name}" for name in sorted(names - seen))
    for problem in problems:
        print(f"ERROR: {problem}")
    print(f"Runtime doctor: {len(problems)} problem(s). Current session caches may still need a reload.")
    return problems


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("install", "doctor", "source"))
    parser.add_argument("--source", type=Path, help="explicit source checkout; install otherwise uses this script's checkout")
    parser.add_argument("--home", type=Path, help="isolated installation home (ignores agent-home environment overrides)")
    parser.add_argument("--project-root", type=Path, help="optional invoking project for handoff ignore rules")
    parser.add_argument("--runtime", action="store_true", help="also read installed CLI inventories (doctor only)")
    parser.add_argument("--mode", choices=("linked", "plugin"), help="linked personal Claude skills, or Claude-managed plugin cache")
    args = parser.parse_args()
    home = (args.home or Path.home()).expanduser().resolve()
    state_path = home / ".local/share/cktk/install.json"
    receipt = read_json(state_path) if state_path.exists() else {}
    registered = Path(receipt.get("source_root", str(DEFAULT_SOURCE)))
    source = (args.source or (DEFAULT_SOURCE if args.command == "install" else registered)).expanduser().resolve()
    if args.command == "source":
        if not is_checkout(source):
            raise ValueError(f"registered checkout is unavailable: {source}; select an existing checkout explicitly")
        print(source)
        return 0
    skills = source_skills(source)
    paths = locations(home, args.home is not None)
    if args.command == "install":
        project = args.project_root or (Path(os.environ["PROJECT_ROOT"]) if os.environ.get("PROJECT_ROOT") and not args.home else None)
        install(source, paths, skills, receipt, state_path, project, args.mode or receipt.get("mode", "linked"))
        return 0
    # Recheck the locations chosen at installation even if environment overrides changed.
    if receipt.get("locations"):
        paths = {key: Path(value) for key, value in receipt["locations"].items()}
    problems = doctor(source, paths, skills, receipt, state_path)
    if args.runtime:
        if args.home is not None:
            raise ValueError("--runtime inspects the real user configuration; omit --home")
        problems.extend(runtime_doctor(source, skills, receipt.get("mode", "linked")))
    return int(bool(problems))


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f"agent-skills: {error}", file=sys.stderr)
        sys.exit(1)
