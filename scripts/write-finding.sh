#!/usr/bin/env bash
# write-finding.sh — write a finding into <findings-dir> ONLY after it validates
# against schemas/findings.schema.json (stage + ajv + atomic rename). On failure
# nothing lands in findings/. This is the write half of crash-safe resume (SPEC §4):
# a finding is visible on disk iff it is valid, so reconcile-session.sh never sees a
# half-written finding and never counts a partial as done.
#
# Usage: write-finding.sh <source.json> <findings-dir> <dest-name.json>
#   exit 0 = validated and renamed into place; non-zero = rejected, nothing written.

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:?usage: write-finding.sh <source.json> <findings-dir> <dest-name.json>}"
FDIR="${2:?findings-dir required}"
NAME="${3:?dest-name.json required}"
[ -f "$SRC" ] || { echo "write-finding: source not found: $SRC" >&2; exit 2; }
mkdir -p "$FDIR"

# Stage hidden + .json-extensioned, on the SAME filesystem as the destination so the
# final mv is an atomic rename. Hidden (.*) so reconcile-session.sh ignores it while
# in flight; .json so ajv selects the JSON parser.
STAGE="$FDIR/.wf-staging-$NAME"
cp "$SRC" "$STAGE"
if ! ajv validate --spec=draft2020 --strict=false -c ajv-formats \
      -s "$ROOT/schemas/findings.schema.json" \
      -r "$ROOT/schemas/mif/mif.schema.json" \
      -r "$ROOT/schemas/mif/definitions/entity-reference.schema.json" \
      -d "$STAGE" >/dev/null 2>&1; then
  rm -f "$STAGE"
  echo "write-finding: $NAME does NOT validate — refused; nothing written to $FDIR" >&2
  exit 1
fi
mv "$STAGE" "$FDIR/$NAME"
echo "write-finding: wrote $FDIR/$NAME (validated)"
