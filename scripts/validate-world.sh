#!/usr/bin/env bash
# validate-world.sh — fail-closed ontology conformance for the world graph (SPEC §8d).
# Asserts that every node entityType and every relationship edge type is declared by an
# ontology BOUND to the node's topic(s) (core mif-generic/mif-base ∪ the topic's bound
# ontologies), and that each relationship's endpoints satisfy the ontology's from/to
# domains. Any undeclared type or domain violation -> non-zero (fail-closed). Mention
# edges (via:entity) are structural and not domain-checked.
#
# Usage: validate-world.sh <world.json> [--config <p>] [--catalog <p>]

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for t in yq jq; do command -v "$t" >/dev/null 2>&1 || { echo "validate-world: '$t' not found" >&2; exit 5; }; done
WORLD=""; CONFIG="$ROOT/harness.config.json"; CATALOG="$ROOT/.claude/enabled-packs.json"
while [ $# -gt 0 ]; do
  case "$1" in
    --config) CONFIG="$2"; shift 2 ;;
    --catalog) CATALOG="$2"; shift 2 ;;
    *) WORLD="$1"; shift ;;
  esac
done
[ -n "$WORLD" ] && [ -f "$WORLD" ] || { echo "validate-world: world graph not found: ${WORLD:-<none>}" >&2; exit 2; }
# Fail-safe: without the catalog we cannot determine bound ontologies — abort, never pass.
[ -f "$CATALOG" ] || { echo "validate-world: catalog missing ($CATALOG) — run sync-packs.sh; refusing to validate" >&2; exit 3; }

src_of() { jq -r --arg id "$1" '.ontologies[]? | select(.id==$id) | .source' "$CATALOG" | head -1; }
core_ids=$(jq -r '.ontologies[]? | select(.core) | .id' "$CATALOG")

# Gather every relevant ontology's declared types + relationships into one JSON doc,
# and a topic -> allowed-ontology-ids map. Reading the YAML with yq (not in jq).
all_ids=$(
  { printf '%s\n' $core_ids
    jq -r '.topics[]?.ontologies[]?' "$CONFIG" 2>/dev/null | sed 's/@.*//'; } | sed '/^$/d' | sort -u)
ONTO='{}'
for oid in $all_ids; do
  src="$(src_of "$oid")"; [ -z "$src" ] && continue
  # yq only converts yaml->json; jq extracts the shape (robust against yq construction quirks).
  if ! ofull=$(yq -o=json '.' "$ROOT/$src" 2>/dev/null); then
    echo "validate-world: yq failed reading ontology '$oid' ($src) — aborting (fail closed)" >&2; exit 4
  fi
  od=$(jq -c '{types:[.entity_types[]?.name], rels:(.relationships // {})}' <<<"$ofull")
  ONTO=$(jq -c --arg id "$oid" --argjson d "$od" '. + {($id):$d}' <<<"$ONTO")
done
ALLOWED='{}'
for tp in $(jq -r '.topics[].id' "$CONFIG" 2>/dev/null); do
  ids=$( { printf '%s\n' $core_ids
           jq -r --arg t "$tp" '.topics[]? | select(.id==$t) | .ontologies[]?' "$CONFIG" 2>/dev/null | sed 's/@.*//'; } \
         | sed '/^$/d' | sort -u | jq -R . | jq -cs .)
  ALLOWED=$(jq -c --arg t "$tp" --argjson ids "$ids" '. + {($t):$ids}' <<<"$ALLOWED")
done

# All conformance logic in one jq (deterministic, portable).
if ! viol=$(jq -rn --slurpfile W "$WORLD" --argjson onto "$ONTO" --argjson allowed "$ALLOWED" '
  $W[0] as $G
  | ($G.nodes | map({key:.id, value:.}) | from_entries) as $byid
  | def allowed_ids($topics): [ $topics[] | $allowed[.] // [] ] | add // [] | unique;
    ( [ $G.nodes[]
        | select(.entityType != null and (.external != true))
        | .entityType as $et
        | select( any(allowed_ids(.topics)[]; ($onto[.].types // []) | index($et)) | not )
        | "node \(.id): entityType \($et) not declared by any bound ontology" ] )
  + ( [ $G.edges[] | select(.via == "relationship")
        | . as $e
        | ($byid[$e.source] // {}) as $s
        | ($byid[$e.target] // {}) as $t
        | allowed_ids($s.topics // []) as $ids
        | [ $ids[] | ($onto[.].rels[$e.type] // empty) ] as $rels
        | if ($rels | length) == 0
          then "edge \($e.source) ->\($e.type)-> \($e.target): relationship type not declared by any bound ontology"
          elif any($rels[]; ((.from // []) | index($s.entityType)) and ((.to // []) | index($t.entityType)))
          then empty
          else "edge \($e.source) ->\($e.type)-> \($e.target): from/to domain violation (\($s.entityType // "null") -> \($t.entityType // "null"))"
          end ] )
  | .[]'); then
  echo "validate-world: conformance check errored (jq) — aborting (fail closed)" >&2; exit 4
fi

if [ -z "$viol" ]; then
  echo "validate-world: conformant ($(jq '.nodes|length' "$WORLD") nodes, $(jq '.edges|length' "$WORLD") edges)"
  exit 0
fi
printf '%s\n' "$viol" >&2
echo "validate-world: $(printf '%s\n' "$viol" | grep -c .) conformance violation(s) — fail" >&2
exit 1
