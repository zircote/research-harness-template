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
# ACTIVE-ONLY: quarantine/, archive/, and drafts-superseded/ are excluded,
# matching falsification-analyst.md's own working-set definition ("the
# quarantine/ and archive/ siblings are separate and excluded").
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
#            "<source-file>\t<orphaned-target>")
#   exit 2 = usage/environment error (missing jq, missing reports dir)
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

FILES="$(mktemp)"; IDS="$(mktemp)"; TARGETS="$(mktemp)"
trap 'rm -f "$FILES" "$IDS" "$TARGETS"' EXIT

# Active-id universe: every finding's @id under <topic>/findings/*.json,
# across every topic. quarantine/, archive/, and drafts-superseded/ are
# separate siblings of findings/ and are never globbed here. Collect the file
# list once, then hand it to jq/xargs in bulk (a handful of process spawns,
# not one per finding) — this corpus runs into the thousands of files.
find "$RD" -mindepth 2 -maxdepth 2 -type d -name findings -print0 \
  | while IFS= read -r -d '' fdir; do
      find "$fdir" -maxdepth 1 -type f -name '*.json' ! -name '.*' -print0
    done > "$FILES"

[ -s "$FILES" ] || { echo "check-relationship-targets: no active findings found under $RD — nothing to check" >&2; exit 0; }

xargs -0 jq -r '."@id" // empty' < "$FILES" 2>/dev/null | sort -u > "$IDS"

# Every relationships[].target, paired with its source file for reporting.
# input_filename is jq's current-file name when given multiple file args.
xargs -0 jq -r 'input_filename as $f | (.relationships // [])[]?.target // empty | "\($f)\t\(.)"' \
  < "$FILES" 2>/dev/null > "$TARGETS"

fail=0; checked=0
while IFS=$'\t' read -r src target; do
  [ -z "$target" ] && continue
  checked=$((checked+1))
  if ! grep -qxF "$target" "$IDS"; then
    printf 'ORPHAN\t%s\t%s\n' "$src" "$target"
    fail=1
  fi
done < "$TARGETS"

if [ "$fail" != 0 ]; then
  echo "check-relationship-targets: one or more relationships[].target values do not resolve to any active finding @id (see ORPHAN lines above)" >&2
  exit 1
fi
echo "check-relationship-targets: ok ($checked relationship target(s) checked across $(wc -l < "$IDS" | tr -d ' ') active finding(s), 0 orphans)"
