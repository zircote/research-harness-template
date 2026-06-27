#!/usr/bin/env bash
# convert-sigint-corpus.sh — convert one sigint topic directory (findings_<dim>.json
# wrappers) into a MIF corpus staging dir (findings/*.json individual units) that
# import-corpus.sh can consume. This is the sigint->MIF bridge that brings a prior
# (v1) corpus forward into the MIF substrate; the legacy in-place migrate skill was
# cut (SPEC §4a), the import path (this + import-corpus.sh) is how a corpus arrives.
#
# Usage:
#   convert-sigint-corpus.sh <sigint-topic-dir> <staging-dir> [<topic-id>]
#     <sigint-topic-dir> contains findings_<dim>.json wrappers.
#     <staging-dir>      receives findings/*.json (created/cleared).
#     <topic-id>         the MIF topic id baked into each unit's @id + namespace.
#                        MUST match the <topic-id> later passed to import-corpus.sh,
#                        or the registered topic and the units' namespace diverge.
#                        Defaults to basename(<sigint-topic-dir>).
#
# Gated by features.sigintCorpusImport in harness.config.json (HARNESS_CONFIG
# overrides the path) — the conversion path is opt-in, off by default.
#
# Emits to stdout: "<units> unit(s) from <files> file(s)".

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
ROOT="$(pwd)"
JQF="$ROOT/scripts/sigint-to-mif.jq"

SRC="${1:?usage: convert-sigint-corpus.sh <sigint-topic-dir> <staging-dir> [topic-id]}"
STAGE="${2:?usage: convert-sigint-corpus.sh <sigint-topic-dir> <staging-dir> [topic-id]}"
TOPIC="${3:-$(basename "$SRC")}"

# Feature gate: the sigint->MIF conversion path is opt-in (SPEC §7). An instance
# enables it by setting features.sigintCorpusImport=true in harness.config.json.
CONFIG="${HARNESS_CONFIG:-harness.config.json}"
if [ ! -f "$CONFIG" ] || [ "$(jq -r '.features.sigintCorpusImport // false' "$CONFIG" 2>/dev/null)" != "true" ]; then
  echo "convert: features.sigintCorpusImport is not enabled in ${CONFIG}." >&2
  echo "         Enable it (\"features\": { \"sigintCorpusImport\": true }) to convert a sigint corpus." >&2
  exit 2
fi

DEST="$STAGE/findings"
rm -rf "$DEST"; mkdir -p "$DEST"

units=0 files=0
shopt -s nullglob
for wf in "$SRC"/findings_*.json; do
  # Skip reflection/non-finding wrappers and unparseable files.
  jq empty "$wf" 2>/dev/null || { echo "convert: skipping unparseable $wf" >&2; continue; }
  n=$(jq 'if type == "array" then length else ((.findings // []) | length) end' "$wf" 2>/dev/null)
  [ "${n:-0}" -gt 0 ] || continue
  files=$((files + 1))
  # Stream {out, doc}; write each doc to its own file.
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    out=$(printf '%s' "$line" | jq -r '.out')
    printf '%s' "$line" | jq '.doc' > "$DEST/$out"
    units=$((units + 1))
  done < <(jq -c --arg topic "$TOPIC" --arg srcfile "$(basename "$wf" .json)" -f "$JQF" "$wf" 2>/dev/null)
done

# Resolve `updates` relationship targets to the actual in-corpus @id. The unit
# @id is unique (<srcfile>-<idslug>-<index>), but a relationship from
# updates_finding can only name the target by its sigint id; map slug(sourceId) ->
# @id across the staged set and rewrite targets that resolve, so build-graph links
# delta findings to the real node instead of an external placeholder.
if [ "$units" -gt 0 ]; then
  map=$(jq -s 'map(select(.extensions.harness.sourceId != null)
                 | { ((.extensions.harness.sourceId | ascii_downcase | gsub("[^a-z0-9]+";"-") | gsub("^-+|-+$";""))): .["@id"] })
               | add // {}' "$DEST"/*.json)
  for u in "$DEST"/*.json; do
    jq --argjson map "$map" '
      .relationships = ((.relationships // []) | map(
        (.target["@id"] | sub("^urn:mif:concept:[^:]+:"; "")) as $tslug
        | if ($map[$tslug]) then .target = {"@id": $map[$tslug]} else . end
      ))
      | if (.relationships | length) == 0 then del(.relationships) else . end
    ' "$u" > "$u.tmp" && mv "$u.tmp" "$u"
  done
fi

echo "$units unit(s) from $files file(s)"
