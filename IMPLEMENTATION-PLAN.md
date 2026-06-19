# Research Harness Template — Implementation Plan

This is the build roadmap for the research-harness template. It is derived from
the design specification (Greenfield Research-Harness Template — Design
Specification) and sequences that spec's decision ledger (its sections 4 and 4a)
into eight dependency-ordered phases.

This document is preparation for implementation. It plans and tracks the build;
it does not itself scaffold or build the template. Each phase maps to a GitHub
milestone of the same number, and every work item is tracked as an issue
labelled by its disposition.

Disposition legend: KEEP (carry as-is), REDESIGN (rework), ADD (build new), CUT
(do not carry, recorded by design).

## Phase 1 — Contracts (Milestone #1)

The typed substrate every later phase exchanges. Build the contracts first so
agents, services, packs, and outputs all speak one schema.

Depends on: nothing — this is the foundation.

Work items:

- REDESIGN — Adopt a single MIF-backed findings/knowledge schema (§6c).
- KEEP — Keep the Structured Data Protocol: jq write-then-validate (§7a).
- REDESIGN — Publish harness.config.json plus its JSON Schema (§7).
- ADD — Define the pack.json plugin contract and marketplace.json (§7b).
- ADD — Add the verifier / citation-integrity gate (§6b).

Acceptance gate: each schema validates a sample artifact with ajv or jq, and the
pack contract validates a sample pack manifest.

## Phase 2 — Scaffold (Milestone #2)

Create the repository skeleton from the spec's section 7a tree, with flat skills
and bundled gates so a clone is runnable and self-documenting.

Depends on: Phase 1 (schemas to place under schemas/).

Work items:

- ADD — Scaffold the section 7a tree: flat .claude/skills, agents, commands,
  hooks; .claude-plugin/marketplace.json; packs/; schemas/; scripts/; docs/;
  evals/; reports/ (§7a).
- REDESIGN — Bundle enforcement hooks with the engine (§7a).
- KEEP — Bundle the md-fix skill and markdown hooks (§7a).
- KEEP — Bundle a merged Diataxis documentation set (§7a).

Acceptance gate: a clone opens in Claude Code with no errors, the bundled hooks
fire, and the flat skills are discovered at `.claude/skills/<name>/SKILL.md`.

## Phase 3 — Engine (Milestone #3)

The orchestrator and its agents, reduced to one adversarial gate, driven by a
measurable session goal.

Depends on: Phase 1 (contracts) and Phase 2 (tree).

Work items:

- KEEP — Keep the swarm orchestrator and parallel dimension-analyst fan-out
  (§6b).
- KEEP — Port the orchestrator agent: phase-owning and goal-driven (§6b).
- REDESIGN — Make dimension-analyst dimensions config-declared and
  domain-general (§4a).
- KEEP — Port the falsification-analyst as the single verification gate (§6b).
- KEEP — Port the source-chunker (RLM) agent (§4a).
- REDESIGN — Redesign report-synthesizer as the domain-general output entry
  (§6d).
- KEEP — Keep the adversarial falsification gate (§6b).
- CUT — Drop the four codex review gates (§6b).
- KEEP — Keep continuity: the progress file and resume (§6b).
- KEEP — Wire goal-oriented execution: goal-writer to session goal (§2, §6b).

Acceptance gate: the orchestrator runs toward a sample session goal, one agent
emits a schema-valid MIF finding, and exactly one falsification gate runs.

## Phase 4 — Harness services (Milestone #4)

Search, exploration, discovery, and the knowledge graph, all over the MIF
substrate rather than tag-derived recomputation.

Depends on: Phase 1 (MIF substrate) and Phase 3 (engine produces findings).

Work items:

- REDESIGN — Make the knowledge graph first-class over MIF (§6c).
- REDESIGN — Rebuild the search skill over the MIF index (§4a).
- KEEP — Port the lab skill for interactive exploration (§4a).
- KEEP — Port the discover skill: gaps, clusters, stale (§4a).
- REDESIGN — Fold the graph skill into the MIF-native graph (§4a).
- KEEP — Port the topics skill: registry listing (§4a).
- REDESIGN — Replace reindex/build scripts with incremental MIF maintenance
  (§4a).

Acceptance gate: search, discover, lab, graph, and topics all operate over a MIF
sample, and the graph builds from MIF entities/relations, not tags.

## Phase 5 — Packs (Milestone #5)

Everything optional as plugins on the single extension surface, enabled and
sourced through the manifest.

Depends on: Phase 1 (pack contract), Phase 2 (marketplace), Phase 3 (engine).

Work items:

- CUT — Demote market-research to an optional methodology pack (§7b).
- CUT — Demote issue-architect / GitHub-issues to an optional channel pack
  (§7b).
- ADD — Build the reports genre pack: exec-summary, academic, engineering,
  trend-analysis, briefing; financial and market on demand (§6d).
- KEEP — Ship trend-modeling as an optional methodology pack (§7b).
- CUT — Move discuss (GitHub Discussions) into the channels pack (§7b).
- KEEP — Move nlm-artifacts into the channels pack, optional (§7b).
- KEEP — Move report-pdf into the channels pack, optional (§7b).

Acceptance gate: enabling a pack adds its namespaced skills and disabling removes
them, and an external/private plugin is ingested as a pack via the manifest.

## Phase 6 — Outputs (Milestone #6)

Blog and book as first-class outputs over the typed findings-to-artifact
contract.

Depends on: Phase 1 (contract), Phase 4 (services), Phase 5 (channels pack).

Work items:

- ADD — Promote blog and book to first-class outputs over a typed contract
  (§6d).

Acceptance gate: a sample findings set renders to both a blog post and a book
chapter through the same typed contract.

## Phase 7 — Distribution (Milestone #7)

Package the whole as a living, upgradable template with evals in CI.

Depends on: Phase 2 (tree) and all prior phases (the packaged whole).

Work items:

- ADD — Adopt a Copier-class template with update propagation (§7).
- KEEP — Ship evals and run them in template CI (§7).

Acceptance gate: a copier update re-applies a template change to an instantiated
harness, and the eval suite passes in CI.

## Phase 8 — Corpus/KG migration (Milestone #8)

Drop the legacy migration and plan the first real use: importing the existing
corpus and, above all, its knowledge graph.

Depends on: Phase 1 (MIF schema), Phase 4 (graph), Phase 7 (a working template).

Work items:

- CUT — Drop the legacy v1-to-v2 migrate skill (§4a).
- ADD — Plan the corpus and knowledge-graph import as the first real use; keep
  the MIF substrate and contracts compatible with that import (§10).

Acceptance gate: a sample of the existing corpus and its knowledge graph imports
into a fresh harness with provenance and edges intact.
