---
title: "Vendor ontologies on demand"
description: "Fetch a domain ontology from the canonical registry, verify it against its pinned hash, and author-and-contribute a new one when none exists."
diataxis_type: how-to
---

# Vendor ontologies on demand

Domain ontologies are fetched from the canonical registry (the `ontologies` repo,
served at `https://mif-spec.dev/ontologies/`) and verified fail-closed against a
pinned `sha256`. Base layers (`mif-base`, `mif-generic`, `shared-traits`,
`engineering-base`) ship committed and are never fetched. See
[ADR-0012](../adr/0012-on-demand-ontology-vendoring.md).

## Fetch a domain ontology

```sh
scripts/fetch-ontology.sh scientific          # one ontology + its extends closure
scripts/fetch-ontology.sh --all-enabled       # every ontology enabled in harness.config.json
scripts/sync-packs.sh                          # refresh the catalog after fetching
```

Each fetch resolves the `extends` closure, fetches every domain layer not already
present, verifies its `sha256` against the registry index (a mismatch aborts and
writes nothing), materializes `packs/ontologies/<id>/`, and pins the result in
`ontologies.lock.json`.

## Point at a source

Resolution order: `$MIF_ONTOLOGY_SOURCE`, then `.ontologies.source` (one line in
the repo root), then the default `https://mif-spec.dev/ontologies`. Use a local
directory for offline or CI runs:

```sh
MIF_ONTOLOGY_SOURCE=/path/to/ontologies/ontologies scripts/fetch-ontology.sh --all-enabled
```

## Verify vendored copies have not drifted

```sh
scripts/check-ontology-lock.sh    # every enabled domain ontology matches its pinned sha256
```

Vendored copies are **not** edited in place — a fix belongs **upstream** in the
`ontologies` repo, after which you re-fetch. The gate fails on any local drift.

## When no ontology exists: author one from your research

If a topic needs a domain the registry does not cover, fetch fails with a pointer
to author one. The harness drafts it from the entity types your findings already
used:

```sh
scripts/author-ontology.sh clinical-trials my-topic            # scaffold a draft
scripts/author-ontology.sh clinical-trials my-topic --open-pr  # concierge a draft PR upstream
```

The draft lists the topic's observed entity types (generic-fallback ones first),
with grounding (`source_vocab` / `source_class` / `prior_art`) stubbed `TODO` for
you to fill with a cited authority before the upstream PR merges.
