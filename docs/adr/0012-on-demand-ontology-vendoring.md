---
title: "On-demand ontology vendoring from a canonical registry"
description: "Fetch domain ontologies on demand from the canonical ontologies registry, verified fail-closed against a pinned sha256 index, instead of bundling every ontology in every clone; keep base layers committed; offer to author-and-contribute a new ontology when none exists."
type: adr
category: architecture
tags: [ontology, vendoring, supply-chain, fail-closed, registry, on-demand]
status: accepted
created: 2026-06-30
updated: 2026-06-30
author: zircote
project: research-harness-template
technologies: [Bash, jq, yq, sha256]
audience: [developers, architects]
related: [0008-attested-fail-closed-supply-chain.md, 0011-fail-closed-ontology-completeness-gate.md]
---

# ADR-0012: On-demand ontology vendoring from a canonical registry

## Context

The harness typed findings against ontology packs that shipped **bundled** —
every domain ontology committed in every clone, kept current by hand. That has
two costs: each clone carries (and must re-sync) ontologies it never binds, and
hand-edits to a vendored copy silently drift it from its canonical definition
(the source of truth is the `ontologies` repo, served at
`https://mif-spec.dev/ontologies/`). The drift is real: a clone's bundled packs
had fallen ~1800 lines behind canonical, and a reviewer once suggested editing a
vendored pack in place — which would have desynced it permanently.

## Decision

Vendor **domain** ontologies on demand from the canonical registry, and keep
**base** layers (`mif-base`, `mif-generic`, `shared-traits`, `engineering-base`)
committed (every finding needs them; no fetch latency, offline-safe).

- The registry publishes `index.json` mapping `id -> {version, file, sha256,
  extends[]}` (`scripts/gen-ontology-index.sh` in the `ontologies` repo).
- `scripts/fetch-ontology.sh <id>` resolves the id's `extends` closure, fetches
  each domain layer not already present, **verifies its sha256 against the index
  fail-closed**, materializes it as `packs/ontologies/<id>/`, and pins the result
  in `ontologies.lock.json`. This reuses the supply-chain stance of ADR-0008
  (verify every downloaded artifact against a pinned hash).
- `scripts/check-ontology-lock.sh` proves every enabled domain ontology matches
  its pinned hash — catching local drift (fixes belong upstream) and missing
  on-demand packs.
- When resolution finds **no** ontology for a domain, the harness is a producer,
  not just a consumer: `scripts/author-ontology.sh <id> <topic>` scaffolds a
  draft ontology from the entity types the topic's findings actually used
  (`reports/<topic>/ontology-map.json`, generic-fallback types first) with
  grounding stubbed, and concierges a draft PR back to the `ontologies` repo.
- Source resolution: `$MIF_ONTOLOGY_SOURCE` / `.ontologies.source` /
  `https://mif-spec.dev/ontologies` (default). A local directory source is read
  for dev/CI/offline; an http source via curl.

## Consequences

- Lean clones; vendored copies are verifiable and drift-proof; edits are forced
  upstream where the source of truth lives.
- A new network/registry dependency for binding a not-yet-present domain
  ontology (mitigated: base layers + already-vendored packs work offline, and the
  lock pins exact content).
- **Adoption is staged.** This decision ships the mechanism. Flipping the bundled
  domain packs to a gitignored on-demand cache, and re-syncing them to canonical,
  is a follow-up that also requires re-enriching the bundled example corpus
  (canonical migrated some entity-type names; pinned findings must be re-pinned —
  the `/ontology-review --enrich` pass) and the registry being served. Until then
  the bundled packs remain committed and the mechanism fetches on demand for any
  not-yet-present ontology.
