#!/usr/bin/env bash
# verify.sh — the harness build gate.
#
# Accretive by design: each milestone appends a `gate_mN` function and registers
# it in GATES. The whole script must always exit 0 when every registered gate
# passes. Run from the repository root.
#
#   bash scripts/verify.sh
#
# Requires: jq, ajv (ajv-cli) + ajv-formats. markdownlint-cli2 is run separately
# by CI / the G5 lint gate.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
ROOT="$(pwd)"

PASS=0
FAIL=0
RED=$'\033[31m'; GREEN=$'\033[32m'; DIM=$'\033[2m'; RST=$'\033[0m'

ok()   { PASS=$((PASS+1)); printf '%s  ok %s %s\n' "$GREEN" "$RST" "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '%sFAIL%s %s\n'   "$RED"   "$RST" "$1"; }
info() { printf '%s--- %s%s\n' "$DIM" "$1" "$RST"; }

# ajv invocation with the vendored MIF schema closure registered.
ajv_mif() { # ajv_mif <schema> <data>
  ajv validate --spec=draft2020 --strict=false -c ajv-formats \
    -s "$1" \
    -r schemas/mif/mif.schema.json \
    -r schemas/mif/definitions/entity-reference.schema.json \
    -d "$2" >/dev/null 2>&1
}

ajv_plain() { # ajv_plain <schema> <data>
  ajv validate --spec=draft2020 --strict=false -c ajv-formats \
    -s "$1" -d "$2" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Milestone 1 — Contracts
# ---------------------------------------------------------------------------
gate_m1() {
  info "Milestone 1 — Contracts"

  # 1a. Each schema validates its paired sample (G3).
  if ajv_mif schemas/findings.schema.json schemas/samples/finding.sample.json; then
    ok "findings schema validates sample (MIF-backed)"
  else
    bad "findings schema does not validate sample"
  fi

  if ajv_plain harness.config.schema.json harness.config.json; then
    ok "harness.config schema validates sample manifest"
  else
    bad "harness.config schema does not validate sample manifest"
  fi

  if ajv_plain schemas/pack.schema.json schemas/samples/pack.sample.json; then
    ok "pack schema validates sample pack manifest"
  else
    bad "pack schema does not validate sample pack manifest"
  fi

  # 1b. marketplace.json is valid JSON.
  if jq -e . .claude-plugin/marketplace.json >/dev/null 2>&1; then
    ok "marketplace.json parses as valid JSON"
  else
    bad "marketplace.json is not valid JSON"
  fi

  # 1c. Citation-integrity gate flags BAD and passes GOOD (G4).
  if scripts/check-citation-integrity.sh schemas/samples/citation-good.sample.json >/dev/null 2>&1; then
    ok "citation-integrity gate PASSES the GOOD sample"
  else
    bad "citation-integrity gate rejected the GOOD sample"
  fi
  if scripts/check-citation-integrity.sh schemas/samples/citation-bad.sample.json >/dev/null 2>&1; then
    bad "citation-integrity gate PASSED the BAD sample (should flag it)"
  else
    ok "citation-integrity gate FLAGS the BAD sample"
  fi

  # 1d. Contamination scrub: no corpus finding IDs or corpus report-slug paths
  #     in built artifacts (criteria "Constraints"). Planning docs are excluded;
  #     they are meta, not built artifacts.
  # git grep handles filenames with spaces and an empty match set safely (it
  # never reads stdin and returns 1 on no match), unlike `git ls-files | xargs grep`.
  local hits
  hits=$(git grep -nE 'f_(tech|competitive|trends|customer|sizing|financial|regulatory)_[0-9]+|reports/[a-z0-9][a-z0-9-]+/findings_' -- \
           ':!COMPLETION-CRITERIA.md' ':!IMPLEMENTATION-PLAN.md' ':!PROGRESS.md' 2>/dev/null || true)
  if [ -z "$hits" ]; then
    ok "no corpus finding IDs or corpus report-slug paths in built artifacts"
  else
    bad "corpus contamination found in built artifacts:"
    printf '%s\n' "$hits" >&2
  fi
}

# ---------------------------------------------------------------------------
# Gate registry — each milestone appends its function name here.
# ---------------------------------------------------------------------------
GATES=(gate_m1)

for g in "${GATES[@]}"; do "$g"; done

echo
if [ "$FAIL" -gt 0 ]; then
  printf '%sverify.sh: %d passed, %d FAILED%s\n' "$RED" "$PASS" "$FAIL" "$RST"
  exit 1
fi
printf '%sverify.sh: %d passed, 0 failed%s\n' "$GREEN" "$PASS" "$RST"
exit 0
