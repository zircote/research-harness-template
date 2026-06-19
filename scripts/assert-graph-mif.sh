#!/usr/bin/env bash
# assert-graph-mif.sh — prove the knowledge graph is built from MIF entities and
# relations, not tags (Milestone 4 acceptance gate). Asserts:
#   1. every node id is a urn:mif: identifier;
#   2. every edge source is a urn:mif: concept and every edge target is a urn:mif: id;
#   3. at least one edge derives from a typed MIF relationship (via=relationship)
#      and at least one entity node exists (via=entity) — i.e. the graph uses the
#      MIF substrate, not tag co-occurrence;
#   4. no node or edge carries a tag-derived id (a bare tag string).
#
# Usage: assert-graph-mif.sh <knowledge-graph.json>

set -uo pipefail
G="${1:?usage: assert-graph-mif.sh <knowledge-graph.json>}"
[ -f "$G" ] || { echo "assert-graph: not found: $G" >&2; exit 2; }

fail=0
check() { # check <jq-bool-expr> <message>
  if [ "$(jq -r "$1" "$G")" = "true" ]; then
    echo "  graph: ok — $2"
  else
    echo "  graph: FAIL — $2" >&2; fail=1
  fi
}

check '(.nodes | length) > 0' "graph has nodes"
check '(.edges | length) > 0' "graph has edges"
check '.nodes | all(.id | startswith("urn:mif:"))' "every node id is a urn:mif: identifier (not a tag)"
check '.edges | all(.source | startswith("urn:mif:"))' "every edge source is a urn:mif: concept"
check '.edges | all(.target | startswith("urn:mif:"))' "every edge target is a urn:mif: id"
check 'any(.edges[]; .via == "relationship")' "at least one edge derives from a typed MIF relationship"
check 'any(.nodes[]; .kind == "entity" and (.id | startswith("urn:mif:entity:")))' "graph has MIF entity nodes"

# Every relationship edge must point at a real node (referential integrity).
check '(.nodes | map(.id)) as $ids | .edges | all(.target as $t | $ids | index($t) != null)' \
  "every edge target resolves to a node in the graph"

if [ "$fail" -ne 0 ]; then
  echo "assert-graph: FAIL" >&2
  exit 1
fi
echo "assert-graph: PASS"
