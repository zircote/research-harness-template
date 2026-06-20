#!/usr/bin/env bash
# convert-sigint-corpus.sh — convert one sigint topic directory (findings_<dim>.json
# wrappers) into a MIF corpus staging dir (findings/*.json individual units) that
# import-corpus.sh can consume. This is the sigint->MIF bridge that brings a prior
# (v1) corpus forward into the MIF substrate; the legacy in-place migrate skill was
# cut (SPEC §4a), the import path (this + import-corpus.sh) is how a corpus arrives.
#
# Usage:
#   convert-sigint-corpus.sh <sigint-topic-dir> <staging-dir>
#     <sigint-topic-dir> contains findings_<dim>.json wrappers.
#     <staging-dir>      receives findings/*.json (created/cleared).
#
# Emits to stdout: "<units> unit(s) from <files> file(s)".

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
ROOT="$(pwd)"
JQF="$ROOT/scripts/sigint-to-mif.jq"

SRC="${1:?usage: convert-sigint-corpus.sh <sigint-topic-dir> <staging-dir>}"
STAGE="${2:?usage: convert-sigint-corpus.sh <sigint-topic-dir> <staging-dir>}"
TOPIC="$(basename "$SRC")"

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

echo "$units unit(s) from $files file(s)"
