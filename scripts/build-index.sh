#!/usr/bin/env bash
# build-index.sh — incremental research-index maintenance over the MIF substrate
# (SPEC §4a: replace tag-derived recomputation with incremental maintenance).
#
# Emits a flat index of every MIF finding (id, title, dimension, tags, namespace,
# verdict, citation count) that the search/discover/topics services read. The
# index is a projection of the MIF files, so it is always reproducible from them.
#
# It also projects the goal-version membership mirror (SPEC §11): for each finding,
# goal_versions[] (which goal versions it is in scope for) and stale_in[] (the
# versions where its verification has decayed), derived from the authoritative
# per-version members files at <findings-dir>/../goals/*.members.json. The members
# files are the source of truth; this projection is re-derivable.
#
# Usage: build-index.sh <findings-dir> [<out.json>]
#        default out: <findings-dir>/../research-index.json

set -uo pipefail

DIR="${1:?usage: build-index.sh <findings-dir> [out.json]}"
OUT="${2:-$DIR/../research-index.json}"
[ -d "$DIR" ] || { echo "build-index: not a directory: $DIR" >&2; exit 2; }

FILES=$(find "$DIR" -maxdepth 1 -name '*.json' | sort)
[ -n "$FILES" ] || { echo "build-index: no finding JSON in $DIR" >&2; exit 2; }
NFILES=$(printf '%s\n' "$FILES" | grep -c .)

# Membership map: finding-id -> { goal_versions[], stale_in[] }, folded over every
# per-version members file. Empty {} when no goal versions have been resolved yet.
MEMBERS=$(find "$DIR/../goals" -maxdepth 1 -name '*.members.json' 2>/dev/null | sort)
if [ -n "$MEMBERS" ]; then
  # shellcheck disable=SC2086
  MEMBERSHIP=$(jq -s 'reduce .[] as $m ({};
    reduce ($m.members[]) as $id (.; .[$id].goal_versions += [$m.version])
    | reduce ($m.stale[])  as $id (.; .[$id].stale_in     += [$m.version]) )' $MEMBERS)
else
  MEMBERSHIP='{}'
fi

# shellcheck disable=SC2086
jq -s --argjson membership "$MEMBERSHIP" '{
  "@type": "ResearchIndex",
  count: length,
  findings: map({
    id: .["@id"],
    title: (.title // null),
    namespace: (.namespace // null),
    dimension: (.extensions.harness.dimension // null),
    tags: (.tags // []),
    verdict: (.extensions.harness.verification.verdict // null),
    citations: (.citations | length),
    goal_versions: ($membership[.["@id"]].goal_versions // []),
    stale_in: ($membership[.["@id"]].stale_in // [])
  })
}' $FILES > "$OUT"

echo "build-index: wrote $OUT ($(jq '.count' "$OUT") findings) from $NFILES MIF files"
