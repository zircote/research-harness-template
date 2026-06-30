#!/usr/bin/env bash
# check-ontology-lock.sh — prove vendored domain ontologies match the pinned lock.
#
# Fail-closed integrity gate (wired into verify.sh). Two checks:
#   (a) COVERAGE — every ENABLED domain ontology is pinned in ontologies.lock.json
#       and present as packs/ontologies/<id>/<id>.ontology.yaml.
#   (b) INTEGRITY — every PINNED ontology that is present on disk hashes to its
#       pinned sha256 (catches local drift even for a disabled-but-vendored pack;
#       fixes belong UPSTREAM in the ontologies repo, not here).
# Base layers under schemas/ontologies/ are committed, not vendored, and skipped.
#
# When there is no lock, on-demand vendoring has not been adopted in this clone —
# there is nothing to verify, so the gate passes cleanly.
#
# Usage: check-ontology-lock.sh        (exit 1 on any drift/missing pin/file)
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
LOCK="ontologies.lock.json"
CFG="harness.config.json"
command -v jq >/dev/null || { echo "check-ontology-lock: jq required" >&2; exit 2; }
SHA="sha256sum"; command -v sha256sum >/dev/null || SHA="shasum -a 256"

[ -f "$CFG" ] || { echo "check-ontology-lock: no $CFG" >&2; exit 2; }
if [ ! -f "$LOCK" ]; then
  echo "check-ontology-lock: no $LOCK — on-demand vendoring not adopted; nothing to verify"
  exit 0
fi

fail=0; checked=0

# (a) coverage: every enabled domain ontology must be pinned
for id in $(jq -r '.ontologies[]? | select(.enabled==true) | .id' "$CFG"); do
  [ -d "schemas/ontologies/$id" ] && continue           # committed base layer
  pinned=$(jq -r --arg id "$id" '.ontologies[$id].sha256 // empty' "$LOCK")
  if [ -z "$pinned" ]; then
    echo "  MISSING PIN: '$id' is enabled but absent from $LOCK — run scripts/fetch-ontology.sh $id" >&2
    fail=1
  fi
done

# (b) integrity: every pinned ontology present on disk must match its hash;
#     an enabled pin with no file is NOT VENDORED (a disabled one absent is fine).
for id in $(jq -r '.ontologies | keys[]?' "$LOCK"); do
  pinned=$(jq -r --arg id "$id" '.ontologies[$id].sha256 // empty' "$LOCK")
  yaml="packs/ontologies/$id/$id.ontology.yaml"
  enabled=$(jq -r --arg id "$id" '[.ontologies[]? | select(.id==$id and .enabled==true)] | length' "$CFG" 2>/dev/null)
  if [ ! -f "$yaml" ]; then
    if [ "${enabled:-0}" -ge 1 ]; then
      echo "  NOT VENDORED: enabled '$id' is pinned but $yaml is absent — run scripts/fetch-ontology.sh $id" >&2
      fail=1
    fi
    continue
  fi
  got=$($SHA "$yaml" | awk '{print $1}')
  if [ "$got" != "$pinned" ]; then
    echo "  DRIFT: $yaml sha256 $got != pinned $pinned" >&2
    echo "         a vendored ontology was edited locally — change it UPSTREAM in the ontologies repo, then re-fetch." >&2
    fail=1; continue
  fi
  checked=$((checked+1))
done

if [ "$fail" != 0 ]; then exit 1; fi
echo "check-ontology-lock: ok ($checked vendored ontolog$([ "$checked" = 1 ] && echo y || echo ies) match the lock)"
