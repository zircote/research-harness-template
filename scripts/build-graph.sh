#!/usr/bin/env bash
# build-graph.sh — build the first-class knowledge graph from the MIF substrate
# (SPEC §6c, §4a). The graph is derived from MIF EntityReferences and typed
# relationships, NOT from tag co-occurrence (the prior system's bolt-on). Every
# node and edge traces to a urn:mif: id.
#
#   nodes: one per finding concept (@id) and one per referenced MIF entity
#          (entities[].entity.@id), deduplicated.
#   edges: typed relationships[] (source concept -> target, by relationship type)
#          plus "mentions" edges from a finding to each entity it references.
#
# Usage: build-graph.sh <findings-dir> [<out.json>]
#        default out: <findings-dir>/../knowledge-graph.json

set -uo pipefail

DIR="${1:?usage: build-graph.sh <findings-dir> [out.json]}"
OUT="${2:-$DIR/../knowledge-graph.json}"

[ -d "$DIR" ] || { echo "build-graph: not a directory: $DIR" >&2; exit 2; }

# Collect the MIF finding files (concept docs with a urn:mif: @id). Portable to
# bash 3.2 (no mapfile); the controlled corpus has no spaces in paths.
FILES=$(find "$DIR" -maxdepth 1 -name '*.json' | sort)
[ -n "$FILES" ] || { echo "build-graph: no finding JSON in $DIR" >&2; exit 2; }
NFILES=$(printf '%s\n' "$FILES" | grep -c .)

# shellcheck disable=SC2086
jq -s '
  # Concept nodes: one per finding.
  ( map({ id: .["@id"], kind: "concept", label: (.title // .["@id"]),
          dimension: (.extensions.harness.dimension // null) }) ) as $concepts
  # Entity nodes: one per distinct referenced MIF entity.
  | ( [ .[] | (.entities // [])[] | { id: .entity["@id"], kind: "entity",
          label: (.name // .entity["@id"]), entityType: (.entityType // null) } ]
      | unique_by(.id) ) as $entities
  # Relationship edges: from each finding to its relationship targets.
  | ( [ .[] | .["@id"] as $src | (.relationships // [])[]
        | { source: $src, target: .target, type: .type,
            strength: (.strength // null), via: "relationship" } ] ) as $reledges
  # Mention edges: from each finding to each entity it references.
  | ( [ .[] | .["@id"] as $src | (.entities // [])[]
        | { source: $src, target: .entity["@id"], type: "mentions",
            strength: null, via: "entity" } ] ) as $mentions
  | {
      "@type": "KnowledgeGraph",
      generator: "build-graph.sh (MIF-native; SPEC §6c)",
      nodes: ($concepts + $entities | unique_by(.id)),
      edges: ($reledges + $mentions)
    }
' $FILES > "$OUT"

NODES=$(jq '.nodes | length' "$OUT")
EDGES=$(jq '.edges | length' "$OUT")
echo "build-graph: wrote $OUT ($NODES nodes, $EDGES edges) from $NFILES MIF findings"
