#!/usr/bin/env bash
# Citation-integrity gate (SPEC §4 "Verifier/citation-integrity layer", §6c/§6d).
#
# Reference-hallucination and citation-quality failures are the dominant deep-
# research failure mode, so citation verification is a CORE gate that travels
# with the engine. This script asserts, over one or more MIF-backed findings
# files (a single finding object or an array of them):
#
#   1. every finding carries at least one citation (MIF Level 3);
#   2. every citation is traceable to a source — EITHER a well-formed http(s) URL
#      (web source) OR an internal/document citation (citationType ^internal:
#      carrying the quoted evidence in `note`) — and has a citationRole;
#   3. no finding ships with an adversarial verdict of "falsified";
#   4. no citation URL is listed dead (extensions.harness.citationStatus.deadUrls[]).
#
# Exit 0 = all findings pass (GOOD). Exit 1 = at least one violation (BAD),
# with one `file:finding-id: reason` line per violation on stderr.
#
# Usage: check-citation-integrity.sh <findings.json> [<findings.json> ...]

set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "usage: check-citation-integrity.sh <findings.json> [...]" >&2
  exit 2
fi

# Feature flag (SPEC §7): internal/document citations are accepted as traceable
# ONLY when harness.config.json opts in via features.internalCitations. The
# template ships strict (flag absent/false => http(s)-only); an instance that
# imported a legacy corpus with internal sources enables it. HARNESS_CONFIG
# overrides the config path.
CONFIG="${HARNESS_CONFIG:-harness.config.json}"
internal_ok=false
if [ -f "$CONFIG" ] && [ "$(jq -r '.features.internalCitations // false' "$CONFIG" 2>/dev/null)" = "true" ]; then
  internal_ok=true
fi

violations=0

for f in "$@"; do
  if [ ! -f "$f" ]; then
    echo "${f}: file not found" >&2
    violations=$((violations + 1))
    continue
  fi
  if ! jq -e . "$f" >/dev/null 2>&1; then
    echo "${f}: not valid JSON" >&2
    violations=$((violations + 1))
    continue
  fi

  # Normalize: wrap a single finding object into a one-element array so the same
  # jq program handles both shapes. jq emits one fully-formed message per line.
  report=$(jq -r --arg file "$f" --argjson internal_ok "$internal_ok" '
    (if type == "array" then . else [.] end)
    | to_entries[]
    | (.value["@id"] // ("#" + (.key|tostring))) as $id
    | (.value.citations // []) as $cites
    | (.value.extensions.harness.verification.verdict // "inconclusive") as $verdict
    | ($file + ":" + $id + ": ") as $loc
    | [
        (if ($cites | length) < 1
           then ($loc + "no citations (MIF Level 3 requires >=1)") else empty end),
        ($cites[]
           | select(
               ( (((.url // "")|type) == "string" and ((.url // "")|test("^https?://")))
                 or ( $internal_ok and ((.citationType // "")|test("^internal:")) and (((.note // "")|length) > 0) )
               ) | not)
           | ($loc + (if $internal_ok
                      then "citation has neither a well-formed http(s) URL nor an internal: source with a note: "
                      else "citation missing well-formed http(s) URL: " end)
              + ((.title // "<untitled>")|tostring))),
        ($cites[]
           | select((.citationRole // "") == "")
           | ($loc + "citation missing citationRole: " + (.title // "<untitled>"))),
        (if $verdict == "falsified"
           then ($loc + "adversarial verdict is falsified; finding must not ship") else empty end),
        ((.value.extensions.harness.citationStatus.deadUrls // [])[]
           | ($loc + "citation URL listed dead: " + (.|tostring)))
      ]
    | .[]
  ' "$f")

  if [ -n "$report" ]; then
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      echo "$line" >&2
      violations=$((violations + 1))
    done <<< "$report"
  fi
done

if [ "$violations" -gt 0 ]; then
  echo "citation-integrity: FAIL (${violations} violation(s))" >&2
  exit 1
fi

echo "citation-integrity: PASS ($# file(s))"
exit 0
