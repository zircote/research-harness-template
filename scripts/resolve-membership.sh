#!/usr/bin/env bash
# resolve-membership.sh — the deterministic scope-resolution pass (SPEC §11).
#
# For a goal version, classify the topic's existing findings against that version's
# contract and emit the authoritative per-version members file
# reports/<topic>/goals/goal-<version>.members.json:
#
#   { version, generated, members[], stale[], gap_dimensions[] }
#
#   members        — findings IN SCOPE for this version (dimension is one of the
#                    goal's dimensions AND verdict is not "falsified").
#   stale          — in-scope findings whose verification has decayed under
#                    source-type decay (re_verify_by = attempted_at + TTL, where
#                    TTL is the MIN over the finding's citations' citationType
#                    windows from harness.config freshness; a finding with no
#                    attempted_at is freshness-unknown -> stale).
#   gap_dimensions — goal dimensions with no in-scope finding (must be researched).
#
# This is the DETERMINISTIC floor. Ambiguous in/out-of-scope judgement (against the
# goal's out_of_scope/non_goals prose) is layered on top by the goal-writer command,
# which calls this and then refines the members file. The result is a re-derivable
# projection; build-index.sh mirrors goal_versions[] onto each finding from it.
#
# Usage: resolve-membership.sh <topic> [<goal-version>]
#        version defaults to the content hash of reports/<topic>/goal.json.

set -uo pipefail

die() { echo "resolve-membership: $*" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || die "jq is required"

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CONFIG="$PROJECT_DIR/harness.config.json"
HERE="$(cd "$(dirname "$0")" && pwd)"

TOPIC="${1:?usage: resolve-membership.sh <topic> [<goal-version>]}"
TOPIC_DIR="$PROJECT_DIR/reports/$TOPIC"
GOAL="$TOPIC_DIR/goal.json"
FINDINGS_DIR="$TOPIC_DIR/findings"

[ -f "$GOAL" ] || die "no goal for topic \"$TOPIC\": $GOAL"

VERSION="${2:-$(bash "$HERE/goal-version.sh" "$GOAL")}"

DIMS=$(jq -c '.dimensions // []' "$GOAL")
FRESH=$(jq -c '.freshness // {}' "$CONFIG" 2>/dev/null || echo '{}')

FILES=$(find "$FINDINGS_DIR" -maxdepth 1 -name '*.json' 2>/dev/null | sort)

if [ -z "$FILES" ]; then
  CLASSIFIED='{"members":[],"stale":[],"in_scope_dims":[]}'
else
  # shellcheck disable=SC2086
  CLASSIFIED=$(jq -s \
    --argjson dims "$DIMS" \
    --argjson fresh "$FRESH" '
    ($fresh.default_days // 180) as $def
    | ($fresh.by_citation_type // {}) as $byt
    | map(
        (.["@id"]) as $id
        | (.extensions.harness.dimension // null) as $dim
        | ((.extensions.harness.verification.verdict // "none") != "falsified"
           and ($dims | index($dim)) != null) as $in
        | ([ .citations[]?.citationType ] | map($byt[.] // $def) | (min // $def)) as $ttl
        | (.extensions.harness.verification.attempted_at // null) as $att
        | { id: $id, dim: $dim, in_scope: $in,
            stale: (
              if ($in | not) then false
              else (($att | fromdateiso8601?) // null) as $t
                   | if $t == null then true else (now > ($t + $ttl*86400)) end
              end) }
      )
    | { members: [ .[] | select(.in_scope) | .id ],
        stale:   [ .[] | select(.in_scope and .stale) | .id ],
        in_scope_dims: ([ .[] | select(.in_scope) | .dim ] | unique) }' \
    $FILES)
fi

GENERATED=$(date -u +%Y-%m-%dT%H:%M:%SZ)
OUT_DIR="$TOPIC_DIR/goals"
OUT="$OUT_DIR/goal-$VERSION.members.json"
mkdir -p "$OUT_DIR"

jq -n \
  --arg version "$VERSION" \
  --arg generated "$GENERATED" \
  --argjson dims "$DIMS" \
  --argjson c "$CLASSIFIED" '
  {
    version: $version,
    generated: $generated,
    members: $c.members,
    stale: $c.stale,
    gap_dimensions: ($dims - $c.in_scope_dims)
  }' > "$OUT" || die "failed to write $OUT"

echo "wrote $OUT"
jq -r '"  members: \(.members|length) | stale: \(.stale|length) | gap_dimensions: \(.gap_dimensions|join(", ") // "none")"' "$OUT"
