# Structured Data Protocol — jq write-then-validate

Files are the sole durable store for the harness. Every structured artifact the
engine writes (findings, config, pack manifests, state) is JSON on disk,
validated against a schema the moment it is written. This is the reliability
backbone carried over from the current harness (design spec §4, "Structured Data
Protocol — KEEP"): no in-memory-only state, no ad-hoc JSON.

## The rule

**Write, then validate, before the artifact is trusted.** A write is not
complete until the artifact validates against its contract. An invalid artifact
is a bug to fix at write time, never a thing to "clean up later".

## Validators

Two validator families, chosen by artifact:

- **JSON Schema (ajv)** — the typed contracts: findings, `harness.config.json`,
  pack manifests. These extend or reference the vendored MIF schema under
  `schemas/mif/`. Validate with:

  ```bash
  ajv validate --spec=draft2020 --strict=false -c ajv-formats \
    -s schemas/findings.schema.json \
    -r schemas/mif/mif.schema.json \
    -r schemas/mif/definitions/entity-reference.schema.json \
    -d <artifact>.json
  ```

  The `-r` flags register the vendored MIF schema closure so the
  `$ref: https://mif-spec.dev/...` references resolve offline.

- **jq predicates** — fast structural assertions and gates that are cheaper as a
  jq program than a full schema (for example the citation-integrity gate,
  `scripts/check-citation-integrity.sh`). A jq validator is a boolean program run
  with `jq -e`; a non-zero exit is a failed validation.

## Write-then-validate, concretely

```bash
# 1. Write the artifact (jq composes it; never hand-edit trusted JSON in place).
jq -n '{ "@context": "...", "@type": "Memory", ... }' > reports/<topic>/finding.json

# 2. Validate immediately. A non-zero exit means the write is not done.
ajv validate --spec=draft2020 --strict=false -c ajv-formats \
  -s schemas/findings.schema.json \
  -r schemas/mif/mif.schema.json \
  -r schemas/mif/definitions/entity-reference.schema.json \
  -d reports/<topic>/finding.json

# 3. Run the citation-integrity gate before the finding is trusted as evidence.
scripts/check-citation-integrity.sh reports/<topic>/finding.json
```

`scripts/verify.sh` runs every contract's schema-against-sample validation and
the citation-integrity gate as part of the build gate, so the protocol is
enforced in CI, not just asserted here.
