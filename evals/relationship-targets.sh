#!/usr/bin/env bash
# relationship-targets.sh — regression eval for scripts/check-relationship-targets.sh
# (2026-07 data-integrity gap: relationships[].target values that don't resolve to
# any real finding @id — see that script's header for the two root causes).
#
# Proves, against a hermetic temp corpus (never the real reports/ tree):
#   1. a dangling target (references an @id that exists nowhere) -> gate FAILS
#   2. a target pointing only into quarantine/ (falsified, inactive) -> gate FAILS
#   3. the same corpus with both relationships fixed -> gate PASSES
#   4. a malformed (unparseable) finding elsewhere in the corpus -> gate hard-
#      fails (exit 2), rather than silently truncating the active-@id/target
#      universe and missing a real orphan past the bad file
#
# Run: bash evals/relationship-targets.sh   (exit 0 = all assertions hold)
set -uo pipefail
CHECK="$(cd "$(dirname "$0")/.." && pwd)/scripts/check-relationship-targets.sh"
pass=0; fail=0
ok() { echo "PASS: $1"; pass=$((pass+1)); }
no() { echo "FAIL: $1"; fail=$((fail+1)); }

ROOT=$(mktemp -d "${TMPDIR:-/tmp}/rel-targets-eval.XXXXXX"); trap 'rm -rf "$ROOT"' EXIT
RD="$ROOT/reports"
mkdir -p "$RD/t1/findings" "$RD/t1/quarantine"

cat > "$RD/t1/findings/a.json" <<'EOF'
{"@id":"urn:mif:concept:t1:a","relationships":[]}
EOF
cat > "$RD/t1/findings/b.json" <<'EOF'
{
  "@id": "urn:mif:concept:t1:b",
  "relationships": [
    { "type": "relates-to", "target": "urn:mif:concept:t1:does-not-exist", "strength": 0.5 },
    { "type": "relates-to", "target": "urn:mif:concept:t1:quarantined-finding", "strength": 0.5 }
  ]
}
EOF
cat > "$RD/t1/quarantine/quarantined-finding.json" <<'EOF'
{"@id":"urn:mif:concept:t1:quarantined-finding","relationships":[]}
EOF

# 1+2. Both a bare-nonexistent target and a quarantine-only target must fail
# the gate (quarantine/ is deliberately excluded from the active @id universe).
OUT="$ROOT/rel-eval-out"
if "$CHECK" --reports-dir "$RD" >"$OUT" 2>&1; then
  no "gate must fail on a corpus with dangling + quarantined-only targets"
else
  out=$(cat "$OUT")
  if echo "$out" | grep -q "does-not-exist" && echo "$out" | grep -q "quarantined-finding"; then
    ok "gate fails and reports both orphaned targets by name"
  else
    no "gate failed but did not report both orphaned targets: $out"
  fi
fi

# 3. Fix both relationships (relink the dangling one to a real active finding,
# drop the one that points at a deliberately quarantined finding — mirroring
# the two real remediation classes) -> the gate must pass clean.
cat > "$RD/t1/findings/b.json" <<'EOF'
{
  "@id": "urn:mif:concept:t1:b",
  "relationships": [
    { "type": "relates-to", "target": "urn:mif:concept:t1:a", "strength": 0.5 }
  ]
}
EOF
if "$CHECK" --reports-dir "$RD" >/dev/null 2>&1; then
  ok "gate passes once both orphaned targets are remediated"
else
  no "gate still fails after remediation"
fi

# 4. A malformed finding elsewhere in the corpus must hard-fail the gate
# (exit 2), not silently truncate the @id/target universe. Regression for a
# real bug: jq aborts its whole multi-file batch on the first unparseable
# file, so an unguarded run would report the corpus clean (0 findings, 0
# orphans) even though z.json below has a genuine dangling target.
mkdir -p "$RD/t2/findings"
printf '{invalid json' > "$RD/t2/findings/bad.json"
cat > "$RD/t2/findings/z.json" <<'EOF'
{"@id":"urn:mif:concept:t2:z","relationships":[{"type":"relates-to","target":"urn:mif:concept:t2:does-not-exist","strength":0.5}]}
EOF
"$CHECK" --reports-dir "$RD" >"$OUT" 2>&1
rc=$?
if [ "$rc" = 2 ]; then
  ok "gate hard-fails (exit 2) on a malformed finding instead of silently missing the real orphan past it"
else
  no "gate must exit 2 on unparseable JSON, got exit $rc: $(cat "$OUT")"
fi
rm -rf "$RD/t2"

echo "relationship-targets eval: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
