---
name: diataxis-docs
description: "Render a research topic's surviving findings into a Diátaxis-compliant documentation set — a tutorial, a how-to guide, a reference, and an explanation, each carrying a diataxis_type marker. An OPTIONAL channel pack (enable the `diataxis` pack to use it), behind the typed findings→artifact contract. Use this skill when the user wants documentation for a research topic, a docs set from the findings, or to publish the corpus as Diátaxis docs. Triggers on 'diataxis docs', 'documentation channel', 'render docs from research', 'tutorial and how-to from the findings', 'reference and explanation docs'."
version: 1.0.0
argument-hint: "[--topic <id>] [--genre <genre>] [--out <dir>] [--slug <name>]"
allowed-tools: Read, Bash, Glob, Grep
---

# diataxis-docs — research → Diátaxis documentation set

Diátaxis is a documentation channel pack (SPEC §6d): enable the bundled `diataxis`
channel pack to render a research topic into documentation — it is not an
always-on core output (blog is the first-class published channel). It renders a
topic's surviving findings through the **same typed findings→artifact contract**
(`schemas/artifact.schema.json`) the blog and book outputs use, so one synthesis
drives a post, a chapter, and a docs set, and the citation gates run uniformly
across all of them.

This channel is **per-topic**, exactly like `book` and `pdf`: it documents the
research corpus of a single topic. It is not a repository-wide documentation tool.

## What Diátaxis is

Diátaxis organizes documentation by the user need it serves, into four modes that
must stay **pure** — never mixed within one document:

- **Tutorial** — learning-oriented. A guided first walk through the results for
  someone new; lessons, not a list of facts.
- **How-to guide** — task-oriented. Numbered steps to act on the findings;
  assumes competence, states a goal and a result.
- **Reference** — information-oriented. Dry, neutral facts for lookup; no
  narration, no instruction.
- **Explanation** — understanding-oriented. The discursive "why" — background and
  how the parts connect; for understanding, not action.

Mode purity is the compliance invariant: a tutorial that explains, or a reference
that instructs, is non-compliant. The renderer keeps each quadrant in its mode.

## Pipeline

1. **Resolve the finding set** for the topic — the surviving findings (verdict ≠
   `falsified`) under `reports/<topic>/findings`.

2. **Synthesize the artifact** (the report-synthesizer substrate). Because
   `synthesize-artifact.sh` changes directory internally, build absolute output
   paths from `pwd`:

   ```bash
   OUTDIR=$(pwd)
   scripts/synthesize-artifact.sh "reports/<topic>/findings" <genre> "$OUTDIR/artifact.json"
   ```

3. **Render the documentation set** from that artifact with the pack-local,
   `jq`-only renderer. It writes one Markdown file per quadrant under its own
   directory, each with a `diataxis_type:` frontmatter marker:

   ```bash
   packs/channels/diataxis/scripts/render-diataxis.sh "$OUTDIR/artifact.json" docs/<topic> overview
   ```

   This produces `docs/<topic>/{tutorials,how-to,reference,explanation}/overview.md`.

4. **Confirm mode purity and clean citations.** Each file must read in its own
   mode, and the prose cites only the artifact's public sources — no finding ids,
   `urn:mif:` ids, or `reports/<slug>/` paths.

## Non-negotiables

- **Never include a falsified or quarantined finding** — the synthesizer filters
  them.
- **Documentation prose carries no internal-research references.** Each page cites
  only the public sources in its Sources list.
- **Keep every quadrant in its mode.** Do not let a tutorial drift into reference,
  or a how-to into explanation — that breaks Diátaxis compliance.
- The docs set is a projection of the artifact; change the findings or synthesis,
  not the rendered Markdown in place.
- **`diataxis` is a MIF-exempt channel** (declared `mif.exempt: true` in its
  `plugin.json`): authored documentation prose is orthogonal to MIF, so the MIF
  Level-3 source of truth lives in the generic `report` channel
  (`reports/<topic>/<slug>.md`), not the docs set. The MIF I/O conformance gate
  skips and logs the documentation; it does not require an L3 projection of it.
