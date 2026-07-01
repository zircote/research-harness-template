#!/usr/bin/env bash
# check-relationship-targets.sh — prove every relationships[].target in the
# active corpus resolves to a real finding @id.
#
# Root cause this closes (2026-07): relationships[].target is authored by an
# LLM analyst (dimension-analyst.md Step 5c: "target is the sibling finding's
# full @id... Re-validate the finding after adding relationships[]") with no
# machine-checked step backing that instruction — unlike citation-integrity,
# which has an actual `scripts/check-citation-integrity.sh` call at write
# time. That let bare/guessed slugs (e.g. "f-competitive-1" instead of the
# real "findings-competitive-f-competitive-1-0") land unnoticed. Separately,
# falsification-analyst.md's quarantine step ("move the finding file to
# $REPORTS_DIR/quarantine/... removed from the active set") never cascades to
# other findings' inbound relationships, leaving dangling references to a
# finding that used to be active.
#
# The "real @id" universe is corpus-wide (@id is a globally unique URN) and
# ACTIVE-ONLY: only <topic>/findings/*.json is globbed, so quarantine/ and
# archive/ are excluded, matching falsification-analyst.md's own working-set
# definition ("the quarantine/ and archive/ siblings are separate and
# excluded").
#
# KNOWN LIMITATION: dimension-analyst.md permits a target that is "a urn:mif:
# id of an external concept" outside this corpus. This gate cannot distinguish
# a legitimate external reference from a typo/dangling reference — it treats
# every urn:mif:concept: target not found in the active-id universe as a
# finding. If a genuine external target is ever introduced, this gate will
# need an allowlist; as of this writing zero such references exist in the
# corpus (verified by a full scan), so no allowlist is implemented yet.
#
# Usage: check-relationship-targets.sh [--reports-dir <path>]
#   exit 0 = every relationships[].target resolves to an active finding @id
#   exit 1 = one or more orphaned targets found (each printed as
#            "ORPHAN\t<source-file>\t<orphaned-target>")
#   exit 2 = usage/environment error (missing jq, missing reports dir, or a
#            finding file that jq cannot parse — see below for why this must
#            be a hard failure rather than a silent skip)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RD="$ROOT/reports"
while [ $# -gt 0 ]; do
  case "$1" in
    --reports-dir) RD="$2"; shift 2 ;;
    *) echo "check-relationship-targets: unknown arg: $1" >&2; exit 2 ;;
  esac
done
command -v jq >/dev/null || { echo "check-relationship-targets: jq required" >&2; exit 2; }
[ -d "$RD" ] || { echo "check-relationship-targets: reports dir not found: $RD" >&2; exit 2; }

FILES="$(mktemp)"; IDS="$(mktemp)"; TARGETS="$(mktemp)"; JQERR="$(mktemp)"
trap 'rm -f "$FILES" "$IDS" "$TARGETS" "$JQERR"' EXIT

# Active-id universe: every finding's @id under <topic>/findings/*.json,
# across every topic. quarantine/ and archive/ are separate siblings of
# findings/ and are never globbed here. Collect the file
# list once, then hand it to jq/xargs in bulk (a handful of process spawns,
# not one per finding) — this corpus runs into the thousands of files.
find "$RD" -mindepth 2 -maxdepth 2 -type d -name findings -print0 \
  | while IFS= read -r -d '' fdir; do
      find "$fdir" -maxdepth 1 -type f -name '*.json' ! -name '.*' -print0
    done > "$FILES"

[ -s "$FILES" ] || { echo "check-relationship-targets: no active findings found under $RD — nothing to check" >&2; exit 0; }

# jq, given multiple file args, aborts the whole batch (not just the one bad
# file) on the first unparseable JSON — silently truncating everything after
# it in file order. Under the old `2>/dev/null`, that meant one malformed
# finding anywhere in the corpus made the active-@id universe (and the
# targets list) silently incomplete: real orphans past the bad file went
# unreported, and findings past the bad file could be misreported as
# orphaned. Both jq passes here therefore fail loudly (exit 2) instead of
# swallowing the error, matching this repo's no-silent-diagnostic-suppression
# convention.
if ! xargs -0 jq -r '."@id" // empty' < "$FILES" 2>"$JQERR" | sort -u > "$IDS"; then
  echo "check-relationship-targets: jq failed to parse one or more finding files under $RD — fix the invalid JSON before re-running:" >&2
  cat "$JQERR" >&2
  exit 2
fi

# Every relationships[].target, paired with its source file for reporting.
# input_filename is jq's current-file name when given multiple file args.
if ! xargs -0 jq -r 'input_filename as $f | (.relationships // [])[]?.target // empty | "\($f)\t\(.)"' \
  < "$FILES" 2>"$JQERR" > "$TARGETS"; then
  echo "check-relationship-targets: jq failed to parse one or more finding files under $RD — fix the invalid JSON before re-running:" >&2
  cat "$JQERR" >&2
  exit 2
fi

# A per-target `grep -qxF "$IDS"` here would be O(targets x ids) — noticeably
# slow once a corpus reaches thousands of findings with hundreds of
# relationships. Instead, resolve the whole target set against the whole id
# set as a single sorted-merge set difference (comm), then re-join only the
# resulting orphan VALUES back against $TARGETS to name their source files.
# This repo's own scripts stay bash-3.2-compatible (macOS's bundled
# /usr/bin/env bash), so no `declare -A` associative array here.
TVALS="$(mktemp)"; ORPHANS="$(mktemp)"
trap 'rm -f "$FILES" "$IDS" "$TARGETS" "$JQERR" "$TVALS" "$ORPHANS"' EXIT
cut -f2 "$TARGETS" | grep -v '^$' | sort -u > "$TVALS"
comm -23 "$TVALS" "$IDS" > "$ORPHANS"

checked=$(awk -F'\t' '$2!=""' "$TARGETS" | wc -l | tr -d ' ')
fail=0
if [ -s "$ORPHANS" ]; then
  fail=1
  # Column-matched join (ORPHANS is target values only, one per line) —
  # avoids grep -F substring false positives against the src\ttarget rows.
  awk -F'\t' 'NR==FNR { orphan[$1]=1; next } $2 in orphan { printf "ORPHAN\t%s\t%s\n", $1, $2 }' \
    "$ORPHANS" "$TARGETS"
fi

if [ "$fail" != 0 ]; then
  echo "check-relationship-targets: one or more relationships[].target values do not resolve to any active finding @id (see ORPHAN lines above)" >&2
  exit 1
fi
echo "check-relationship-targets: ok ($checked relationship target(s) checked across $(wc -l < "$IDS" | tr -d ' ') active finding(s), 0 orphans)"
