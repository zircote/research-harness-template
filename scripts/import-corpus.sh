#!/usr/bin/env bash
# import-corpus.sh — import an existing corpus and its knowledge graph into a
# user's freshly INSTANTIATED harness, with provenance and graph edges intact
# (SPEC §10; Milestone 8 — the first real use of the MIF substrate). The
# accumulated value of a large, expensive research corpus is high; this is the
# path that brings it forward without adopting technical debt.
#
# This is a capability a clone runs against ITS OWN harness — it is NOT used to
# populate the template repository. The template ships clean and standalone; a
# corpus only ever lands in an instantiated harness's reports/ (the <reports-root>
# argument), never in the template's.
#
# Because the corpus is already MIF (findings are MIF concept units, the graph is
# MIF EntityReferences + typed relationships), the import is lossless: it
# validates each unit against the MIF-backed findings schema, places it under the
# target topic, registers the topic in the manifest, and rebuilds the index and
# graph over the MIF substrate. Provenance (the W3C-PROV block) travels with each
# unit untouched.
#
# Usage:
#   import-corpus.sh <source-corpus-dir> <topic-id> [<reports-root>] [<config>]
#     <source-corpus-dir> contains findings/*.json (MIF) and optionally a
#                         knowledge-graph.json (the corpus's existing graph).
#     defaults: reports-root=reports  config=harness.config.json

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
ROOT="$(pwd)"

SRC="${1:?usage: import-corpus.sh <source-corpus-dir> <topic-id> [reports-root] [config]}"
TOPIC="${2:?usage: import-corpus.sh <source-corpus-dir> <topic-id> [reports-root] [config]}"
REPORTS="${3:-reports}"
CONFIG="${4:-harness.config.json}"

SRC_FINDINGS="$SRC/findings"
[ -d "$SRC_FINDINGS" ] || { echo "import: source has no findings/ dir: $SRC_FINDINGS" >&2; exit 2; }

# GUARD — never import a corpus into the template repository itself (that defeats
# the point of a clean, reusable template). The template root is recognizable by
# its build docs + copier.yml (an instantiated harness has neither: copier.yml and
# COMPLETION-CRITERIA.md are excluded at instantiation). Refuse if the target
# reports-root resolves inside the template's own reports/.
if [ -f "$ROOT/copier.yml" ] && [ -f "$ROOT/COMPLETION-CRITERIA.md" ] && [ -z "${HARNESS_ALLOW_TEMPLATE_IMPORT:-}" ]; then
  RP_ABS="$(cd "$REPORTS" 2>/dev/null && pwd || echo "$ROOT/$REPORTS")"
  case "$RP_ABS" in
    "$ROOT"/reports|"$ROOT"/reports/*)
      echo "import: refusing to import a corpus into the template repository's own reports/." >&2
      echo "        Run this against an INSTANTIATED harness — pass a <reports-root> outside the template." >&2
      exit 2 ;;
  esac
fi

DEST="$REPORTS/$TOPIC/findings"
mkdir -p "$DEST"

# Validate + import each finding, asserting provenance is present (it must survive
# the import). ajv resolves the vendored MIF closure.
ajv_one() {
  ajv validate --spec=draft2020 --strict=false -c ajv-formats \
    -s "$ROOT/schemas/findings.schema.json" \
    -r "$ROOT/schemas/mif/mif.schema.json" \
    -r "$ROOT/schemas/mif/definitions/entity-reference.schema.json" \
    -d "$1" >/dev/null 2>&1
}

imported=0 no_prov=0
for f in "$SRC_FINDINGS"/*.json; do
  [ -f "$f" ] || continue
  if ! ajv_one "$f"; then
    echo "import: finding fails MIF-backed schema, refusing to import: $f" >&2
    exit 1
  fi
  # Provenance must be present and survive the import (SPEC §8a W3C-PROV).
  if ! jq -e '.provenance.sourceType != null' "$f" >/dev/null 2>&1; then
    no_prov=$((no_prov+1))
  fi
  cp "$f" "$DEST/"
  imported=$((imported+1))
done

if [ "$no_prov" -gt 0 ]; then
  echo "import: $no_prov finding(s) lack a provenance block; import aborted (provenance must be preserved)" >&2
  exit 1
fi

# Register the topic in the manifest if not already present (lossless add).
NS="$(jq -rs '.[0].namespace // empty' "$DEST"/*.json 2>/dev/null)"
NS="${NS:-harness/$TOPIC}"
if [ -f "$CONFIG" ] && [ "$(jq -r --arg t "$TOPIC" '[.topics[]|select(.id==$t)]|length' "$CONFIG")" = "0" ]; then
  tmp=$(mktemp)
  jq --arg t "$TOPIC" --arg ns "$NS" \
    '.topics += [{"id":$t,"title":$t,"namespace":$ns,"status":"active"}]' "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
  echo "import: registered topic '$TOPIC' (namespace $NS) in $CONFIG"
fi

# Rebuild the index and graph over the imported MIF substrate.
"$ROOT/scripts/build-index.sh" "$DEST" "$REPORTS/$TOPIC/research-index.json" >/dev/null
"$ROOT/scripts/build-graph.sh" "$DEST" "$REPORTS/$TOPIC/knowledge-graph.json" >/dev/null

NODES=$(jq '.nodes|length' "$REPORTS/$TOPIC/knowledge-graph.json")
EDGES=$(jq '.edges|length' "$REPORTS/$TOPIC/knowledge-graph.json")
echo "import: imported $imported finding(s) into $DEST; rebuilt graph ($NODES nodes, $EDGES edges) with provenance intact"
