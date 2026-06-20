#!/usr/bin/env bash
# reconcile-session.sh — derive a durable session checkpoint
# (reports/<topic>/state.json) purely from disk and print the remaining-work plan.
# Crash-safe resume (SPEC §6b): a finding is DONE only when it is schema-valid AND
# gated (extensions.harness.verification.attempted_at present). Invalid findings,
# and *.tmp / hidden partial writes, are EXCLUDED from done-counts, so /resume never
# reworks completed findings. Idempotent and byte-deterministic: the checkpoint
# carries no wall-clock field, records are sorted, and jq sorts keys — two runs over
# the same disk produce byte-identical state.json AND plan.
#
# Usage: reconcile-session.sh <reports-dir>
#   writes <reports-dir>/state.json; prints the remaining plan to stdout; exit 0.

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

RD="${1:?usage: reconcile-session.sh <reports-dir>}"
case "$RD" in /*) : ;; *) RD="$(pwd)/$RD" ;; esac
[ -d "$RD" ] || { echo "reconcile: not a directory: $RD" >&2; exit 2; }
FDIR="$RD/findings"
TOPIC="$(basename "$RD")"

ajv_ok() { # validate one finding file against the MIF-backed findings schema
  ajv validate --spec=draft2020 --strict=false -c ajv-formats \
    -s "$ROOT/schemas/findings.schema.json" \
    -r "$ROOT/schemas/mif/mif.schema.json" \
    -r "$ROOT/schemas/mif/definitions/entity-reference.schema.json" \
    -d "$1" >/dev/null 2>&1
}

# Per-finding records. A real finding is a non-hidden, non-tmp *.json file; hidden
# (.*) and *.tmp files are in-flight partial writes and are skipped entirely.
records="[]"
partial_count=0
if [ -d "$FDIR" ]; then
  partial_count=$(find "$FDIR" -maxdepth 1 -type f -name '*.tmp' 2>/dev/null | wc -l | tr -d ' ')
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    id=$(jq -r '."@id" // .id // empty' "$f" 2>/dev/null); [ -z "$id" ] && id="$(basename "$f")"
    dim=$(jq -r '.extensions.harness.dimension // "unknown"' "$f" 2>/dev/null)
    att=$(jq -r '.extensions.harness.verification.attempted_at // empty' "$f" 2>/dev/null)
    vrd=$(jq -r '.extensions.harness.verification.verdict // empty' "$f" 2>/dev/null)
    if ajv_ok "$f"; then valid=true; else valid=false; fi
    records=$(jq -c --arg id "$id" --arg dim "$dim" --argjson valid "$valid" \
                    --arg att "$att" --arg vrd "$vrd" \
      '. + [{id:$id, dimension:$dim, valid:$valid,
             attempted_at:(if $att=="" then null else $att end),
             verdict:(if $vrd=="" then null else $vrd end)}]' <<<"$records")
  done < <(find "$FDIR" -maxdepth 1 -type f -name '*.json' ! -name '.*' ! -name '*.tmp' 2>/dev/null | sort)
fi

# DONE = valid AND gated (attempted_at != null). Per-dimension total/done; checks
# computed from disk. jq -S => sorted keys; findings sorted by id => deterministic.
state=$(jq -S -n --arg topic "$TOPIC" --argjson f "$records" '
  ($f | sort_by(.id)) as $findings
  | ($findings | group_by(.dimension) | map({
       key: .[0].dimension,
       value: { total: length,
                done: ([.[] | select(.valid and .attempted_at != null)] | length) }
    }) | from_entries) as $dims
  | { topic: $topic, findings: $findings, dimensions: $dims,
      checks: [
        {check:"findings_present",    passed: (($findings | map(select(.valid and .attempted_at != null)) | length) > 0)},
        {check:"all_valid_gated",     passed: (($findings | map(select(.valid and .attempted_at == null)) | length) == 0)},
        {check:"no_invalid_findings", passed: (($findings | map(select(.valid | not)) | length) == 0)}
      ] }')

# no_partial_writes is a filesystem fact (count of *.tmp), folded in and re-sorted.
if [ "$partial_count" -eq 0 ]; then nptw=true; else nptw=false; fi
state=$(jq -S --argjson nptw "$nptw" \
  '.checks += [{check:"no_partial_writes", passed:$nptw}] | .checks |= sort_by(.check)' <<<"$state")

# Write the checkpoint atomically (tmp + rename).
printf '%s\n' "$state" > "$RD/.state.json.staging" && mv "$RD/.state.json.staging" "$RD/state.json"

# Remaining-work plan: dimensions with undone findings + failing checks, sorted.
plan=$(jq -r '
  ( [ .dimensions | to_entries[] | select(.value.done < .value.total)
      | "dimension \(.key): \(.value.total - .value.done) finding(s) need work" ] )
  + ( [ .checks[] | select(.passed | not) | "check \(.check): FAIL" ] )
  | sort | .[]' "$RD/state.json")

if [ -z "$plan" ]; then
  echo "nothing to do"
else
  echo "REMAINING WORK PLAN"
  printf '%s\n' "$plan"
fi
