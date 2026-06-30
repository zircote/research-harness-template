#!/usr/bin/env bash
# check-ontology-lock.sh — prove vendored domain ontologies match the pinned lock.
#
# Fail-closed integrity gate. Every ENABLED domain ontology must:
#   (a) be pinned in ontologies.lock.json,
#   (b) be present as packs/ontologies/<id>/<id>.ontology.yaml,
#   (c) hash to its pinned sha256.
# This catches hand-edits/drift of a vendored copy (fixes belong UPSTREAM in the
# ontologies repo, not here) and missing on-demand packs. Base layers under
# schemas/ontologies/ are committed, not vendored, and are out of scope.
#
# Usage: check-ontology-lock.sh        (exit 1 on any drift/missing pin/file)
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
LOCK="ontologies.lock.json"
CFG="harness.config.json"
command -v jq >/dev/null || { echo "check-ontology-lock: jq required" >&2; exit 2; }
SHA="sha256sum"; command -v sha256sum >/dev/null || SHA="shasum -a 256"

[ -f "$CFG" ] || { echo "check-ontology-lock: no $CFG" >&2; exit 2; }
[ -f "$LOCK" ] || { echo "check-ontology-lock: no $LOCK (run scripts/fetch-ontology.sh --all-enabled)" >&2; exit 1; }

fail=0; checked=0
for id in $(jq -r '.ontologies[]? | select(.enabled==true) | .id' "$CFG"); do
  [ -d "schemas/ontologies/$id" ] && continue          # committed base layer, not vendored
  pinned=$(jq -r --arg id "$id" '.ontologies[$id].sha256 // empty' "$LOCK")
  yaml="packs/ontologies/$id/$id.ontology.yaml"
  if [ -z "$pinned" ]; then
    echo "  MISSING PIN: '$id' is enabled but absent from $LOCK" >&2; fail=1; continue
  fi
  if [ ! -f "$yaml" ]; then
    echo "  NOT VENDORED: '$id' is pinned but $yaml is absent — run scripts/fetch-ontology.sh $id" >&2; fail=1; continue
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
echo "check-ontology-lock: ok ($checked enabled domain ontolog$([ "$checked" = 1 ] && echo y || echo ies) match the lock)"
