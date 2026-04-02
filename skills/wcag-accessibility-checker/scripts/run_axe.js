#!/usr/bin/env node
/**
 * run_axe.js — Automated accessibility testing using axe-core via Playwright
 *
 * Usage:
 *   npx --yes playwright install chromium  # first time only
 *   node run_axe.js <base-url> [options]
 *
 * Options:
 *   --urls /path1,/path2,...   Comma-separated paths to test (default: /)
 *   --level A|AA|AAA           Target WCAG level (default: AA)
 *   --output results.json      Write results to file (default: stdout)
 *
 * Examples:
 *   node run_axe.js http://localhost:3000
 *   node run_axe.js http://localhost:3000 --urls /,/about,/contact --level AA
 *   node run_axe.js http://localhost:3000 --output a11y-results.json
 *
 * Dependencies (auto-installed via npx):
 *   - playwright (with chromium)
 *   - @axe-core/playwright
 */

const { chromium } = require("playwright");

// Dynamically require axe-playwright — caller should ensure it's available
let AxeBuilder;
try {
  AxeBuilder = require("@axe-core/playwright").default;
} catch {
  console.error(
    "Error: @axe-core/playwright not found. Install it first:\n" +
      "  npm install --no-save @axe-core/playwright playwright\n" +
      "Then ensure Chromium is installed:\n" +
      "  npx playwright install chromium"
  );
  process.exit(1);
}

// ── Argument parsing ────────────────────────────────────────

function parseArgs(argv) {
  const args = argv.slice(2);
  const opts = {
    baseUrl: null,
    urls: ["/"],
    level: "AA",
    output: null,
  };

  let i = 0;
  while (i < args.length) {
    const arg = args[i];
    if (arg === "--urls" && args[i + 1]) {
      opts.urls = args[++i].split(",").map((u) => u.trim());
    } else if (arg === "--level" && args[i + 1]) {
      opts.level = args[++i].toUpperCase();
    } else if (arg === "--output" && args[i + 1]) {
      opts.output = args[++i];
    } else if (!arg.startsWith("--") && !opts.baseUrl) {
      opts.baseUrl = arg.replace(/\/$/, "");
    }
    i++;
  }

  if (!opts.baseUrl) {
    console.error(
      "Usage: node run_axe.js <base-url> [--urls /p1,/p2] [--level AA] [--output file.json]"
    );
    process.exit(1);
  }

  if (!["A", "AA", "AAA"].includes(opts.level)) {
    console.error("Error: --level must be A, AA, or AAA");
    process.exit(1);
  }

  return opts;
}

// ── WCAG tag mapping ────────────────────────────────────────

/**
 * Map axe-core rule tags to WCAG level and POUR principle.
 * axe tags follow patterns like: "wcag2a", "wcag2aa", "wcag21a", "wcag22aa",
 * "wcag111" (SC 1.1.1), "cat.color", "cat.forms", etc.
 */
function getWcagLevel(tags) {
  if (
    tags.some((t) =>
      /^wcag2{0,1}(2{0,1})aaa$/.test(t) || t === "wcag2aaa" || t === "wcag22aaa"
    )
  )
    return "AAA";
  if (
    tags.some(
      (t) => t === "wcag2aa" || t === "wcag21aa" || t === "wcag22aa"
    )
  )
    return "AA";
  if (
    tags.some(
      (t) => t === "wcag2a" || t === "wcag21a" || t === "wcag22a"
    )
  )
    return "A";
  return "unknown";
}

function getWcagCriterion(tags) {
  for (const tag of tags) {
    const match = tag.match(/^wcag(\d)(\d)(\d+)$/);
    if (match) {
      return `${match[1]}.${match[2]}.${match[3]}`;
    }
  }
  return null;
}

function getPrinciple(tags) {
  const criterion = getWcagCriterion(tags);
  if (criterion) {
    const principle = parseInt(criterion.charAt(0), 10);
    const names = {
      1: "Perceivable",
      2: "Operable",
      3: "Understandable",
      4: "Robust",
    };
    return names[principle] || "Unknown";
  }

  // Fallback: use axe category tags
  const catMap = {
    "cat.text-alternatives": "Perceivable",
    "cat.color": "Perceivable",
    "cat.sensory-and-visual-cues": "Perceivable",
    "cat.time-and-media": "Perceivable",
    "cat.tables": "Perceivable",
    "cat.keyboard": "Operable",
    "cat.navigation": "Operable",
    "cat.semantics": "Robust",
    "cat.structure": "Perceivable",
    "cat.forms": "Understandable",
    "cat.language": "Understandable",
    "cat.parsing": "Robust",
    "cat.aria": "Robust",
    "cat.name-role-value": "Robust",
  };

  for (const tag of tags) {
    if (catMap[tag]) return catMap[tag];
  }
  return "Unknown";
}

function getSeverity(impact) {
  const map = {
    critical: "Critical",
    serious: "Serious",
    moderate: "Moderate",
    minor: "Moderate",
  };
  return map[impact] || "Moderate";
}

// ── axe tags to include based on target level ───────────────

function getAxeTags(level) {
  const tags = ["wcag2a", "wcag21a", "wcag22a"];
  if (level === "AA" || level === "AAA") {
    tags.push("wcag2aa", "wcag21aa", "wcag22aa");
  }
  if (level === "AAA") {
    tags.push("wcag2aaa", "wcag21aaa", "wcag22aaa");
  }
  return tags;
}

// ── Main ────────────────────────────────────────────────────

async function scanPage(browser, url, level) {
  const context = await browser.newContext();
  const page = await context.newPage();
  const result = { url, violations: [], error: null };

  try {
    const response = await page.goto(url, {
      waitUntil: "domcontentloaded",
      timeout: 30000,
    });

    if (!response || response.status() >= 400) {
      result.error = `HTTP ${response ? response.status() : "no response"}`;
      return result;
    }

    // Wait for content to settle
    await page.waitForTimeout(1000);

    const axeTags = getAxeTags(level);
    const axeResults = await new AxeBuilder({ page })
      .withTags(axeTags)
      .analyze();

    result.violations = axeResults.violations.map((v) => ({
      id: v.id,
      description: v.description,
      help: v.help,
      helpUrl: v.helpUrl,
      impact: v.impact,
      severity: getSeverity(v.impact),
      wcagLevel: getWcagLevel(v.tags),
      wcagCriterion: getWcagCriterion(v.tags),
      principle: getPrinciple(v.tags),
      tags: v.tags,
      nodes: v.nodes.map((n) => ({
        html: n.html,
        target: n.target,
        failureSummary: n.failureSummary,
      })),
    }));
  } catch (err) {
    result.error = err.message;
  } finally {
    await context.close();
  }

  return result;
}

async function main() {
  const opts = parseArgs(process.argv);

  console.error(`axe-core accessibility scan`);
  console.error(`  Base URL: ${opts.baseUrl}`);
  console.error(`  Paths: ${opts.urls.join(", ")}`);
  console.error(`  Target level: WCAG 2.2 ${opts.level}`);
  console.error("");

  const browser = await chromium.launch({ headless: true });
  const pages = [];

  for (const path of opts.urls) {
    const url = `${opts.baseUrl}${path}`;
    console.error(`  Scanning: ${url}`);
    const result = await scanPage(browser, url, opts.level);

    if (result.error) {
      console.error(`    Error: ${result.error}`);
    } else {
      console.error(
        `    Found ${result.violations.length} violation(s)`
      );
    }

    pages.push(result);
  }

  await browser.close();

  // Build summary
  const allViolations = pages.flatMap((p) => p.violations);
  const summary = {
    totalViolations: allViolations.length,
    byLevel: { A: 0, AA: 0, AAA: 0, unknown: 0 },
    byPrinciple: {
      Perceivable: 0,
      Operable: 0,
      Understandable: 0,
      Robust: 0,
      Unknown: 0,
    },
    bySeverity: { Critical: 0, Serious: 0, Moderate: 0 },
  };

  for (const v of allViolations) {
    summary.byLevel[v.wcagLevel] = (summary.byLevel[v.wcagLevel] || 0) + 1;
    summary.byPrinciple[v.principle] =
      (summary.byPrinciple[v.principle] || 0) + 1;
    summary.bySeverity[v.severity] =
      (summary.bySeverity[v.severity] || 0) + 1;
  }

  const output = {
    meta: {
      baseUrl: opts.baseUrl,
      targetLevel: opts.level,
      pagesScanned: opts.urls.length,
      timestamp: new Date().toISOString(),
    },
    summary,
    pages,
  };

  const json = JSON.stringify(output, null, 2);

  if (opts.output) {
    require("fs").writeFileSync(opts.output, json, "utf-8");
    console.error(`\nResults written to ${opts.output}`);
  } else {
    console.log(json);
  }

  console.error(`\nDone. Total violations: ${summary.totalViolations}`);
}

main().catch((err) => {
  console.error("Fatal error:", err.message);
  process.exit(1);
});
