# Reference: contracts

The typed substrate every layer exchanges. All contracts live under `schemas/`.

## Findings — `schemas/findings.schema.json`

A finding **is** a MIF v1.0 memory unit (design spec §6c). The schema
`allOf`-extends the real vendored MIF schema (`schemas/mif/mif.schema.json`) with
two harness-local requirements (§8b):

- `citations` — a non-empty array of MIF Level 3 citations (citation-integrity).
- `extensions.harness` — `dimension` (the config-declared dimension) and
  `verification` (the adversarial-falsification verdict: one of `falsified`,
  `weakened`, `survived`, `inconclusive`, with a `verdict_basis`).

Validate with the vendored MIF closure registered:

```bash
ajv validate --spec=draft2020 --strict=false -c ajv-formats \
  -s schemas/findings.schema.json \
  -r schemas/mif/mif.schema.json \
  -r schemas/mif/definitions/entity-reference.schema.json \
  -d <finding>.json
```

## Manifest — `harness.config.schema.json`

The deploy contract. Required: `version`, `topics`, `dimensions`, `packs`.
`packs[].source` is either the `"bundled"` constant or an external/private
plugin object (`{type, url, ref}`). See `harness.config.json` for a sample.

## Pack — `schemas/pack.schema.json`

A pack is a Claude Code plugin. Required: `name`, `version`, `kind` (one of
`methodology`, `genre`, `channel`, `ontology`). `provides.skills` lists the
plugin's skills. The bundled plugins are listed in
`.claude-plugin/marketplace.json`.

**One plugin per skill** (see [pack-structure](../explanation/pack-structure.md)):
each skill is its own plugin under `packs/<pack>/<skill>/`, so a clone enables
exactly the skills it wants without adopting a whole pack. The pack directory
(`packs/reports/`, `packs/market-research/`, …) is a *family container*, not a
plugin; the plugins are its `<skill>/` subdirectories.

## Structured Data Protocol

See [STRUCTURED-DATA.md](../../schemas/STRUCTURED-DATA.md): write JSON with `jq`,
then validate immediately. A write is not complete until the artifact validates.

## Citation-integrity gate

`scripts/check-citation-integrity.sh <findings.json>` asserts every finding has
at least one well-formed, live citation and no `falsified` verdict. Exit 0 =
pass, exit 1 = violation (one diagnostic line per violation).

## Generic report — `reports/<topic>/<slug>.md` (MIF Level-3 markdown)

The canonical MIF Level-3 output and source of truth (SPEC §10). A report **is** a
MIF concept serialized as markdown: authoritative YAML frontmatter (the MIF fields
— `@id`, `conceptType`, `created`, `citations`, `provenance`,
`extensions.harness.{dimension,verification}`) over a Markdown body that becomes the
MIF `content`. `scripts/mif-project.sh <report.md>` projects frontmatter+body to
JSON and validates it against `findings.schema.json` (the **same bar as a finding**)
plus the citation-integrity gate — so a report carries a real, non-falsified
falsification verdict, exactly like a finding. `scripts/render-artifact.sh
<artifact.json> report <out.md> <verification.json>` emits it write-then-validated
(fails closed on a non-conformant report).

## Source envelope — `schemas/mif/source-envelope.schema.json`

The inbound boundary contract. A raw ingested source normalized into a MIF memory
unit: `allOf`-extends the vendored MIF schema with required `provenance.sourceType`
and `extensions.harness.source` (`url`, `fetchedAt`, `contentType`).
`scripts/wrap-source.sh` composes and validates one, refusing (non-zero) any source
that does not validate at L3 before an analyst consumes it.

## Exemption

A report is exempt from L3 only when its format is orthogonal to the result, and
only when **declared**: first-class channels in `harness.config.json`
`outputs[].mifExempt: true`, channel packs in `plugin.json` `mif.exempt: true`.
Genres are L3 by default; exemption is for orthogonal formats, never genres.
`verify.sh` `gate_m10` enforces all of the above and logs every exempt surface.

## Session state — `schemas/session-state.schema.json`

The crash-safe resume checkpoint (SPEC §6b). `scripts/reconcile-session.sh
<reports-dir>` derives `reports/<topic>/state.json` **purely from disk** — per
finding `{id, dimension, valid, attempted_at, verdict}`, per-dimension
`{total, done}`, and per completion-check `{check, passed}` — then prints the
remaining-work plan. A finding is **done** only when it is schema-valid AND gated
(`extensions.harness.verification.attempted_at` present); invalid findings and
`*.tmp`/hidden partial writes are excluded from done-counts, so `/resume` never
reworks completed findings. Reconcile is byte-deterministic and idempotent (no
wall-clock field; sorted records) — two runs over the same disk produce identical
output. `scripts/write-finding.sh <src> <findings-dir> <name>` is the write half:
a finding lands in `findings/` only after it validates (stage + ajv + atomic
rename), so a half-written finding is never visible. `verify.sh` `gate_m11`
asserts all of this against a fixture session.
