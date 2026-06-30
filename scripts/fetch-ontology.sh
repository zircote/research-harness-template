#!/usr/bin/env bash
# fetch-ontology.sh — on-demand vendoring of a domain ontology pack.
#
# Given an ontology id, this resolves the id's `extends` closure from the
# canonical registry index, fetches each domain layer that is not already
# present, VERIFIES every fetched file's sha256 against the index (fail-closed),
# materializes it as a harness pack under packs/ontologies/<id>/, and pins the
# result in ontologies.lock.json.
#
# Base layers (mif-base, mif-generic, shared-traits, engineering-base) ship
# committed under schemas/ontologies/<id>/ and are NEVER fetched — an extends
# ancestor that resolves to a committed base layer is satisfied locally.
#
# Source (where the index + yaml files live), in precedence order:
#   1. $MIF_ONTOLOGY_SOURCE         (env override; a dir path or http(s):// base)
#   2. .ontologies.source           (file in repo root, one line)
#   3. https://mif-spec.dev/ontologies   (canonical default)
# A local directory source (dev/CI/offline) is read with cp; an http source is
# read with curl. The index is always <source>/index.json.
#
# Usage: fetch-ontology.sh <id> [<id> ...]
#        fetch-ontology.sh --all-enabled        # fetch every enabled domain ontology
#
# Bash 3.2 compatible (no associative arrays): id sets are space-delimited strings.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
ROOT="$(pwd)"

INDEX_NAME="index.json"
LOCK="$ROOT/ontologies.lock.json"
PACKS_DIR="$ROOT/packs/ontologies"
BASE_DIR="$ROOT/schemas/ontologies"
CFG="$ROOT/harness.config.json"

die() { echo "fetch-ontology: $*" >&2; exit 1; }
command -v jq >/dev/null || die "jq is required"
command -v yq >/dev/null || die "yq is required"
SHA="sha256sum"; command -v sha256sum >/dev/null || SHA="shasum -a 256"
sha_of() { $SHA "$1" | awk '{print $1}'; }

# --- resolve source ---------------------------------------------------------
SRC="${MIF_ONTOLOGY_SOURCE:-}"
[ -z "$SRC" ] && [ -f "$ROOT/.ontologies.source" ] && SRC="$(head -n1 "$ROOT/.ontologies.source")"
[ -z "$SRC" ] && SRC="https://mif-spec.dev/ontologies"
SRC="${SRC%/}"
is_http() { case "$1" in http://*|https://*) return 0;; *) return 1;; esac; }

fetch_raw() { # <relpath> <out>
  local rel="$1" out="$2"
  if is_http "$SRC"; then
    curl -fsSL "$SRC/$rel" -o "$out" || return 1
  else
    local base="$SRC"; case "$base" in file://*) base="${base#file://}";; esac
    [ -f "$base/$rel" ] || return 1
    cp "$base/$rel" "$out"
  fi
}

# --- load the registry index ------------------------------------------------
INDEX_FILE="$(mktemp)"; trap 'rm -f "$INDEX_FILE"' EXIT
fetch_raw "$INDEX_NAME" "$INDEX_FILE" || die "cannot read index at $SRC/$INDEX_NAME"
jq -e '.ontologies' "$INDEX_FILE" >/dev/null 2>&1 || die "index at $SRC is malformed (no .ontologies)"

idx() { jq -r --arg id "$1" --arg k "$2" '.ontologies[$id][$k] // empty' "$INDEX_FILE"; }
idx_extends() { jq -r --arg id "$1" '.ontologies[$id].extends[]? // empty' "$INDEX_FILE"; }
is_committed_base() { [ -d "$BASE_DIR/$1" ]; }   # base layer present in-tree

# --- resolve the fetch set: requested ids + extends closure, minus bases -----
seen=" "        # space-delimited, space-padded
queue=""        # space-delimited BFS queue
fetch_list=""   # space-delimited ids that must be fetched (domain layers)
enqueue() { case "$seen" in *" $1 "*) return 0;; esac; seen="$seen$1 "; queue="$queue$1 "; }

if [ "${1:-}" = "--all-enabled" ]; then
  for id in $(jq -r '.ontologies[]? | select(.enabled==true) | .id' "$CFG" 2>/dev/null); do enqueue "$id"; done
  [ -n "${queue// /}" ] || die "no enabled ontologies in $CFG"
else
  [ "$#" -ge 1 ] || die "usage: fetch-ontology.sh <id> [<id> ...] | --all-enabled"
  for id in "$@"; do enqueue "$id"; done
fi

while [ -n "${queue// /}" ]; do
  id="${queue%% *}"; queue="${queue#* }"
  is_committed_base "$id" && continue
  [ -n "$(idx "$id" version)" ] || die "ontology '$id' is not in the registry index at $SRC
  -> it has no canonical definition yet. Author one from your research and contribute it upstream:
       scripts/author-ontology.sh $id"
  case " $fetch_list " in *" $id "*) :;; *) fetch_list="$fetch_list$id ";; esac
  for anc in $(idx_extends "$id"); do enqueue "$anc"; done
done

if [ -z "${fetch_list// /}" ]; then
  echo "fetch-ontology: nothing to fetch (all requested layers are committed base layers)"
  exit 0
fi

# --- fetch + verify + materialize each domain layer -------------------------
[ -f "$LOCK" ] || printf '{\n  "schema": "mif-ontology-lock/v1",\n  "source": "%s",\n  "ontologies": {}\n}\n' "$SRC" > "$LOCK"
lock_tmp="$(mktemp)"; cp "$LOCK" "$lock_tmp"

for id in $fetch_list; do
  file="$(idx "$id" file)"; want="$(idx "$id" sha256)"; ver="$(idx "$id" version)"
  [ -n "$file" ] && [ -n "$want" ] || die "index entry for '$id' is incomplete (file/sha256 missing)"
  tmp="$(mktemp)"
  fetch_raw "$file" "$tmp" || { rm -f "$tmp"; die "failed to fetch $file from $SRC"; }
  got="$(sha_of "$tmp")"
  if [ "$got" != "$want" ]; then
    rm -f "$tmp"
    die "CHECKSUM MISMATCH for '$id' ($file): expected $want got $got
  -> refusing to vendor an ontology that does not match the pinned registry hash (fail-closed)."
  fi
  dest="$PACKS_DIR/$id"; mkdir -p "$dest"
  mv "$tmp" "$dest/$file"
  desc="$(yq -r '.ontology.description // ""' "$dest/$file")"
  jq -n --arg name "$id" --arg ver "$ver" --arg desc "$desc" \
    '{name:$name, version:$ver, kind:"ontology", description:$desc, provides:{ontologies:[$name]}}' \
    > "$dest/ontology.pack.json"
  jq --arg id "$id" --arg v "$ver" --arg sha "$want" \
    '.ontologies[$id] = {version:$v, sha256:$sha}' "$lock_tmp" > "$lock_tmp.2" && mv "$lock_tmp.2" "$lock_tmp"
  echo "fetch-ontology: vendored $id@$ver (sha256 ok) -> packs/ontologies/$id/"
done

jq -S '.' "$lock_tmp" > "$LOCK"; rm -f "$lock_tmp"
echo "fetch-ontology: lock updated ($LOCK). Run scripts/sync-packs.sh to refresh the catalog."
