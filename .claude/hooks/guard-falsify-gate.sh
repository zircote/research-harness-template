#!/usr/bin/env bash
# guard-falsify-gate.sh — PreToolUse(Bash) deterministic guard for the SINGLE
# falsification gate (SPEC §6b). scripts/falsify.sh is the orchestrator's one
# Phase-2 pass over a topic's findings; it must NOT run ad-hoc — e.g. a dimension-
# analyst looping it over reports/<topic>/findings/ self-grades its siblings, and
# the one-round rule (attempted_at) then makes that premature, evidence-less stamp
# PERMANENT (the real gate skips it).
#
# This is a PHASE gate, not an identity gate, and it is SCOPED to the contamination
# vector — grading a topic's SESSION FINDINGS (reports/<topic>/findings/*.json):
#   - the orchestrator / `/falsify` open a per-topic window by creating
#     reports/<topic>/.gate-active for the duration of the pass;
#   - a falsify.sh tool-call over that topic's findings/ OUTSIDE the window is DENIED.
# falsify.sh over a NON-findings target (a report-finding, a test fixture) is a legit
# non-gate use (report-synthesizer, publish-report, the smoke/eval harnesses) and is
# always allowed. The test harnesses also call falsify.sh as a subprocess of
# `bash scripts/<x>.sh`, which is not a falsify.sh tool-command, so they are unaffected.
set -uo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

INPUT=$(cat /dev/stdin 2>/dev/null)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Only act on a command that invokes the gate script.
printf '%s' "$CMD" | grep -qF 'falsify.sh' || exit 0

# Only guard grading of a topic's SESSION FINDINGS (reports/<topic>/findings/*.json).
# Anything else (report-finding, fixtures) is a legit non-gate use -> allow.
FINDING=$(printf '%s' "$CMD" | grep -oE '[^[:space:]]*reports/[^[:space:]]+/findings/[^[:space:]]+\.json' | head -1)
[ -n "$FINDING" ] || exit 0

# Derive the per-topic gate marker: reports/<topic>/findings/<f>.json -> reports/<topic>/.gate-active
TOPIC_DIR=$(dirname "$(dirname "$FINDING")")
case "$TOPIC_DIR" in
  /*) MARKER="$TOPIC_DIR/.gate-active" ;;
  *)  MARKER="$ROOT/$TOPIC_DIR/.gate-active" ;;
esac
# Allow while THIS topic's gate window is open.
[ -f "$MARKER" ] && exit 0

# Outside the window: DENY (JSON contract, same shape md_guard uses).
REASON="Blocked: scripts/falsify.sh is the orchestrator's SINGLE Phase-2 falsification gate, and this topic's gate window is not open (${TOPIC_DIR}/.gate-active is absent). A dimension-analyst must NEVER grade the session findings — a premature, fixture-less stamp is permanent under the one-round rule and corrupts siblings. The orchestrator (Phase 2) and the /falsify command open the per-topic window and own the single pass; let them run it."
jq -cn --arg r "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
exit 0
