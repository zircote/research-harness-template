#!/usr/bin/env bash
# check-readme-reindex.sh — PostToolUse hook (the README "channel").
#
# Fires when a report topic is created or mutated — a finding, a rendered report,
# or the manifest is written/edited — and reminds Claude to reconcile that topic's
# navigation README via the `readme` skill. This is the SAFETY NET for out-of-band
# edits; the deterministic primary trigger is the orchestrator's Phase 4, which
# runs the README build after every synthesis.
#
# NON-BLOCKING: emits an additionalContext reminder only; never blocks the write.
# Excludes README.md itself so the skill's own writes never re-trigger this hook.

INPUT=$(cat /dev/stdin 2>/dev/null)
command -v jq >/dev/null 2>&1 || exit 0

FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null)
[ -n "$FILE_PATH" ] || exit 0

# Normalize to a path relative to the project root.
REL_PATH="${FILE_PATH#"${CLAUDE_PROJECT_DIR:-}"/}"

emit() {
  jq -n --arg ctx "$1" '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: $ctx
    }
  }'
}

case "$REL_PATH" in
  # Never self-trigger on the README the skill writes; research-progress.md is
  # continuity (rewritten every phase), not a report — stay silent on both.
  reports/*/README.md|reports/*/research-progress.md)
    exit 0
    ;;
  reports/*/findings/*.json|reports/*/findings_*.json)
    TOPIC=$(printf '%s' "$REL_PATH" | sed -E 's#reports/([^/]+)/.*#\1#')
    # _meta is scaffolding (sample sessions, templates), not a registered topic.
    [ "$TOPIC" = "_meta" ] && exit 0
    emit "Findings changed for topic '$TOPIC'. Reconcile its navigation README before reporting the topic complete: run the readme skill ('readme --topic $TOPIC') or 'bash scripts/build-topic-readme.sh $TOPIC' then '--check'. New/changed findings must be falsified first (see the research-lifecycle reminder)."
    ;;
  reports/*/*.md)
    TOPIC=$(printf '%s' "$REL_PATH" | sed -E 's#reports/([^/]+)/.*#\1#')
    [ "$TOPIC" = "_meta" ] && exit 0
    emit "Report '$REL_PATH' changed. Update the navigation README for topic '$TOPIC' so its Reports table and counts stay accurate: run the readme skill ('readme --topic $TOPIC') or 'bash scripts/build-topic-readme.sh $TOPIC' then '--check'."
    ;;
  harness.config.json)
    emit "harness.config.json changed (the topic registry). Reconcile every topic README so the indices match the manifest: run the readme skill with '--all', or 'bash scripts/build-topic-readme.sh <topic>' for each affected topic, then '--check'."
    ;;
  *)
    exit 0
    ;;
esac
exit 0
