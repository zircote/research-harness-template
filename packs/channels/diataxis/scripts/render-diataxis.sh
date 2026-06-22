#!/usr/bin/env bash
# render-diataxis.sh — render one typed Artifact (schemas/artifact.schema.json)
# into a Diátaxis-compliant documentation set for a research topic.
#
# Diátaxis separates documentation by the user need it serves, into four modes
# that must stay pure (never mixed):
#   tutorial    — learning-oriented: a guided first walk through the results.
#   how-to      — task-oriented: imperative steps to act on the findings.
#   reference   — information-oriented: dry, terse facts for lookup.
#   explanation — understanding-oriented: the discursive "why" behind the results.
#
# Each rendered file carries a `diataxis_type:` frontmatter marker and is written
# under its own quadrant directory. The title lives in the body H1 only (NOT in
# frontmatter) so the set passes markdownlint MD025 (a frontmatter `title:` plus
# a body H1 reads as two top-level headings). The set is authored prose: the
# renderer projects ONLY public fields — the title, section headings and bodies,
# and the public source citations — and never emits finding ids or urn:mif: ids,
# so the documentation carries no internal MIF identity. (The bundled
# check-citation-leak.sh hook covers only blog/book paths, so leak-cleanliness
# here rests on this projection, which the pack's eval asserts; the channel is
# mif.exempt.)
#
# Self-contained: depends only on jq, which the harness already requires. It
# consumes a single artifact.json and writes nothing outside <out-dir>. Each
# quadrant is rendered to a temp file and moved into place only on success, so a
# jq failure never leaves a partial doc behind, and the script exits non-zero if
# any quadrant fails.
#
# Usage: render-diataxis.sh <artifact.json> <out-dir> [<slug>]

set -uo pipefail

ART="${1:?usage: render-diataxis.sh <artifact.json> <out-dir> [slug]}"
OUT="${2:?usage: render-diataxis.sh <artifact.json> <out-dir> [slug]}"
SLUG="${3:-overview}"
case "$SLUG" in
  */*|*..*) echo "render-diataxis: slug must not contain '/' or '..' (got: $SLUG)" >&2; exit 2 ;;
esac
[ -f "$ART" ] || { echo "render-diataxis: artifact not found: $ART" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "render-diataxis: jq is required" >&2; exit 2; }

# emit <quadrant-dir> <jq-program> — render atomically; return non-zero on failure.
emit() {
  local dir="$OUT/$1" prog="$2" tmp
  mkdir -p "$dir" || { echo "render-diataxis: cannot create $dir" >&2; return 1; }
  tmp="$(mktemp)" || return 1
  if jq -r "$prog" "$ART" > "$tmp"; then
    mv "$tmp" "$dir/$SLUG.md"
  else
    rm -f "$tmp"
    echo "render-diataxis: failed to render $1" >&2
    return 1
  fi
}

# Shared jq prelude: clean a section body (trim outer whitespace, collapse 3+
# newlines to a single blank) so emitted Markdown never trips MD012. The four
# quadrant programs are built by concatenating jq line-arrays and streaming them
# with `.[]`; the document ends on real content (the last source), so jq -r adds
# exactly one trailing newline (MD047-clean, no surplus blank).
DEF='def clean: gsub("^\\s+|\\s+$";"") | gsub("\\n{3,}";"\n\n");
     def firstsentence: (gsub("\\s+";" ") | split(". ")[0] | rtrimstr(".")) + ".";'

# --- tutorial (learning-oriented): a numbered lesson the reader works through ---
TUT="$DEF"'
  ( [ "---",
      "diataxis_type: tutorial",
      ("audience: " + ((.audience // "newcomers") | tojson)),
      "---",
      "",
      ("# Tutorial: Getting started with " + .title),
      "",
      ("This tutorial walks you through " + .title + " one step at a time. By the end you will have seen each key result first-hand. Follow the steps in order; no prior knowledge is assumed."),
      "",
      "## Before you begin",
      "",
      ("You will work through " + ((.sections | length) | tostring) + " short steps; each builds on the last."),
      "" ] )
  + [ .sections | to_entries[]
      | ( "## Step " + ((.key + 1) | tostring) + " — " + .value.heading,
          "",
          ("In this step you will explore " + .value.heading + "."),
          "",
          (.value.body | clean),
          "" ) ]
  + [ "## What you have learned", "" ]
  + [ .sections[] | "- " + .heading ]
  + [ "",
      "## Where to go next",
      "",
      "Use the how-to guide to apply this, the reference to look up the details, and the explanation to understand the reasoning.",
      "",
      "## Sources",
      "" ]
  + [ .sources[] | "- [" + .title + "](" + .url + ")" ]
  | .[]
'

# --- how-to (task-oriented): imperative steps to act on the findings ---
HOW="$DEF"'
  ( [ "---",
      "diataxis_type: how-to",
      "---",
      "",
      ("# How-to: Apply the findings on " + .title),
      "",
      ("This guide shows how to act on " + .title + ". It assumes you already understand the basics; if not, read the explanation first."),
      "",
      "## Goal",
      "",
      "Put the research conclusions to work.",
      "",
      "## Steps",
      "" ] )
  + [ .sections | to_entries[]
      | ((.key + 1) | tostring) + ". Apply this conclusion: " + (.value.heading | rtrimstr(".")) + "." ]
  + [ "",
      "## Result",
      "",
      "You have applied each conclusion above. Verify the outcome against the reference, and revisit the explanation if a step is unclear.",
      "",
      "## Sources",
      "" ]
  + [ .sources[] | "- [" + .title + "](" + .url + ")" ]
  | .[]
'

# --- reference (information-oriented): dry, terse facts for lookup ---
REF="$DEF"'
  ( [ "---",
      "diataxis_type: reference",
      "---",
      "",
      ("# Reference: " + .title),
      "",
      ("Factual lookup for " + .title + "."),
      "",
      "## Summary",
      "",
      ("- Genre: " + .genre),
      ("- Audience: " + (.audience // "general")),
      ("- Entries: " + ((.sections | length) | tostring)),
      "",
      "## Entries",
      "" ] )
  + [ .sections[] | "- **" + .heading + "** — " + (.body | firstsentence) ]
  + [ "", "## Sources", "" ]
  + [ .sources[] | "- [" + .title + "](" + .url + ") — " + (.citationType // "source") + ", " + (.citationRole // "reference") ]
  | .[]
'

# --- explanation (understanding-oriented): the discursive "why", full bodies ---
EXP="$DEF"'
  ( [ "---",
      "diataxis_type: explanation",
      "---",
      "",
      ("# Explanation: Understanding " + .title),
      "",
      ("This discussion explains why " + .title + " matters and how its parts connect. It is for understanding, not step-by-step action — see the how-to guide for that."),
      "" ] )
  + [ .sections[] | ( "## " + .heading, "", (.body | clean), "" ) ]
  + [ "## Sources", "" ]
  + [ .sources[] | "- [" + .title + "](" + .url + ")" ]
  | .[]
'

rc=0
emit tutorials   "$TUT" || rc=1
emit how-to      "$HOW" || rc=1
emit reference   "$REF" || rc=1
emit explanation "$EXP" || rc=1
if [ "$rc" -ne 0 ]; then
  echo "render-diataxis: one or more quadrants failed to render" >&2
  exit 1
fi

echo "render-diataxis: wrote $SLUG.md to tutorials/, how-to/, reference/, explanation/ under $OUT"
