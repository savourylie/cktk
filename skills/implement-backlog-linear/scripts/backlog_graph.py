#!/usr/bin/env python3
"""Plan, schedule, and report implement-backlog-linear runs.

The skill gathers facts from Linear and git; this script applies the rules
that decide what a run may touch, so the same facts always produce the same
plan, ready list, and status line. Standard library only; it never contacts
Linear.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

SCHEMA = 1
PARK_LABEL = "human-blocked"
GATE_LABELS = frozenset({"human-setup", "human-acceptance", PARK_LABEL})
OPEN_STATES = frozenset({"triage", "backlog", "unstarted", "started"})
TERMINAL_STATES = frozenset({"completed", "canceled", "duplicate"})
ISSUE_ID = re.compile(r"^([A-Za-z][A-Za-z0-9]*)-(\d+)$")
ID_PREFIX = re.compile(r"^([A-Za-z][A-Za-z0-9]*-\d+)-")
LANDED_SUBJECT = re.compile(r"^Merge linear-([A-Za-z][A-Za-z0-9]*-\d+)-\S* into (\S+)$")
EPIC_TITLE = re.compile(r"^\s*\[epic\]", re.IGNORECASE)
COUNT_KEYS = ("AI-ELIGIBLE", "DONE", "PARKED", "HUMAN-GATED", "BLOCKED")


class InputError(Exception):
    """A snapshot, state, plan, or repository the rules cannot use."""


def norm_id(value):
    match = ISSUE_ID.match(str(value).strip())
    if not match:
        raise InputError(f"not a Linear issue identifier: {value!r}")
    return f"{match.group(1).upper()}-{int(match.group(2))}"


def id_key(issue_id):
    team, number = issue_id.rsplit("-", 1)
    return (team, int(number))


def sort_ids(ids):
    return sorted(ids, key=id_key)


def label_set(labels):
    """Lowercased label names; a label is a name or an object with one. Anything else fails closed."""
    names = set()
    for label in labels or ():
        if isinstance(label, dict):
            label = label.get("name")
        if not isinstance(label, str):
            raise InputError(f"unreadable label {label!r}; expected a label name")
        names.add(label.strip().lower())
    return names


def project_of(value):
    if not value:
        return None
    if isinstance(value, dict):
        return {"id": str(value["id"]), "name": str(value.get("name") or "")}
    return {"id": str(value), "name": ""}


def load_snapshot(data):
    """Normalize a planning snapshot: uppercase ids, merged duplicates, both relation directions."""
    issues = {}
    reverse = []
    for raw in data.get("issues") or []:
        issue_id = norm_id(raw["id"])
        state = str(raw.get("state_type") or "").lower()
        if state not in OPEN_STATES | TERMINAL_STATES:
            raise InputError(f"{issue_id}: unknown state_type {raw.get('state_type')!r}")
        entry = issues.setdefault(issue_id, {
            "id": issue_id,
            "title": str(raw.get("title") or ""),
            "state_type": state,
            "labels": set(),
            "assignee": raw.get("assignee"),
            "project": project_of(raw.get("project")),
            "parent": norm_id(raw["parent"]) if raw.get("parent") else None,
            "blocked_by": set(),
            "local_work": bool(raw.get("local_work")),
            "sub_issues": set(),
        })
        entry["labels"] |= label_set(raw.get("labels"))
        entry["blocked_by"] |= {norm_id(b) for b in raw.get("blocked_by") or ()}
        entry["sub_issues"] |= {norm_id(s) for s in raw.get("sub_issues") or ()}
        reverse.extend((norm_id(b), issue_id) for b in raw.get("blocks") or ())
    for blocked, blocker in reverse:
        if blocked in issues:
            issues[blocked]["blocked_by"].add(blocker)
    external = {}
    for raw in data.get("external") or []:
        issue_id = norm_id(raw["id"])
        external[issue_id] = {"id": issue_id, "state_type": str(raw.get("state_type") or "").lower(),
                              "title": str(raw.get("title") or "")}
    team = data.get("team") or {}
    if not team.get("key"):
        raise InputError("snapshot team.key is required")
    me = data.get("me")
    if not isinstance(me, str) or not me.strip() or me.strip().lower() == "me":
        raise InputError("snapshot me must be the invoking user's Linear id")
    return {
        "team": {"id": str(team.get("id") or ""), "key": str(team["key"]).upper()},
        "me": me.strip(),
        "requested_project": project_of(data.get("requested_project")),
        "binding_project": project_of(data.get("binding_project")),
        "issues": issues,
        "external": external,
    }


def resolve_scope(snapshot):
    """Apply the one-project-one-repository rule to the snapshot's open issues."""
    issues = snapshot["issues"]
    open_ids = [i for i, v in issues.items() if v["state_type"] in OPEN_STATES]
    requested = snapshot["requested_project"]
    bound = snapshot["binding_project"]
    bound_id = bound["id"] if bound else None
    if requested:
        if bound_id and bound_id != requested["id"]:
            return {"status": "stop", "reason": "binding-mismatch", "project": requested, "bound": bound}
        ids = [i for i in open_ids if (issues[i]["project"] or {}).get("id") == requested["id"]]
        return {"status": "ok", "project": requested, "issue_ids": sort_ids(ids)}
    projects = {}
    for issue_id in open_ids:
        project = issues[issue_id]["project"]
        if project:
            projects.setdefault(project["id"], project)
    if len(projects) > 1:
        listed = sorted(projects.values(), key=lambda p: (p["name"], p["id"]))
        return {"status": "stop", "reason": "multiple-projects", "bound": bound,
                "projects": [dict(p, bound=p["id"] == bound_id) for p in listed]}
    if projects:
        project = next(iter(projects.values()))
        if bound_id and bound_id != project["id"]:
            return {"status": "stop", "reason": "binding-mismatch", "project": project, "bound": bound}
        return {"status": "ok", "project": project, "issue_ids": sort_ids(open_ids)}
    return {"status": "ok", "project": None, "issue_ids": sort_ids(open_ids)}


def classify(issue, me):
    """Return why an open in-scope issue is not a candidate, or None when it is one."""
    gates = issue["labels"] & GATE_LABELS
    if gates:
        label = PARK_LABEL if PARK_LABEL in gates else sorted(gates)[0]
        return {"reason": "human-gate", "label": label}
    if issue["assignee"] and issue["assignee"] != me:
        return {"reason": "someone-else"}
    if issue["state_type"] == "triage":
        return {"reason": "not-triaged"}
    if issue["state_type"] == "started" and not issue["local_work"]:
        return {"reason": "running-elsewhere"}
    return None


def state_of(issue_id, snapshot):
    if issue_id in snapshot["issues"]:
        return snapshot["issues"][issue_id]["state_type"]
    if issue_id in snapshot["external"]:
        return snapshot["external"][issue_id]["state_type"]
    return None


def topo_layers(nodes, blockers):
    """Kahn's algorithm in layers; returns (layers, nodes that never became free)."""
    remaining, done, layers = set(nodes), set(), []
    while remaining:
        layer = sort_ids(n for n in remaining if all(b in done for b in blockers[n]))
        if not layer:
            break
        layers.append(layer)
        done.update(layer)
        remaining.difference_update(layer)
    return layers, remaining


def on_cycle(node, blockers, allowed):
    stack, seen = list(blockers.get(node, ())), set()
    while stack:
        current = stack.pop()
        if current == node:
            return True
        if current in seen or current not in allowed:
            continue
        seen.add(current)
        stack.extend(blockers.get(current, ()))
    return False


def attach_roots(excluded, snapshot):
    """Name the underlying causes of every dependency exclusion as <kind>:<issue>."""
    memo = {}

    def roots(issue_id, trail):
        if issue_id in memo:
            return memo[issue_id]
        info = excluded[issue_id]
        if info["reason"] == "human-gate":
            found = {f"{info['label']}:{issue_id}"}
        elif info["reason"] != "blocked":
            found = {f"{info['reason']}:{issue_id}"}
        else:
            found = set()
            for blocker in info["via"]:
                if blocker in excluded:
                    if blocker not in trail:
                        found |= roots(blocker, trail | {issue_id})
                    continue
                state = state_of(blocker, snapshot)
                if state in ("canceled", "duplicate"):
                    found.add(f"{state}:{blocker}")
                elif state is None:
                    found.add(f"unknown:{blocker}")
                else:
                    found.add(f"outside-scope:{blocker}")
        memo[issue_id] = found
        return found

    for issue_id, info in excluded.items():
        if info["reason"] == "blocked":
            info["roots"] = sorted(roots(issue_id, frozenset()))


def select(snapshot):
    """Compute the plan: scope, eligible issues in layers, and every exclusion with its reason."""
    scope = resolve_scope(snapshot)
    plan = {"status": "stop", "scope": {k: v for k, v in scope.items() if k != "issue_ids"},
            "order": [], "layers": [], "edges": {}, "excluded": {}, "titles": {}}
    if scope["status"] != "ok":
        return plan
    issues = snapshot["issues"]
    scope_ids = scope["issue_ids"]
    excluded, candidates = {}, []
    for issue_id in scope_ids:
        verdict = classify(issues[issue_id], snapshot["me"])
        if verdict:
            excluded[issue_id] = verdict
        else:
            candidates.append(issue_id)
    for issue_id in list(candidates):
        has_sub_issues = bool(issues[issue_id]["sub_issues"]) or any(issues[c]["parent"] == issue_id for c in scope_ids)
        if EPIC_TITLE.match(issues[issue_id]["title"]) and not has_sub_issues:
            excluded[issue_id] = {"reason": "epic-not-broken-down"}
            candidates.remove(issue_id)
    edges = {}
    for issue_id in candidates:
        children = {c for c in scope_ids if issues[c]["parent"] == issue_id} | issues[issue_id]["sub_issues"]
        children = {c for c in children if state_of(c, snapshot) not in ("canceled", "duplicate")}
        edges[issue_id] = issues[issue_id]["blocked_by"] | children
    eligible = set(candidates)
    changed = True
    while changed:
        changed = False
        for issue_id in sort_ids(eligible):
            unmet = [b for b in edges[issue_id]
                     if b not in eligible and state_of(b, snapshot) != "completed"]
            if unmet:
                eligible.discard(issue_id)
                excluded[issue_id] = {"reason": "blocked", "via": sort_ids(unmet)}
                changed = True
    in_plan = {i: sort_ids(b for b in edges[i] if b in eligible) for i in eligible}
    layers, stuck = topo_layers(eligible, in_plan)
    if stuck:
        cyclic = {i for i in stuck if on_cycle(i, in_plan, stuck)}
        for issue_id in sort_ids(stuck):
            if issue_id in cyclic:
                excluded[issue_id] = {"reason": "cycle", "via": [b for b in in_plan[issue_id] if b in cyclic]}
            else:
                excluded[issue_id] = {"reason": "blocked", "via": [b for b in in_plan[issue_id] if b in stuck]}
    attach_roots(excluded, snapshot)
    order = [i for layer in layers for i in layer]
    plan.update({
        "status": "planned" if order else "nothing-eligible",
        "order": order,
        "layers": layers,
        "edges": {i: in_plan[i] for i in order},
        "excluded": {i: excluded[i] for i in sort_ids(excluded)},
        "titles": {i: issues[i]["title"] for i in scope_ids},
    })
    return plan


def slugify(text, limit=24):
    slug = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    if len(slug) > limit:
        cut = slug[:limit]
        slug = cut.rsplit("-", 1)[0] if "-" in cut else cut
    return slug


def make_run_id(team_key, project, now, runs_dir):
    """<TEAM>-<project slug>-<YYYYMMDD-HHMM>, with -2, -3, … when that directory exists."""
    label = "team" if project is None else (slugify(project["name"]) or "project")
    base = f"{team_key}-{label}-{now.strftime('%Y%m%d-%H%M')}"
    candidate, suffix = base, 2
    while (Path(runs_dir) / candidate).exists():
        candidate, suffix = f"{base}-{suffix}", suffix + 1
    return candidate


def git(repo, *args):
    result = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True)
    if result.returncode != 0:
        raise InputError(f"git {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout


def worktree_ids(porcelain, main_root):
    root = os.path.join(os.path.realpath(main_root), ".worktrees") + os.sep
    ids = set()
    for line in porcelain.splitlines():
        if not line.startswith("worktree "):
            continue
        path = os.path.realpath(line[len("worktree "):].strip())
        if path.startswith(root):
            match = ID_PREFIX.match(path[len(root):].split(os.sep, 1)[0])
            if match:
                ids.add(norm_id(match.group(1)))
    return ids


def branch_ids(listing):
    ids = set()
    for line in listing.splitlines():
        name = line.strip()
        if name.startswith("linear-"):
            match = ID_PREFIX.match(name[len("linear-"):])
            if match:
                ids.add(norm_id(match.group(1)))
    return ids


def landed_ids(subjects, base):
    ids = set()
    for line in subjects.splitlines():
        match = LANDED_SUBJECT.match(line.strip())
        if match and match.group(2) == base:
            ids.add(norm_id(match.group(1)))
    return ids


def base_tip(repo, base):
    result = subprocess.run(["git", "-C", str(repo), "rev-parse", "--verify", "--quiet", base],
                            capture_output=True, text=True)
    return result.stdout.strip() or None


def landed_on(repo, base, since):
    """Issue ids whose `Merge linear-<ID>-… into <base>` commit landed after `since` (the plan's base tip)."""
    if not since or not base_tip(repo, base):
        return set()
    return landed_ids(git(repo, "log", f"{since}..{base}", "--merges", "--format=%s"), base)


def local_work(repo):
    """Issue ids with a registered .worktrees/<ID>-* worktree or a linear-<ID>-* branch."""
    ids = worktree_ids(git(repo, "worktree", "list", "--porcelain"), repo)
    return ids | branch_ids(git(repo, "branch", "--list", "--format=%(refname:short)", "linear-*"))


def now_utc(text=None):
    if not text:
        return datetime.now(timezone.utc)
    value = datetime.fromisoformat(text.replace("Z", "+00:00"))
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)


def read_json(path):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise InputError(f"cannot read {path}: {error}") from error


def write_json(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def cmd_plan(args):
    if args.parallel < 1:
        raise InputError("--parallel must be at least 1")
    raw = read_json(args.snapshot)
    snapshot = load_snapshot(raw)
    if args.repo:
        found = local_work(args.repo)
        for issue in snapshot["issues"].values():
            issue["local_work"] = issue["id"] in found
    plan = select(snapshot)
    now = now_utc(args.now)
    plan.update({
        "schema": SCHEMA,
        "created_at": now.isoformat(timespec="seconds"),
        "team": snapshot["team"],
        "me": snapshot["me"],
        "base": args.base,
        "parallel": args.parallel,
        "host": args.host,
        "repo": os.path.realpath(args.repo) if args.repo else None,
        "base_sha": base_tip(args.repo, args.base) if args.repo else None,
        "run_id": None,
        "run_dir": None,
    })
    if plan["status"] == "planned" and not args.dry_run:
        run_id = make_run_id(snapshot["team"]["key"], plan["scope"]["project"], now.astimezone(), args.runs_dir)
        run_dir = Path(args.runs_dir) / run_id
        plan["run_id"], plan["run_dir"] = run_id, str(run_dir)
        write_json(run_dir / "plan.json", plan)
        write_json(run_dir / "snapshot.json", raw)
        (run_dir / "results").mkdir(exist_ok=True)
    print(json.dumps(plan, ensure_ascii=False, indent=2))
    return 0


def next_step(plan, state, landed=frozenset()):
    """Decide what a run does next from its plan and fresh Linear state."""
    me = plan.get("me")
    order = plan["order"]
    planned = set(order)
    current = {norm_id(k): v for k, v in (state.get("issues") or {}).items()}
    external = {norm_id(k): v for k, v in (state.get("external") or {}).items()}
    in_flight = {norm_id(i) for i in state.get("in_flight") or ()}
    blockers = {i: set(plan["edges"].get(i, ())) for i in order}
    done, parked, removed = [], [], {}
    for issue_id in order:
        info = current.get(issue_id)
        if info is None:
            raise InputError(f"state is missing planned issue {issue_id}")
        if "labels" not in info:
            raise InputError(f"state for {issue_id} is missing labels")
        labels = label_set(info["labels"])
        state_type = str(info.get("state_type") or "").lower()
        if state_type == "completed":
            done.append(issue_id)
        elif PARK_LABEL in labels:
            parked.append(issue_id)
        elif labels & GATE_LABELS:
            removed[issue_id] = {"reason": "human-gate", "label": sorted(labels & GATE_LABELS)[0]}
        elif state_type in ("canceled", "duplicate"):
            removed[issue_id] = {"reason": state_type}
        elif info.get("assignee") and info["assignee"] != me:
            removed[issue_id] = {"reason": "someone-else"}
        else:
            new = []
            for blocker in info.get("blocked_by") or ():
                blocker = norm_id(blocker)
                if blocker in planned:
                    blockers[issue_id].add(blocker)
                elif (external.get(blocker) or current.get(blocker) or {}).get("state_type") != "completed":
                    new.append(blocker)
            if new:
                removed[issue_id] = {"reason": "new-blocker", "via": sort_ids(new)}
    finished = set(done)
    out = set(parked) | set(removed)
    changed = True
    while changed:
        changed = False
        for issue_id in order:
            if issue_id in finished or issue_id in out:
                continue
            via = sort_ids(b for b in blockers[issue_id] if b in out)
            if via:
                removed[issue_id] = {"reason": "blocked", "via": via}
                out.add(issue_id)
                changed = True
    active = [i for i in order if i not in finished and i not in out]
    landed_not_done = [i for i in active if i in landed]
    ready = [i for i in active
             if i not in in_flight and i not in landed and all(b in finished for b in blockers[i])]
    if active and not ready and not landed_not_done and not in_flight.intersection(active):
        for issue_id in active:
            removed[issue_id] = {"reason": "stuck",
                                 "via": sort_ids(b for b in blockers[issue_id] if b not in finished)}
        active = []
    counts = count_status(plan, active, done, parked, removed)
    return {
        "ready": ready,
        "in_flight": [i for i in active if i in in_flight],
        "landed_not_done": landed_not_done,
        "done": done,
        "parked": parked,
        "removed": {i: removed[i] for i in sort_ids(removed)},
        "counts": counts,
        "status_line": status_line(plan["run_id"], counts),
    }


def count_status(plan, active, done, parked, removed):
    excluded = plan["excluded"]
    parked_all = set(parked) | {i for i, v in excluded.items()
                                if v["reason"] == "human-gate" and v["label"] == PARK_LABEL}
    gated_all = {i for i, v in excluded.items()
                 if v["reason"] == "human-gate" and v["label"] != PARK_LABEL}
    gated_all |= {i for i, v in removed.items() if v["reason"] == "human-gate"}
    others = (set(excluded) | set(removed)) - parked_all - gated_all
    return {"AI-ELIGIBLE": len(active), "DONE": len(done), "PARKED": len(parked_all),
            "HUMAN-GATED": len(gated_all), "BLOCKED": len(others)}


def status_line(run_id, counts):
    parts = " · ".join(f"{key} {counts[key]}" for key in COUNT_KEYS)
    return f"STATUS implement-backlog-linear RUN {run_id} · {parts}"


def halted_line(run_id, reason):
    return f"STATUS implement-backlog-linear RUN {run_id} · HALTED · {' '.join(reason.split())}"


def cmd_next(args):
    plan = read_json(args.plan)
    state = read_json(args.state)
    landed = frozenset(landed_on(args.repo, plan["base"], plan.get("base_sha"))) if args.repo else frozenset()
    markers = Path(plan["run_dir"]) / "dispatched" if plan.get("run_dir") else None
    if markers and markers.is_dir():
        dispatched = [p.name for p in markers.iterdir() if ISSUE_ID.match(p.name)]
        state = dict(state, in_flight=list(state.get("in_flight") or ()) + dispatched)
    print(json.dumps(next_step(plan, state, landed), ensure_ascii=False, indent=2))
    return 0


def cmd_halted(args):
    print(halted_line(read_json(args.plan)["run_id"], args.reason))
    return 0


def scan_results(results_dir, known):
    new, malformed = [], []
    for path in sorted(Path(results_dir).glob("*.json")):
        name = path.name[: -len(".json")]
        if name in known:
            continue
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            malformed.append(name)
            continue
        new.append(name)
    return new, malformed


def cmd_wait(args):
    known = {part.strip() for part in args.known.split(",") if part.strip()}
    deadline = time.monotonic() + args.timeout
    while True:
        new, malformed = scan_results(args.results_dir, known)
        if new or malformed:
            print(json.dumps({"new": new, "malformed": malformed}))
            return 0
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            print(json.dumps({"new": [], "malformed": [], "timed_out": True}))
            return 124
        time.sleep(min(args.interval, remaining))


def read_lock(lock):
    try:
        return json.loads(lock.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {"run_id": None, "unreadable": True}


def cmd_lock(args):
    lock = Path(args.runs_dir) / "ACTIVE"
    if lock.exists():
        holder = read_lock(lock)
        if holder.get("run_id") != args.run_id:
            print(json.dumps({"locked_by": holder, "lock": str(lock)}))
            return 3
    write_json(lock, {"run_id": args.run_id, "host": args.host,
                      "taken_at": datetime.now(timezone.utc).isoformat(timespec="seconds")})
    print(json.dumps({"lock": str(lock), "run_id": args.run_id}))
    return 0


def cmd_unlock(args):
    lock = Path(args.runs_dir) / "ACTIVE"
    if not lock.exists():
        print(json.dumps({"released": False}))
        return 0
    holder = read_lock(lock)
    if holder.get("run_id") != args.run_id:
        print(json.dumps({"locked_by": holder, "lock": str(lock)}))
        return 3
    lock.unlink()
    print(json.dumps({"released": True}))
    return 0


def build_parser():
    parser = argparse.ArgumentParser(prog="backlog_graph.py",
                                     description="Plan, schedule, and report implement-backlog-linear runs.")
    sub = parser.add_subparsers(dest="command", required=True)

    plan = sub.add_parser("plan", help="select the issues a run may take")
    plan.add_argument("--snapshot", required=True)
    plan.add_argument("--runs-dir", required=True)
    plan.add_argument("--repo")
    plan.add_argument("--base", default="main")
    plan.add_argument("--parallel", type=int, default=3)
    plan.add_argument("--host", default="unknown")
    plan.add_argument("--now", help="ISO-8601 time; defaults to the current time")
    plan.add_argument("--dry-run", action="store_true", help="print the plan without creating a run directory")
    plan.set_defaults(handler=cmd_plan)
    step = sub.add_parser("next", help="decide what a run does next")
    step.add_argument("--plan", required=True)
    step.add_argument("--state", required=True)
    step.add_argument("--repo")
    step.set_defaults(handler=cmd_next)

    halted = sub.add_parser("halted", help="print the halted status line")
    halted.add_argument("--plan", required=True)
    halted.add_argument("--reason", required=True)
    halted.set_defaults(handler=cmd_halted)

    wait = sub.add_parser("wait", help="block until a new result file appears")
    wait.add_argument("--results-dir", required=True)
    wait.add_argument("--known", default="")
    wait.add_argument("--timeout", type=float, default=540.0)
    wait.add_argument("--interval", type=float, default=5.0)
    wait.set_defaults(handler=cmd_wait)

    for name, handler in (("lock", cmd_lock), ("unlock", cmd_unlock)):
        command = sub.add_parser(name, help=f"{name} the repository's active run")
        command.add_argument("--runs-dir", required=True)
        command.add_argument("--run-id", required=True)
        if name == "lock":
            command.add_argument("--host", default="unknown")
        command.set_defaults(handler=handler)

    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        return args.handler(args)
    except (InputError, KeyError, TypeError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
