#!/usr/bin/env bash
# build-topic-readme.sh — maintain (build) and validate (check) a topic's
# navigation README at reports/<topic>/README.md.
#
# The README is a per-topic navigation index — title, metadata, purpose,
# dimensions, key findings, a report-file table, and tags — projected from the
# MIF substrate (reports/<topic>/findings/*.json), the session goal
# (reports/<topic>/goal.json), and the manifest entry (harness.config.json).
# Like blog/book, it is a navigation projection, NOT a MIF Level-3 report, so it
# is exempt from the output-conformance gate (see .claude/hooks/check-output-conformance.sh).
#
# All counts/dates/dimensions/tags/file-tables are computed deterministically
# here; the `readme` skill refines the Purpose and Key Findings prose on top of
# the valid default this script writes. The script alone always produces a valid,
# complete README — including for a just-created topic with zero findings.
#
# Usage:
#   build-topic-readme.sh <topic> [--check] [--findings <dir>] [--out <path>]
#
#   build (default)  write/refresh reports/<topic>/README.md
#   --check          structural validation gate; exits non-zero on any defect
#   --findings <dir> override findings dir (default reports/<topic>/findings)
#   --out <path>     override output path (default reports/<topic>/README.md)

set -uo pipefail

die() { echo "build-topic-readme: $*" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || die "jq is required"

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CONFIG="$PROJECT_DIR/harness.config.json"

TOPIC=""
MODE="build"
FINDINGS_DIR=""
OUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --check)    MODE="check" ;;
    --findings) FINDINGS_DIR="${2:?--findings needs a dir}"; shift ;;
    --out)      OUT="${2:?--out needs a path}"; shift ;;
    --*)        die "unknown flag: $1" ;;
    *)          if [ -z "$TOPIC" ]; then TOPIC="$1"; else die "unexpected arg: $1"; fi ;;
  esac
  shift
done

[ -n "$TOPIC" ] || die "usage: build-topic-readme.sh <topic> [--check] [--findings <dir>] [--out <path>]"
[ -f "$CONFIG" ] || die "manifest not found: $CONFIG"

# Resolve the manifest entry — the topic MUST be registered.
TOPIC_JSON=$(jq -c --arg id "$TOPIC" '.topics[] | select(.id == $id)' "$CONFIG")
[ -n "$TOPIC_JSON" ] || die "topic \"$TOPIC\" is not registered in harness.config.json"

TITLE=$(printf '%s' "$TOPIC_JSON" | jq -r '.title // empty')
[ -n "$TITLE" ] || TITLE="$TOPIC"

TOPIC_DIR="$PROJECT_DIR/reports/$TOPIC"
[ -n "$FINDINGS_DIR" ] || FINDINGS_DIR="$TOPIC_DIR/findings"
[ -n "$OUT" ] || OUT="$TOPIC_DIR/README.md"
GOAL="$TOPIC_DIR/goal.json"

# ----- deterministic data over the MIF substrate -------------------------------

# Findings rollup: count, distinct source URLs, dimensions, tags, created date,
# and the survived/weakened titles that become Key Findings bullets.
read_findings() {
  local files
  files=$(find "$FINDINGS_DIR" -maxdepth 1 -name '*.json' 2>/dev/null | sort)
  if [ -z "$files" ]; then
    echo '{"count":0,"sources":0,"dimensions":[],"tags":[],"created":null,"key":[]}'
    return
  fi
  # shellcheck disable=SC2086
  jq -s '
    {
      count: length,
      sources: ([.[].citations[]?.url] | map(select(. != null)) | unique | length),
      dimensions: ([.[].extensions.harness.dimension] | map(select(. != null)) | unique),
      tags: ([.[].tags[]?] | map(select(. != null)) | unique),
      created: ([.[].created] | map(select(. != null)) | sort | first),
      key: (
        map(select((.extensions.harness.verification.verdict // "") as $v
                   | $v == "survived" or $v == "weakened"))
        | sort_by(.extensions.harness.verification.verdict == "survived" | not)
        | map(.title) | map(select(. != null)) | .[0:5]
      )
    }' $files
}

ROLL=$(read_findings)
COUNT=$(printf '%s' "$ROLL" | jq -r '.count')
SOURCES=$(printf '%s' "$ROLL" | jq -r '.sources')
CREATED=$(printf '%s' "$ROLL" | jq -r '.created // empty')
TODAY=$(date -u +%Y-%m-%d)
[ -n "$CREATED" ] || CREATED="$TODAY"
CREATED="${CREATED:0:10}"   # normalize ISO datetime -> date-only

# Dimensions: union of goal dimensions and dimensions seen in findings.
DIMENSIONS=$(jq -rn \
  --argjson roll "$ROLL" \
  --slurpfile goal_arr <(cat "$GOAL" 2>/dev/null || echo '{}') '
  ($goal_arr[0] // {}) as $g
  | (($g.dimensions // []) + $roll.dimensions) | unique
  | if length == 0 then "—" else join(", ") end')

# Tags from findings; fall back to a sensible note when none.
TAGS=$(printf '%s' "$ROLL" | jq -r 'if (.tags | length) == 0 then "—" else (.tags | join(", ")) end')

# Purpose: prefer the goal statement, else a generic line.
PURPOSE=$(jq -rn --slurpfile goal_arr <(cat "$GOAL" 2>/dev/null || echo '{}') --arg t "$TITLE" '
  ($goal_arr[0] // {}) as $g
  | ($g.goal_statement // $g.research_question // $g.goal // $g.question // null) as $q
  | if $q == null or $q == "" then ("Research session for " + $t + ".") else $q end')

# Extract the body of a section (between "## Header" and the next "## ") from an
# existing README, with leading/trailing blank lines trimmed.
extract_section() {
  awk -v hdr="$1" '
    $0 == hdr { grab=1; next }
    grab && /^## / { grab=0 }
    grab { print }
  ' "$2" | awk '
    { lines[n++] = $0 }
    END {
      s = 0; while (s < n && lines[s] == "") s++
      e = n; while (e > s && lines[e-1] == "") e--
      for (i = s; i < e; i++) print lines[i]
    }'
}

# Preservation (matches the reference reindexer: refresh metadata, keep custom
# prose). When the README already exists, preserve the human/skill-authored
# Purpose and Key Findings and the original Created date — only the deterministic
# header counts, Updated date, Dimensions, Reports table, and Tags are rebuilt.
KEY_PRESERVED=""
if [ "$MODE" = "build" ] && [ -f "$OUT" ]; then
  prev_created=$(grep -oE '\*\*Created:\*\* [0-9]{4}-[0-9]{2}-[0-9]{2}' "$OUT" \
    | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
  [ -n "$prev_created" ] && CREATED="$prev_created"
  prev_purpose=$(extract_section "## Purpose" "$OUT")
  [ -n "$prev_purpose" ] && PURPOSE="$prev_purpose"
  prev_key=$(extract_section "## Key Findings" "$OUT")
  [ -n "$prev_key" ] && KEY_PRESERVED="$prev_key"
fi

# ----- markdown assembly -------------------------------------------------------

build_readme() {
  printf '# %s\n\n' "$TITLE"
  printf '**Research ID:** %s\n' "$TOPIC"
  printf '**Created:** %s | **Updated:** %s\n' "$CREATED" "$TODAY"
  printf '**Findings:** %s | **Sources:** %s\n\n' "$COUNT" "$SOURCES"
  printf -- '---\n\n'

  printf '## Purpose\n\n%s\n\n' "$PURPOSE"

  printf '## Dimensions\n\n%s\n\n' "$DIMENSIONS"

  printf '## Key Findings\n\n'
  if [ -n "$KEY_PRESERVED" ]; then
    printf '%s\n\n' "$KEY_PRESERVED"
  elif [ "$COUNT" -eq 0 ]; then
    printf -- '- No findings yet — run `/start --topic %s` to begin research.\n\n' "$TOPIC"
  else
    printf '%s' "$ROLL" | jq -r '.key[] | "- " + .'
    printf '\n'
  fi

  printf '## Reports\n\n'
  local reports
  # research-progress.md is a continuity/audit log, not a rendered report — exclude
  # it (and README.md) so it never appears as a report link or defeats the empty state.
  reports=$(find "$TOPIC_DIR" -maxdepth 1 -name '*.md' \
    ! -name 'README.md' ! -name 'research-progress.md' 2>/dev/null | sort)
  if [ -z "$reports" ]; then
    printf 'No reports rendered yet.\n\n'
  else
    printf '| File | Description |\n'
    printf '| --- | --- |\n'
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      local base desc
      base=$(basename "$f")
      case "$base" in
        *delta*|*DELTA*) desc="Delta update" ;;
        report.md|*-report.md|REPORT.md) desc="Research report" ;;
        *) desc="Report" ;;
      esac
      printf '| [`%s`](%s) | %s |\n' "$base" "$base" "$desc"
    done <<< "$reports"
    printf '\n'
  fi

  printf '## Tags\n\n%s\n' "$TAGS"
}

# ----- check (structural validation gate) --------------------------------------

run_check() {
  local errs=0
  if [ ! -f "$OUT" ]; then
    echo "FAIL: README missing: $OUT" >&2
    return 1
  fi
  local required=("## Purpose" "## Dimensions" "## Key Findings" "## Reports" "## Tags")
  for sec in "${required[@]}"; do
    grep -qF "$sec" "$OUT" || { echo "FAIL: missing section: $sec" >&2; errs=$((errs+1)); }
  done

  # Findings count in the README must match the actual finding count.
  local stated
  stated=$(grep -oE '\*\*Findings:\*\* [0-9]+' "$OUT" | grep -oE '[0-9]+' | head -1)
  if [ -z "$stated" ]; then
    echo "FAIL: no '**Findings:** N' metadata line" >&2; errs=$((errs+1))
  elif [ "$stated" != "$COUNT" ]; then
    echo "FAIL: Findings count drift — README says $stated, substrate has $COUNT" >&2; errs=$((errs+1))
  fi

  # Every linked report file in the Reports table must exist on disk.
  local link
  while IFS= read -r link; do
    [ -n "$link" ] || continue
    [ -f "$TOPIC_DIR/$link" ] || { echo "FAIL: dangling report link: $link" >&2; errs=$((errs+1)); }
  done < <(grep -oE '\| \[`[^`]+`\]\([^)]+\)' "$OUT" | grep -oE '\]\([^)]+\)' | sed -E 's/^\]\(//; s/\)$//')

  if [ "$errs" -ne 0 ]; then
    echo "build-topic-readme: $errs validation error(s) for $TOPIC" >&2
    return 1
  fi
  echo "OK: $OUT valid ($COUNT findings, $SOURCES sources)"
  return 0
}

# ----- dispatch ----------------------------------------------------------------

if [ "$MODE" = "check" ]; then
  run_check
  exit $?
fi

mkdir -p "$(dirname "$OUT")"
build_readme > "$OUT" || die "failed to write $OUT"
echo "wrote $OUT ($COUNT findings, $SOURCES sources)"
