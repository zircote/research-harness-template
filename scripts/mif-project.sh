#!/usr/bin/env bash
# mif-project.sh — project a MIF-L3 markdown report (YAML frontmatter + Markdown
# body) into its JSON-LD finding projection and validate it at MIF Level 3
# (SPEC §10, output conformance). The frontmatter is the authoritative MIF
# concept; the body is the MIF `content`. A report is "L3 MIF compliant
# markdown" iff this projection validates against schemas/findings.schema.json
# (the same bar as a finding) AND passes the citation-integrity gate (which
# rejects a falsified verdict and dead/malformed citations).
#
# Write-then-validate: render-artifact.sh's `report` channel calls this right
# after writing the .md and fails non-zero if the report does not project to a
# valid L3 finding. gate_m10 in verify.sh calls it over every emitted report.
#
# Usage: mif-project.sh <report.md> [--json-out <out.json>]
#   exit 0 = projects to a valid L3 finding; non-zero = not compliant.

set -uo pipefail

# Resolve the report path against the INVOKING cwd before we cd to the repo root,
# so a caller-relative path (e.g. from an eval working dir) still resolves.
MD="${1:?usage: mif-project.sh <report.md> [--json-out <out.json>]}"
[ -f "$MD" ] || { echo "mif-project: report not found: $MD" >&2; exit 2; }
MD="$(cd "$(dirname "$MD")" && pwd)/$(basename "$MD")"
JSON_OUT=""
if [ "${2:-}" = "--json-out" ]; then
  JSON_OUT="${3:?--json-out needs a path}"
  case "$JSON_OUT" in /*) : ;; *) JSON_OUT="$(pwd)/$JSON_OUT" ;; esac
fi

cd "$(dirname "$0")/.." || exit 2

# A temp dir so the projection carries a .json extension (ajv-cli selects its
# parser by file extension; an extensionless file is mis-parsed).
TMPD="$(mktemp -d)"; TMP="$TMPD/projection.json"; TMPE="$TMPD/err"; trap 'rm -rf "$TMPD"' EXIT

# Project frontmatter + body -> finding JSON (the JSON-LD projection of the MIF
# concept). The body becomes MIF `content` unless the frontmatter sets it.
if ! python3 - "$MD" >"$TMP" 2>"$TMPE" <<'PY'
import sys, json
try:
    import yaml
except Exception as e:  # pragma: no cover
    sys.stderr.write("pyyaml required: %s\n" % e); sys.exit(3)

# Keep ISO 8601 date-times as verbatim strings (preserving the trailing 'Z'):
# the default SafeLoader coerces them to datetime objects, which both break JSON
# serialization and rewrite the value into a non-'Z' form the date-time format
# validator would reject.
class _StrDatesLoader(yaml.SafeLoader):
    pass
for _ch, _resolvers in list(_StrDatesLoader.yaml_implicit_resolvers.items()):
    _StrDatesLoader.yaml_implicit_resolvers[_ch] = [
        (tag, rx) for (tag, rx) in _resolvers if tag != "tag:yaml.org,2002:timestamp"
    ]

text = open(sys.argv[1], encoding="utf-8").read()
lines = text.splitlines(keepends=True)
if not lines or lines[0].strip() != "---":
    sys.stderr.write("no opening YAML frontmatter delimiter ('---' on line 1)\n"); sys.exit(4)
close = next((i for i in range(1, len(lines)) if lines[i].strip() == "---"), None)
if close is None:
    sys.stderr.write("no closing frontmatter delimiter\n"); sys.exit(4)
fm = "".join(lines[1:close])
body = "".join(lines[close + 1:]).strip()
data = yaml.load(fm, Loader=_StrDatesLoader) or {}
if not isinstance(data, dict):
    sys.stderr.write("frontmatter is not a mapping\n"); sys.exit(4)
if not data.get("content"):
    data["content"] = body if body else data.get("title", "")
json.dump(data, sys.stdout, ensure_ascii=False)
PY
then
  echo "mif-project: $MD — frontmatter projection failed:" >&2
  sed 's/^/  /' "$TMPE" >&2
  exit 1
fi

# Validate the projection at MIF L3 (same ajv closure as findings).
if ! ajv validate --spec=draft2020 --strict=false -c ajv-formats \
      -s schemas/findings.schema.json \
      -r schemas/mif/mif.schema.json \
      -r schemas/mif/definitions/entity-reference.schema.json \
      -d "$TMP" >/dev/null 2>&1; then
  echo "mif-project: $MD — projection does NOT validate against findings.schema.json (not MIF L3):" >&2
  ajv validate --spec=draft2020 --strict=false -c ajv-formats \
      -s schemas/findings.schema.json \
      -r schemas/mif/mif.schema.json \
      -r schemas/mif/definitions/entity-reference.schema.json \
      -d "$TMP" 2>&1 | sed 's/^/  /' >&2 || true
  exit 1
fi

# Citation-integrity (rejects a falsified verdict + dead/malformed citations).
if ! scripts/check-citation-integrity.sh "$TMP" >/dev/null 2>&1; then
  echo "mif-project: $MD — fails citation-integrity gate:" >&2
  scripts/check-citation-integrity.sh "$TMP" 2>&1 | sed 's/^/  /' >&2 || true
  exit 1
fi

[ -n "$JSON_OUT" ] && cp "$TMP" "$JSON_OUT"
echo "mif-project: $MD projects to a valid MIF L3 finding"
