#!/usr/bin/env bash
# ontology-review.sh — review + validate ontology coverage across topics (SPEC §8c).
#
# For each topic, resolves every finding's ontology mapping (refreshing
# reports/<topic>/ontology-map.json via resolve-ontology.sh) and prints a coverage
# summary: STAMPED (a durable entity_type is actually written on the finding —
# resolve-ontology.sh basis "declared" or "resolved"), DISCOVERY (basis "discovery":
# the finding has NO entity block; resolve-ontology.sh's content-pattern fallback
# guessed a type at review time, but that guess is never written back to the
# finding — re-running loses it, and a reader of the finding file sees no ontology
# at all), UNTYPED (no entity/ontology, no discovery match either), and
# unresolved/invalid (a stamped type that does not resolve or whose entity fails the
# type schema). Read-only except the derived ontology-map.json and, with
# --followup, the backlog file it writes. This is the deterministic engine
# behind the /ontology-review tool; the tool adds the agent enrichment (bind an
# ontology to an unbound topic, retro-classify untyped AND discovery-basis
# findings).
#
# DISCOVERY was previously folded into the same "typed" bucket as STAMPED, which
# made a topic read as fully classified when in fact none of its findings carried a
# real ontology stamp on disk — the exact gap `--followup` exists to surface.
#
# Also runs check-relationship-targets.sh once, corpus-wide, after the
# per-topic loop: proves every relationships[].target resolves to a real,
# active finding @id (catches dangling references left by bare/guessed target
# slugs or by a quarantine that was never cascaded — see that script's header).
#
# Usage: ontology-review.sh [--topic <id>] [--strict] [--reports-dir <p>]
#                           [--config <p>] [--catalog <p>] [--followup <path>]
#   exit 0 = reviewed; with --strict, non-zero if any finding is unresolved/invalid
#            or any relationships[].target is orphaned. --strict does NOT fail on
#            DISCOVERY or UNTYPED findings — those are backlog, not corruption; use
#            --followup to track them.
#   --followup <path>  write a JSON backlog of every finding that is NOT durably
#                       stamped (DISCOVERY, UNTYPED, or invalid/unresolved), grouped
#                       by topic, to <path>. Deterministic: sorted, no timestamps.

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/harness.config.json"
CATALOG="$ROOT/.claude/enabled-packs.json"
RD="$ROOT/reports"
ONE_TOPIC=""; STRICT=0; FOLLOWUP=""
while [ $# -gt 0 ]; do
  case "$1" in
    --topic) ONE_TOPIC="$2"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    --reports-dir) RD="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    --catalog) CATALOG="$2"; shift 2 ;;
    --followup) FOLLOWUP="$2"; shift 2 ;;
    *) echo "ontology-review: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -f "$CONFIG" ] || { echo "ontology-review: config not found: $CONFIG" >&2; exit 2; }

# A catalog is required to resolve anything; if absent, run sync-packs first.
if [ ! -f "$CATALOG" ]; then
  echo "ontology-review: catalog missing — running sync-packs.sh first" >&2
  "$ROOT/scripts/sync-packs.sh" >/dev/null 2>&1 || { echo "ontology-review: sync-packs failed" >&2; exit 3; }
fi

if [ -n "$ONE_TOPIC" ]; then topics="$ONE_TOPIC"; else topics=$(jq -r '.topics[].id' "$CONFIG"); fi

followup_all='{}'
if [ -n "$FOLLOWUP" ]; then
  idmap_tmp=$(mktemp "${TMPDIR:-/tmp}/ontology-review-idmap.XXXXXX")
  trap 'rm -f "$idmap_tmp"' EXIT
fi

g_total=0 g_stamped=0 g_discovery=0 g_untyped=0 g_bad=0 g_topics=0 any_bad=0
printf '%-28s %-22s %6s %8s %10s %8s %9s\n' "TOPIC" "BOUND" "FIND" "STAMPED" "DISCOVERY" "UNTYPED" "INVALID"
for topic in $topics; do
  fdir="$RD/$topic/findings"
  [ -d "$fdir" ] || continue
  g_topics=$((g_topics+1))
  map="$RD/$topic/ontology-map.json"
  bound=$(jq -r --arg t "$topic" '.topics[]|select(.id==$t)|.ontologies // [] | join(",")' "$CONFIG"); [ -z "$bound" ] && bound="(core-only)"
  rm -f "$map"   # rebuild deterministically from disk
  [ -n "$FOLLOWUP" ] && : > "$idmap_tmp"
  nfiles=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    nfiles=$((nfiles+1))
    "$ROOT/scripts/resolve-ontology.sh" "$f" --topic "$topic" --catalog "$CATALOG" --config "$CONFIG" --map "$map" >/dev/null 2>&1 || true
    if [ -n "$FOLLOWUP" ]; then
      fid=$(jq -r '."@id" // .id // empty' "$f" 2>/dev/null); [ -z "$fid" ] && fid="$(basename "$f")"
      printf '%s\t%s\n' "$fid" "${f#"$ROOT"/}" >> "$idmap_tmp"
    fi
  done < <(find "$fdir" -maxdepth 1 -type f -name '*.json' ! -name '.*' ! -name '*.tmp' 2>/dev/null | sort)

  records=0; stamped=0; discovery=0; untyped=0; bad=0
  if [ -f "$map" ]; then
    records=$(jq 'length' "$map")
    stamped=$(jq '[.[] | select((.basis == "declared" or .basis == "resolved") and .valid)] | length' "$map")
    discovery=$(jq '[.[] | select(.basis == "discovery" and .valid)] | length' "$map")
    untyped=$(jq '[.[] | select(.basis == "untyped")] | length' "$map")
    bad=$(jq '[.[] | select(.valid == false)] | length' "$map")
  fi
  # Reconcile: every finding file must produce a record. A gap means the resolver
  # could not even run on a finding (broken env / unreadable file) — count it as
  # invalid so a silent 0/0/0 can never read as clean.
  gap=$((nfiles - records)); [ "$gap" -lt 0 ] && gap=0
  bad=$((bad + gap)); local_total=$nfiles
  [ "$bad" -gt 0 ] && any_bad=1
  printf '%-28s %-22s %6s %8s %10s %8s %9s\n' \
    "$topic" "$(printf '%s' "$bound" | cut -c1-22)" "$local_total" "$stamped" "$discovery" "$untyped" "$bad"
  g_total=$((g_total+local_total)); g_stamped=$((g_stamped+stamped))
  g_discovery=$((g_discovery+discovery)); g_untyped=$((g_untyped+untyped)); g_bad=$((g_bad+bad))

  if [ -n "$FOLLOWUP" ]; then
    idobj=$(jq -R -s 'split("\n") | map(select(length>0) | split("\t")) | map({(.[0]): .[1]}) | add // {}' "$idmap_tmp")
    map_content='[]'; [ -f "$map" ] && map_content=$(cat "$map")
    known_ids=$(jq -c '[.[].finding_id]' <<<"$map_content")
    # A finding whose file caused resolve-ontology.sh to exit before it ever
    # called record() (invalid JSON, missing tool, unreadable ontology) has no
    # map entry at all — it's exactly the "$gap" case folded into INVALID above.
    # Without this, such a finding would be silently absent from the backlog
    # even though the coverage line above already counts it as invalid.
    topic_followup=$(jq -c -n --argjson map "$map_content" --argjson idobj "$idobj" --argjson known "$known_ids" '
      ( $map
        | map(select(.basis == "discovery" or .basis == "untyped" or .valid == false))
        | map({finding_id, file: ($idobj[.finding_id] // null), basis, entity_type,
               resolved_ontology, valid}) )
      +
      ( $idobj | to_entries
        | map(select(.key as $k | ($known | index($k)) == null))
        | map({finding_id: .key, file: .value, basis: "gap", entity_type: null,
               resolved_ontology: null, valid: false}) )
      | sort_by(.finding_id)')
    if [ "$(printf '%s' "$topic_followup" | jq 'length')" -gt 0 ]; then
      followup_all=$(jq -c --argjson add "$topic_followup" --arg t "$topic" '. + {($t): $add}' <<<"$followup_all")
    fi
  fi
done

# Write the followup backlog now, before the corpus-wide relationship check
# below: that check can exit 2 (environment/parse failure) and abort the
# script, which must not silently discard a backlog that's already computed.
if [ -n "$FOLLOWUP" ]; then
  mkdir -p "$(dirname "$FOLLOWUP")"
  if jq -S -n --argjson t "$followup_all" \
    '{topics: $t, total_needs_followup: ([$t[] | length] | add // 0)}' > "$FOLLOWUP.tmp"; then
    mv "$FOLLOWUP.tmp" "$FOLLOWUP"
    echo "ontology-review: followup backlog written to $FOLLOWUP ($(jq -r '.total_needs_followup' "$FOLLOWUP") finding(s) across $(jq -r '.topics | length' "$FOLLOWUP") topic(s))"
  else
    rm -f "$FOLLOWUP.tmp"
    echo "ontology-review: failed to write followup backlog to $FOLLOWUP" >&2
    exit 2
  fi
fi
# Relationship-graph integrity: every relationships[].target must resolve to a
# real, active finding @id (corpus-wide, not per-topic — see
# check-relationship-targets.sh for the root-cause history and known limits).
# Runs (and prints) before the coverage summary below, which callers treat as
# the final line of output.
rel_bad=0
if [ -d "$RD" ]; then
  # Mirror the per-topic loop's own "$fdir doesn't exist -> skip" behavior
  # above: a reports dir that doesn't exist at all (fresh checkout) is
  # nothing-to-check, not a failure.
  "$ROOT/scripts/check-relationship-targets.sh" --reports-dir "$RD"
  rel_rc=$?
  if [ "$rel_rc" = 1 ]; then
    # Orphaned relationships[].target values — this is the condition the
    # message below names.
    rel_bad=1
    any_bad=1
  elif [ "$rel_rc" != 0 ]; then
    # Usage/environment error (missing jq, or a finding jq cannot parse —
    # see check-relationship-targets.sh's own exit-2 contract). Do not fold
    # this into rel_bad/"orphaned" — that would misreport an environment
    # failure as a data-integrity finding.
    echo "ontology-review: check-relationship-targets.sh failed (exit $rel_rc, not an orphan finding) — see its output above" >&2
    exit 2
  fi
fi

echo "---"
printf 'ontology-review: %d topic(s); %d findings — %d stamped, %d discovery-only, %d untyped, %d invalid/unresolved\n' \
  "$g_topics" "$g_total" "$g_stamped" "$g_discovery" "$g_untyped" "$g_bad"

if [ "$STRICT" = 1 ] && [ "$any_bad" = 1 ]; then
  [ "$g_bad" -gt 0 ] && echo "ontology-review: --strict and $g_bad finding(s) have an invalid/unresolved mapping — failing" >&2
  [ "$rel_bad" = 1 ] && echo "ontology-review: --strict and one or more relationships[].target values are orphaned — failing" >&2
  exit 1
fi
exit 0
