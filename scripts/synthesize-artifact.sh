#!/usr/bin/env bash
# synthesize-artifact.sh — the report-synthesizer's deterministic substrate
# (SPEC §6d). Consumes the SURVIVING findings (verdict != falsified) under a
# findings dir and produces one typed Artifact (schemas/artifact.schema.json):
# the genre/channel-neutral intermediate that every output channel renders.
#
# Usage: synthesize-artifact.sh <findings-dir> [<genre>] [<out.json>]
#        defaults: genre=general  out=<findings-dir>/../artifact.json

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

DIR="${1:?usage: synthesize-artifact.sh <findings-dir> [genre] [out.json]}"
GENRE="${2:-general}"
OUT="${3:-$DIR/../artifact.json}"
[ -d "$DIR" ] || { echo "synthesize: not a directory: $DIR" >&2; exit 2; }

FILES=$(find "$DIR" -maxdepth 1 -name '*.json' | sort)
[ -n "$FILES" ] || { echo "synthesize: no findings in $DIR" >&2; exit 2; }

# Build the artifact from surviving findings: one section per finding, sources
# deduplicated across the set, finding_refs collected, newsworthiness rolled up.
# shellcheck disable=SC2086
jq -s --arg genre "$GENRE" '
  map(select((.extensions.harness.verification.verdict // "survived") != "falsified")) as $surv
  | ($surv | length) as $n
  | if $n == 0 then error("no surviving findings to synthesize") else . end
  | {
      "@type": "Artifact",
      title: ($surv[0].namespace // "Research" | "Findings: " + .),
      genre: $genre,
      audience: "general",
      newsworthiness: "medium",
      finding_refs: [ $surv[] | .["@id"] ],
      sections: [ $surv[] | {
        heading: .title,
        body: (.content // .summary // .title),
        supports: [ .["@id"] ]
      } ],
      sources: ( [ $surv[] | (.citations // [])[] | { title: .title, url: .url } ]
                 | unique_by(.url) )
    }
' $FILES > "$OUT"

echo "synthesize: wrote $OUT (genre=$GENRE, $(jq '.sections|length' "$OUT") sections, $(jq '.sources|length' "$OUT") sources)"
