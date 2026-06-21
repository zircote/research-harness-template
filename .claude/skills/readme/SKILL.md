---
name: readme
description: "Create, update, and validate a topic's navigation README at reports/<topic>/README.md — the per-topic index (title, metadata, purpose, dimensions, key findings, report-file table, tags) projected from the MIF substrate, modeled on the per-directory READMEs in research corpora. Use this skill whenever a report topic is created or mutated and its README must be reconciled: after a research session synthesizes, after findings or reports change, or when the user asks to 'update the README', 'reindex the topic readme', 'reconcile READMEs', or 'regenerate the topic index'. Reads harness.config.json topics[], reports/<topic>/findings/*.json, and goal.json — never hand-authors counts."
version: 1.0.0
argument-hint: "[--topic <id>] [--all] [--check]"
allowed-tools: Read, Bash, Edit, Glob, Grep, Write
---

# readme — the per-topic navigation index

Every report topic carries a navigation `README.md` at `reports/<topic>/README.md`:
a compact index of what the topic holds — title, research id, created/updated
dates, finding and source counts, purpose, dimensions, key findings, a table of
rendered reports, and tags. It is modeled on the per-directory READMEs in a
research corpus (`reports/**/README.md`).

The README is a **navigation projection, not a MIF Level-3 report.** Like the
`blog` and `book` channels it is MIF-exempt: it carries no MIF frontmatter and is
excluded from the output-conformance gate. Its source of truth is the MIF
substrate — `reports/<topic>/findings/*.json`, the session `goal.json`, and the
`harness.config.json` manifest entry — so it is always reproducible from them.

## When this runs

This skill wraps `scripts/build-topic-readme.sh` — the deterministic engine both
it and the orchestration share — and adds prose refinement.

- **At synthesis (deterministic):** the `orchestrator` (which has no `Skill`
  tool) runs the **script** directly in Phase 4, so every topic-mutating run
  (`full | update | augment`) leaves the README rebuilt and validated.
- **In the orchestration flow:** the `/start` command invokes **this skill**
  after the orchestrator returns, to refine the Purpose and Key Findings prose on
  top of that deterministic build.
- **On demand / safety net:** run it any time, e.g. when the
  `check-readme-reindex` PostToolUse hook flags an out-of-band edit to findings,
  reports, or the manifest.

## Pipeline

1. **Resolve the topic set.**
   - `--topic <id>` — one topic.
   - `--all` — every topic in `harness.config.json` `topics[]`.
   - no flag — the topic of the active session (the `reports/<topic>/` whose
     findings/reports changed); if ambiguous, ask which, or use `--all`.

2. **Write the deterministic README.** The script computes every count, date,
   dimension, tag, and the report-file table from the substrate — never author
   these by hand:

   ```bash
   bash scripts/build-topic-readme.sh <topic>
   ```

   It writes a complete, valid README on its own, including for a just-created
   topic with zero findings.

3. **Refine the prose (judgment).** Open `reports/<topic>/README.md` and improve
   only the **Purpose** and **Key Findings** sections so they read like the
   reference corpus — Purpose a tight 1–2 sentence framing, Key Findings 3–5
   insight-bearing bullets drawn from the surviving/weakened findings (read
   `reports/<topic>/findings/*.json` for substance). **Edit only those two
   sections.** Leave the metadata header, Dimensions, Reports table, and Tags as
   the script produced them, and preserve any manually-added custom sections.

4. **Validate (the gate).** The README must pass the structural check before you
   report done — required sections present, the stated finding count matches the
   substrate, and every linked report exists:

   ```bash
   bash scripts/build-topic-readme.sh <topic> --check
   ```

   A non-zero exit means the README is wrong — fix it, do not ship it. Markdown
   lint is enforced separately by the bundled `md_guard` hook on write.

5. **`--all`:** loop steps 2–4 over every topic.

## Non-negotiables

- The README never carries MIF frontmatter and never claims a verdict — it is a
  navigation index, not a report of record (that is `publish-report`).
- Counts, dates, dimensions, and tags are deterministic — taken from the
  substrate via the script, never invented or edited by hand.
- The `--check` gate must pass before the README is reported reconciled.
- `--topic` / `--all` only — never hardcode a topic id; the harness is a
  distributable template.
