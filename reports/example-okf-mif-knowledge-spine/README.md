# Example: OKF+MIF as a foundational research knowledge spine

**Research ID:** example-okf-mif-knowledge-spine
**Created:** 2026-06-28 | **Updated:** 2026-06-28
**Findings:** 36 (survived 31, weakened 5) | **Sources:** 84 unique URLs
**Status:** archived

---

## Purpose

Decide whether MIF should serve as the modeling, provenance, and temporal spine beneath OKF's accessible, git-distributable packaging layer for a foundational research knowledge spine — testing that layering on four axes: technical feasibility, differentiation from prior art, adoption trajectory, and market reality.

## Dimensions

landscape, market, technical, trajectory

## Key Findings

- **Technically feasible by design, with one resolvable tension.** OKF v0.1 requires consumers to preserve unknown frontmatter keys, giving MIF a non-breaking extension seam for its typed relationships, PROV-O-compatible provenance, bi-temporal/decay, and ontology fields; the one real friction — OKF's permissive consumer model vs. MIF's fail-closed validation — resolves by validating at an ingestion-time enrichment pass, and MIF→OKF degradation is lossless (types fall back to annotated prose links).
- **Differentiation is structural, not cosmetic.** Every prior art sits elsewhere on the depth-vs-accessibility curve: RDF/OWL, SKOS, PROV-O, JSON-LD/schema.org, and Frictionless Data deliver semantics only at Semantic-Web toolchain cost, while Obsidian/Logseq/Roam deliver the markdown surface but with untyped links and no provenance. OKF+MIF uniquely fills the "structured but accessible" cell — PROV-O semantics at plain-JSON authoring cost, no triple store.
- **The strongest tailwind is the failure of schema-less RAG.** Graph-grounded retrieval scores 56.2% vs 16.7% ungrounded (3.4x) and 90%+ where pure vector scores 0%, and provenance plus temporal validity are the documented hard problems of agent memory (Mem0's temporal abstraction degrades to 49% at 10M tokens). Demand for exactly MIF's typed-relationship-plus-provenance layer is being created right now.
- **Adoption momentum is asymmetric — but the asymmetry is distribution, not maturity.** MIF is the older, already-stabilized spec (v1.0.0 Release Candidate, public since early 2026), predating OKF v0.1 (launched 12 June 2026 with Google weight and 5,440 GitHub stars) by ~four months. What MIF lacks is OKF's distribution: two single-author reference implementations (subcog, mnemonic), no governance body, no independent adopters yet. The favorable trajectory is real but conditional on OKF seeding the practitioner base MIF's stabilized semantic layer would enrich.
- **The market pain is large and survived the gate; the OKF+MIF-specific bet is not yet proven.** Institutional-memory loss runs ~$31.5B/year at Fortune 500s, knowledge-graph grounding lifts LLM answer accuracy from 16.7% to 54.2%, and the combined KM + enterprise-KG TAM exceeds ~$25B in 2025 — but demand for structured formats in general does not transfer automatically to OKF+MIF, and the disconfirming finding (OKF 16 days old with no ecosystem; minimalism possibly being the buyer preference rather than a gap) survived at full strength.
- **Five findings were weakened, not falsified — discount the specific numbers, keep the theses.** Four market findings carry overstated or unverified statistics (the Gartner "80% AI-agent adoption by Q1 2026" should read 40% by end-2026 from <5%; the a16z "76% SaaS" figure is unverified; AI-KM sizing figures do not reconcile), and one technical finding mislabels "nine MIF-native core relationship types" when only four (relates-to, derived-from, supersedes, part-of) are spec-core. Each capability claim holds; each disputed number travels with its caveat.
- **Net guidance: build now, stage the scale-up.** Building the layering is low-regret (MIF attaches to OKF's existing seam and degrades back to prose if wound down); lead with a trivially cheap Level-1 entry to avoid the Semantic Web's "too much ceremony" failure; and gate further investment on OKF demonstrating independent, non-Google ecosystem traction and on evidence that adopters actually want the heavier semantic layer.

## Reports

| File | Description |
| --- | --- |
| [`2026-06-28-falsification-report.md`](2026-06-28-falsification-report.md) | Full research report |
| [`report-academic.md`](report-academic.md) | Document |
| [`report-briefing.md`](report-briefing.md) | Document |
| [`report-competitive-analysis.md`](report-competitive-analysis.md) | Document |
| [`report-competitive-quadrant.md`](report-competitive-quadrant.md) | Document |
| [`report-computing-paper.md`](report-computing-paper.md) | Document |
| [`report-engineering.md`](report-engineering.md) | Document |
| [`report-exec-summary.md`](report-exec-summary.md) | Document |
| [`report-market-research-report.md`](report-market-research-report.md) | Full research report |
| [`report-market-sizing.md`](report-market-sizing.md) | Document |
| [`report-trend-analysis.md`](report-trend-analysis.md) | Document |
| [`report-trend-modeling.md`](report-trend-modeling.md) | Document |
| [`synthesis-okf-mif-knowledge-spine.md`](synthesis-okf-mif-knowledge-spine.md) | Document |

## Findings by Dimension

| Dimension | Findings |
| --- | --- |
| technical | 12 |
| trajectory | 9 |
| market | 8 |
| landscape | 7 |

## Tags

accuracy, actor-attribution, adjacent-markets, adoption, adoption-failure, agentic-ai, ai-agent, ai-agents, ai-demand, ai-ml-teams, architecture, attribution, bi-temporal, business-model, buyer-preference, buyer-segments, citations, commercial, comparator, comparison, competitive-positioning, complexity, confidence, confluence, context-graphs, controlled-vocabulary, counter-evidence, data-distribution, data-model, data-package, dataset-packaging, decay, demand, ecosystem, enterprise, enterprise-knowledge-graph, enterprise-licensing, entity-typing, extension-seam, fair-data, formal-typing, format-adoption, frictionless-data, gap-analysis, gartner, git-distributable, git-native, github, google-cloud, graph, graphrag, hallucination, headwind, hybrid-architecture, informal, institutional-memory, integration, interoperability, json-descriptor, json-ld, karpathy, knowledge-graph, knowledge-loss, knowledge-management, knowledge-organization, knowledge-packaging, knowledge-representation, landscape, launch, layering, lessons, linked-data, llm, llm-wiki, log-md, logseq, markdown, market, market-growth, market-risk, market-sizing, memory, memory-format, microsoft, mif, mif-advantage, minimalism, modeled-information-format, momentum, nascent, neo4j, notion, obsidian, okf, okf-nascency, okfn, ontology, open-core, open-knowledge-format, open-knowledge-foundation, open-source, owl, pain-points, pattern, personal-knowledge-management, pkm, pricing, prior-art, production, prov-o, provenance, rag, rdf, rdf-1-2, rdf-star, relationships, research, risk, roam-research, round-trip, saas, schema-enforcement, schema-org, second-brain, semantic-web, semantics, skos, sparql, specification, staleness, standards, stardog, structured-data, tabular-data, tam-sam-som, taxonomy, technical, temporal, temporal-validity, temporal-versioning, thesaurus, think-tank, trajectory, ttl, typed-relationships, untyped-links, v0-1, vector-search, w3c, w3c-prov-o, web-annotation, web-vocabulary, wiki-links, yaml-frontmatter, yaml-ld
