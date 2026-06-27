#!/usr/bin/env bash
# wrap-source.sh — normalize a raw ingested source into a MIF source-envelope at
# the ingestion boundary (SPEC §10, inbound conformance) and validate it at MIF
# Level 3 BEFORE any analyst consumes it. Mirrors import-corpus.sh's
# validate-or-abort: a source that does not validate is refused, not silently
# passed downstream. The resulting urn:mif:source:<ns>:<slug> id is what a
# finding's citation references, so a claim traces back to the primary text the
# analyst actually read.
#
# Usage:
#   wrap-source.sh --url <url> --content-type <mime> --namespace <ns> \
#                  --slug <slug> --out <path.json> [--title <t>] \
#                  [--content-file <f> | --content <text>] [--source-type <st>]
#
# Content is taken from --content-file, then --content, then stdin.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

URL="" CT="" NS="" SLUG="" OUT="" TITLE="" CFILE="" CONTENT="" STYPE="agent_inferred"
while [ $# -gt 0 ]; do
  case "$1" in
    --url) URL="$2"; shift 2;;
    --content-type) CT="$2"; shift 2;;
    --namespace) NS="$2"; shift 2;;
    --slug) SLUG="$2"; shift 2;;
    --out) OUT="$2"; shift 2;;
    --title) TITLE="$2"; shift 2;;
    --content-file) CFILE="$2"; shift 2;;
    --content) CONTENT="$2"; shift 2;;
    --source-type) STYPE="$2"; shift 2;;
    *) echo "wrap-source: unknown arg: $1" >&2; exit 2;;
  esac
done
: "${URL:?--url required}" "${CT:?--content-type required}" "${NS:?--namespace required}" \
  "${SLUG:?--slug required}" "${OUT:?--out required}"

[ -n "$TITLE" ] || TITLE="$SLUG"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Compose into a .json temp (ajv-cli picks its parser by extension; .tmp is
# mis-parsed) so validation runs before the envelope reaches its final path.
TMPD="$(mktemp -d)"; TMP="$TMPD/envelope.json"; trap 'rm -rf "$TMPD"' EXIT

# Keep the source body ON DISK and let jq read it with --rawfile. A large source
# (source-chunker's use case) must not be slurped into a shell variable / jq --arg,
# which is memory-heavy and can hit argument-size limits.
CONTENT_FILE="$TMPD/content"
if [ -n "$CFILE" ]; then
  [ -f "$CFILE" ] || { echo "wrap-source: content file not found: $CFILE" >&2; exit 2; }
  CONTENT_FILE="$CFILE"
elif [ -n "$CONTENT" ]; then
  printf '%s' "$CONTENT" > "$CONTENT_FILE"
elif [ ! -t 0 ]; then
  cat > "$CONTENT_FILE"
fi
[ -s "$CONTENT_FILE" ] || { echo "wrap-source: empty content (provide --content-file, --content, or stdin)" >&2; exit 2; }

mkdir -p "$(dirname "$OUT")"
if ! jq -n --arg ns "$NS" --arg slug "$SLUG" --arg title "$TITLE" --rawfile content "$CONTENT_FILE" \
          --arg created "$NOW" --arg url "$URL" --arg ct "$CT" --arg st "$STYPE" '
  {
    "@context": "https://mif-spec.dev/schema/context.jsonld",
    "@type": "Memory",
    "@id": ("urn:mif:source:" + $ns + ":" + $slug),
    memoryType: "episodic",
    namespace: ($ns + "/sources"),
    title: $title,
    content: $content,
    created: $created,
    provenance: { "@type": "Provenance", sourceType: $st, confidence: 0.8, trustLevel: "moderate_confidence" },
    extensions: { harness: { source: { url: $url, fetchedAt: $created, contentType: $ct } } }
  }' > "$TMP"; then
  echo "wrap-source: compose failed" >&2; rm -f "$TMP"; exit 1
fi

# Validate at L3 (abort on fail — the non-negotiable inbound invariant).
if ! ajv validate --spec=draft2020 --strict=false -c ajv-formats \
      -s schemas/mif/source-envelope.schema.json \
      -r schemas/mif/mif.schema.json \
      -r schemas/mif/definitions/entity-reference.schema.json \
      -d "$TMP" >/dev/null 2>&1; then
  echo "wrap-source: $OUT does NOT validate as a MIF source-envelope (refused):" >&2
  ajv validate --spec=draft2020 --strict=false -c ajv-formats \
      -s schemas/mif/source-envelope.schema.json \
      -r schemas/mif/mif.schema.json \
      -r schemas/mif/definitions/entity-reference.schema.json \
      -d "$TMP" 2>&1 | sed 's/^/  /' >&2 || true
  rm -f "$TMP"; exit 1
fi
mv "$TMP" "$OUT"
echo "wrap-source: wrote $OUT (urn:mif:source:$NS:$SLUG, $CT)"
