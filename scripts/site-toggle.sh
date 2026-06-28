#!/usr/bin/env bash
# site-toggle.sh — flip the Astro/Starlight site-projection controls in a harness
# manifest (`.site`, the control plane read by astro.config.mjs at build time).
# This is the one-line manifest edit a clone makes to choose which surface leads
# (reports vs docs) or to turn an optional site plugin on/off. Unlike pack-toggle,
# there is no re-materialize step: astro.config.mjs reads `.site` directly, so the
# change takes effect on the next `npm run build`.
#
# Usage:
#   site-toggle.sh primary <reports|docs|auto> [<harness.config.json>]
#   site-toggle.sh plugin  <llmsTxt|mermaid|imageZoom|linksValidator> <on|off> [<harness.config.json>]

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

SUB="${1:?usage: site-toggle.sh primary <reports|docs|auto> | plugin <name> <on|off> [config]}"

case "$SUB" in
  primary)
    VALUE="${2:?usage: site-toggle.sh primary <reports|docs|auto> [config]}"
    CFG="${3:-harness.config.json}"
    [ -f "$CFG" ] || { echo "site-toggle: config not found: $CFG" >&2; exit 2; }
    case "$VALUE" in
      reports|docs|auto) ;;
      *) echo "site-toggle: primary must be reports|docs|auto" >&2; exit 2 ;;
    esac
    tmp=$(mktemp)
    jq --arg v "$VALUE" '.site = (.site // {}) | .site.primarySurface = $v' "$CFG" > "$tmp" && mv "$tmp" "$CFG"
    echo "site-toggle: primarySurface -> $VALUE in $CFG"
    ;;
  plugin)
    NAME="${2:?usage: site-toggle.sh plugin <llmsTxt|mermaid|imageZoom|linksValidator> <on|off> [config]}"
    STATE="${3:?usage: site-toggle.sh plugin <name> <on|off> [config]}"
    CFG="${4:-harness.config.json}"
    [ -f "$CFG" ] || { echo "site-toggle: config not found: $CFG" >&2; exit 2; }
    case "$NAME" in
      llmsTxt|mermaid|imageZoom|linksValidator) ;;
      *) echo "site-toggle: unknown plugin '$NAME' (llmsTxt|mermaid|imageZoom|linksValidator)" >&2; exit 2 ;;
    esac
    case "$STATE" in
      on)  EN=true ;;
      off) EN=false ;;
      *)   echo "site-toggle: state must be on|off" >&2; exit 2 ;;
    esac
    tmp=$(mktemp)
    jq --arg n "$NAME" --argjson en "$EN" \
      '.site = (.site // {}) | .site.plugins = (.site.plugins // {}) | .site.plugins[$n] = $en' "$CFG" > "$tmp" && mv "$tmp" "$CFG"
    echo "site-toggle: plugin $NAME -> enabled=$EN in $CFG"
    ;;
  *)
    echo "site-toggle: unknown subcommand '$SUB' (primary|plugin)" >&2
    exit 2
    ;;
esac

echo "site-toggle: rebuild with 'npm run build' (or 'npm run dev') to apply."
