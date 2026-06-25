---
diataxis_type: reference
---

# Ontology packs

Ontology packs extend the MIF entity vocabulary for a specific domain. Each pack
supplies a `*.ontology.yaml` that declares namespaces, entity types, relationships,
and discovery patterns. Binding an ontology pack lets the research engine recognize,
classify, and relate domain entities found in sources.

Ontology packs have no external dependencies and no SKILL.md — they are data packs,
not skill packs.

The vocabulary is layered in three tiers: the domain-neutral **generic core**
(`mif-base` / `mif-generic` / `shared-traits`, the MIF-compliant always-on layer) →
[`engineering-base`](#engineering-base) (shared engineering supertypes — MIF-compliant,
opt-in via `extends`, never bound directly) → the bindable **domain packs** below.

For control-plane mechanics see [Packs and Plugins](../packs-and-plugins.md).

## Enabling and binding an ontology

Ontology packs use a **different control surface** from the skill/channel/genre
plugin packs. They are declared in `harness.config.json` `ontologies[]` (an `id`
plus an `enabled` flag), not in `packs[]`, so `scripts/pack-toggle.sh` does not
apply to them. Enabling an ontology is two steps:

1. Set its `enabled` flag to `true` in `ontologies[]` (the per-pack "Enable"
   command below does exactly this for that pack's `id`).
2. Bind the enabled ontology to a research topic with the `/ontology-review`
   command, whose deterministic engine is `scripts/ontology-review.sh`. Binding
   is what lets findings in that topic resolve to the ontology's entity types;
   per-finding classification is handled by `scripts/resolve-ontology.sh`.

`resolve-ontology.sh` requires `yq`, `jq`, and `ajv` (see
[dependencies](../dependencies.md)).

---

## biology-research-lab

**Version:** 0.1.0 | **Kind:** ontology

### Purpose

Provides an entity vocabulary covering the full lifecycle of an academic biology
research lab: personnel, grants, experiments, samples, data, publications, and
compliance (IRB / IACUC / IBC). Sources include NIH, NSF, OHRP, OLAW, FAIR Data
Principles, and the CRediT Contributor Roles Taxonomy.

### Domain

Academic biology research labs and their operational, funding, and compliance contexts.

### Entities, relationships, and traits

**Entity types:** principal-investigator, lab-member (postdoc / graduate-student /
technician / lab-manager / other), collaborator, grant, grant-submission, grant-report,
project, protocol (cell-culture / molecular-biology / imaging / animal / computational /
other), experiment, sample (cell-line / tissue / dna / rna / protein / plasmid /
organism / other), reagent, equipment (microscope / centrifuge / sequencer /
flow-cytometer / other), dataset, publication, manuscript-submission, irb-protocol,
iacuc-protocol, ibc-protocol, training-record.

**Key relationships:** `leads`, `funded_by`, `uses_protocol`, `produces`, `covered_by`,
`collaborates_with`, `cites_grant`, `uses_sample`, `uses_equipment`.

**Traits applied:** `lifecycle`, `contactable`, `certified`, `renewable`, `auditable`,
`inventoried`, `maintainable`, `versioned`, `owned`, `reviewed`, `scheduled`,
`measured`, `budgeted`.

**Discovery patterns:** recognizes NIH grant mechanism codes (R01, R21, K99, F31,
T32, U01), ORCID identifiers, experimental keywords (PCR, qPCR, Western, assay),
compliance keywords (IRB, IACUC, IBC, BSL), and publication identifiers (DOI, PMID).

### When to bind

Bind `biology-research-lab` when researching academic research lab operations, life
sciences grant landscapes, laboratory compliance requirements, or research data
management.

### Enable

```sh
jq '(.ontologies[] | select(.id=="biology-research-lab") | .enabled) |= true' \
  harness.config.json > harness.config.tmp && mv harness.config.tmp harness.config.json
```

---

## data-engineering

**Version:** 0.2.0 | **Kind:** ontology

### Purpose

Provides an entity vocabulary for the data engineering domain: data contracts, data
products, governance policies, data quality, storage architectures, and pipeline
patterns. It `extends` [`engineering-base`](#engineering-base), inheriting the shared
engineering supertypes and keeping only its data-specific types.

### Domain

Data engineering teams, data platform engineering, and modern data infrastructure.

### Entities, relationships, and traits

**Namespaces (semantic):** contracts (data contracts and product interface agreements),
governance (policies, controls, stewardship), storage (storage and scaling
architectures). **Namespaces (procedural):** pipelines (pipeline and data-movement
patterns).

**Entity types:** data-contract (enforceable schema + semantics + SLA agreements between
producers and consumers), data-product, data-governance-policy, data-quality-rule,
storage-architecture, pipeline-pattern, data-platform.

**Traits applied:** `cited`.

**Discovery patterns:** recognizes data contract mentions, governance terminology,
pipeline and storage architecture patterns.

### When to bind

Bind `data-engineering` when researching data platform architecture, data contract
adoption, data governance frameworks, or modern data engineering tooling and practices.

### Enable

```sh
jq '(.ontologies[] | select(.id=="data-engineering") | .enabled) |= true' \
  harness.config.json > harness.config.tmp && mv harness.config.tmp harness.config.json
```

---

## engineering-base

**Version:** 0.1.0 | **Kind:** ontology (shared layer — not directly bindable)

### Purpose

A MIF-compliant **intermediate layer** between the domain-neutral generic core
(`mif-base` / `mif-generic` / `shared-traits`) and the engineering DOMAIN packs. It
declares the supertypes that recur across every engineering domain so the domains
inherit them instead of each re-declaring its own copy. It is a layer, not a bindable
domain pack: topics do not bind `engineering-base` directly — they bind a descendant
(`software-engineering`, `data-engineering`, `software-security`), whose `extends` chain
reaches here.

### Domain

Shared engineering vocabulary — architecture, components, patterns, decisions, delivery
metrics, practices, and disciplines.

### Entities, relationships, and traits

**Entity types:** component, architectural-decision, design-pattern, delivery-metric,
engineering-practice, process-discipline, plus the cross-cutting universals control,
artifact, policy, provenance (recurring across security, data, and software — domain
packs specialize them via `subtype_of`, e.g. software-security
`security-control` is `subtype_of: [control]` — a subtype is substitutable for its
supertype at a relationship endpoint, enforced by the concordance validator and
`gate_m22`).

**Relationships:** `depends_on`, `implements`, `governs` (control/policy →
component/artifact), `attests` (provenance → artifact), `derived_from` (artifact lineage).

**Traits applied:** `versioned`, `documented`, `dated`, `cited`.

**Discovery patterns:** recognizes named design / architectural patterns (Factory,
Singleton, Observer, Repository, Strategy, Decorator, CQRS, Event Sourcing, Saga).

### Resolution

`engineering-base` is cataloged present-but-NOT-core (`core=false`): it is never
always-on and never auto-applied to a non-engineering topic (biology, agriculture,
legal never resolve these types). Resolution is **transitive** — binding a descendant
pack resolves the supertypes this layer declares, because `resolve-ontology.sh` walks
the `extends` chain. There is no Enable command and no "When to bind" step for this
layer; enable and bind one of its descendant domain packs instead.

---

## market-research

**Version:** 0.1.0 | **Kind:** ontology

### Purpose

Provides an entity vocabulary for market and competitive research: market segments,
competitors and brands, buyer personas, market sizing (TAM/SAM/SOM), competitive forces,
service offerings and demand, value propositions, market-intelligence reports, data
sources, survey instruments, and win-loss analyses. Sources include schema.org /
GoodRelations, Umbrex market-mapping, HubSpot TAM/SAM/SOM, Porter Five Forces, and the
Strategyzer Value Proposition Canvas.

### Domain

Market analysis, competitive intelligence, and customer/segment research.

### Entities, relationships, and traits

**Entity types:** segment, competitor, brand, buyer-persona, respondent-segment,
sizing-estimate, competitive-force, service-offering, market-demand, value-proposition,
market-intelligence-report, market-data-source, survey-instrument, win-loss-analysis.

**Key relationships:** `analyzes-competitor`, `based-on-source`, `covers-segment`,
`item-offered`, `maintains-brand`, `operates-in`, `provides-service`, `targets-audience`,
`tracks-competitive-force`.

**Traits applied:** `auditable`, `bounded`, `categorized`, `contactable`, `located`,
`measured`, `owned`, `reviewed`, `scheduled`, `scored`, `seasonal`, `tagged`, `versioned`.

**Discovery patterns:** recognizes segment/vertical, competitor, buyer-persona/ICP,
TAM/SAM/SOM sizing, Porter five-forces, survey/conjoint/NPS, win-loss, and data-source
terminology.

### When to bind

Bind `market-research` when researching market landscapes, competitive intelligence,
customer segmentation, market sizing, or buyer / voice-of-customer analysis.

### Enable

```sh
jq '(.ontologies[] | select(.id=="market-research") | .enabled) |= true' \
  harness.config.json > harness.config.tmp && mv harness.config.tmp harness.config.json
```

---

## regenerative-agriculture

**Version:** 0.1.0 | **Kind:** ontology

### Purpose

Provides an entity vocabulary for regenerative farm business operations: land, livestock,
supply chain, carbon markets, and certification bodies. Sources include the Rodale
Institute ROC Standards, Soil & Climate Initiative Verification Framework v3.0 (2025),
USDA NRCS Soil Health Principles, Rainforest Alliance Regenerative Agriculture Standard
(2025), and FAO Agroecology Knowledge Hub.

### Domain

Regenerative farm business operations — farm records, supply chain, carbon credit
activities, and certification tracking (not research observations).

### Entities, relationships, and traits

**Namespaces (semantic):** land (land parcels, fields, soil profiles), livestock
(animals, herds, breeding records). Additional namespaces cover supply chain, carbon
markets, certifications, and farm financials.

**Traits applied:** `lifecycle`, `owned`, `renewable`, `auditable`, `inventoried`.

**Discovery patterns:** recognizes farm operation terminology, soil health references,
certification body names (ROC, Rainforest Alliance), carbon market identifiers.

### When to bind

Bind `regenerative-agriculture` when researching farm business operations, regenerative
agriculture supply chains, carbon credit markets, or agricultural certification programs.
For research-oriented findings about farming practices rather than farm records, use
`regenerative-agriculture-research` instead.

### Enable

```sh
jq '(.ontologies[] | select(.id=="regenerative-agriculture") | .enabled) |= true' \
  harness.config.json > harness.config.tmp && mv harness.config.tmp harness.config.json
```

---

## regenerative-agriculture-research

**Version:** 0.1.0 | **Kind:** ontology

### Purpose

Provides a research-oriented entity vocabulary for regenerative agriculture findings.
Covers research observations about farming practices, infrastructure, funding, and
technology — not farm records. Includes cross-cutting technology and security research
types so infrastructure- and security-flavored farm topics resolve correctly.

### Domain

Research findings about regenerative agriculture practices: husbandry, agronomy, farm
infrastructure, funding programs, and farm technology.

### Entities, relationships, and traits

**Namespaces (semantic):** husbandry (animal husbandry and livestock care knowledge),
agronomy (grazing, soil, crop, and pasture practices), infrastructure (fencing,
irrigation, IoT, networks), funding (grants, cost-share, and funding programs).

**Entity types include:** husbandry-practice (animal-husbandry or livestock-care
research observations such as lambing, newborn care, health management).

**Traits applied:** `cited`.

**Discovery patterns:** recognizes husbandry and agronomy terminology, farm
infrastructure keywords, grant and funding program identifiers, IoT and technology
references in a farm context.

### When to bind

Bind `regenerative-agriculture-research` when researching regenerative farming
practices, husbandry techniques, soil science, agronomy research, or agricultural
grant programs. For farm business records and supply chain tracking, use
`regenerative-agriculture` instead.

### Enable

```sh
jq '(.ontologies[] | select(.id=="regenerative-agriculture-research") | .enabled) |= true' \
  harness.config.json > harness.config.tmp && mv harness.config.tmp harness.config.json
```

---

## regulatory-legal

**Version:** 0.1.0 | **Kind:** ontology

### Purpose

Provides an entity vocabulary for regulatory and legal research: legislative acts and
treaties, obligations and rights, jurisdictions and authorities, contracts, licenses,
court decisions, regulatory sanctions, compliance reporting, and control mappings.
Grounded in LKIF-Core, FIBO (FBC / FND), ELI v1.5, Akoma Ntoso, and NIST OSCAL.

### Domain

Law, regulation, compliance, and governance contexts.

### Entities, relationships, and traits

**Entity types:** legal-act, treaty, obligation, legal-right, legal-capacity,
jurisdiction, authority, legal-person, legal-role, contract, license-permit,
control-mapping, court-decision, regulatory-sanction, legal-procedure, assessment,
compliance-report.

**Key relationships:** `amends`, `applies_in`, `cites`, `confers`, `governed_by`,
`has_jurisdiction_in`, `imposes`, `regulates`, `satisfies`, `transposes`.

**Traits applied:** `auditable`, `bounded`, `categorized`, `contactable`, `lifecycle`,
`located`, `owned`, `regulated`, `renewable`, `reviewed`, `scheduled`, `scored`, `tagged`.

**Discovery patterns:** recognizes regulation citations (Regulation (EU), U.S.C., GDPR,
HIPAA), deontic language (shall / must / prohibited), jurisdictions, regulators, control
crosswalks (OLIR), ELI / Akoma Ntoso URIs, case citations (ECLI), and contract / legal-role
terminology. `control-mapping.control_ref` bridges to the software-security pack's `security-control` type.

### When to bind

Bind `regulatory-legal` when researching laws and regulations, compliance obligations,
legal instruments and case law, or control-to-obligation mappings.

### Enable

```sh
jq '(.ontologies[] | select(.id=="regulatory-legal") | .enabled) |= true' \
  harness.config.json > harness.config.tmp && mv harness.config.tmp harness.config.json
```

---

## scientific

**Version:** 0.1.0 | **Kind:** ontology

### Purpose

Provides an entity vocabulary for scientific research: studies and investigations,
methods and protocol applications, samples and measurements, hypotheses, instruments,
publications and funding, and datasets with their catalogs, distributions, services, and
provenance. Grounded in OBO Foundry / OBI, IAO, COB, W3C DCAT 3, W3C PROV-O, and
schema.org (OBO IRIs are OLS4/Ontobee-confirmed).

### Domain

Scientific studies, research data management, and data provenance.

### Entities, relationships, and traits

**Entity types:** study, research-investigation, cohort, method, protocol-application,
sample-organism, measurement, hypothesis, research-instrument, research-publication,
research-funding, dataset, data-distribution, data-service, dataset-series, data-catalog,
data-provenance.

**Key relationships:** `applies`, `catalogs`, `enrolls`, `funded_by`, `has_sample`,
`measured_on`, `produces`, `reports_in`, `tests`, `uses_instrument`, `uses_method`.

**Traits applied:** `auditable`, `bounded`, `budgeted`, `categorized`, `inventoried`,
`lifecycle`, `located`, `maintainable`, `measured`, `owned`, `quality_controlled`,
`renewable`, `reviewed`, `scheduled`, `tagged`.

**Discovery patterns:** recognizes study / trial / cohort, assay / protocol / method,
sample / organism / tissue, measurement, hypothesis, instrument, DOI / preprint, grant,
DCAT dataset, and PROV-O provenance terminology.

### When to bind

Bind `scientific` when researching scientific studies, experimental methods, research
data and catalogs, or data provenance and lineage.

### Enable

```sh
jq '(.ontologies[] | select(.id=="scientific") | .enabled) |= true' \
  harness.config.json > harness.config.tmp && mv harness.config.tmp harness.config.json
```

---

## software-engineering

**Version:** 0.5.0 | **Kind:** ontology

### Purpose

Provides an entity vocabulary for the SDLC-operational slice of software engineering:
production incidents and operational procedures. It `extends`
[`engineering-base`](#engineering-base), from which it inherits the shared engineering
supertypes (component, architectural-decision, design-pattern, delivery-metric,
engineering-practice, process-discipline); the generic `technology` comes from
`mif-generic`. Security types (`security-threat`, `security-framework`,
`security-incident`) live in the [`software-security`](#software-security) pack, and
regulation is modeled in [`regulatory-legal`](#regulatory-legal) (subsumed by its
`legal-act` / `obligation`). The former `adoption-trend` is gone — the
[`trend-analysis`](#trend-analysis) pack's `trend` is canonical.

### Domain

Software development teams, software architecture research, and engineering process
analysis.

### Entities, relationships, and traits

**Namespaces (procedural):** deployments (deployment procedures, release processes).

**Entity types:** incident-report, runbook, deployment-procedure, migration-guide (the
shared supertypes are inherited from `engineering-base`, not re-declared here).

**Traits applied:** `versioned`, `dated`, `timeline`, `stakeholders`.

**Discovery patterns:** recognizes incident / outage / postmortem / RCA, runbook /
playbook / SOP, deployment / release, and migration / upgrade terminology in research
sources.

### When to bind

Bind `software-engineering` when researching production incidents and postmortems,
operational runbooks, deployment and release procedures, or system migration plans. For
the shared engineering supertypes (components, architecture, decisions, patterns), bind
this or any sibling engineering pack — they are inherited from `engineering-base`.

### Enable

```sh
jq '(.ontologies[] | select(.id=="software-engineering") | .enabled) |= true' \
  harness.config.json > harness.config.tmp && mv harness.config.tmp harness.config.json
```

---

## software-security

**Version:** 0.2.0 | **Kind:** ontology

### Purpose

Provides an entity vocabulary for the software-facing slice of security research:
vulnerabilities and weaknesses, controls, threat actors, campaigns and tactics,
indicators of compromise, malware, tools and infrastructure, threat-intelligence
reports, supply-chain risk, policies, assessments, and POA&Ms. It `extends`
[`engineering-base`](#engineering-base). Grounded in MITRE ATT&CK / CAPEC, CVE / CWE /
NVD, NIST SP 800-53 / OSCAL / 800-161r1, STIX 2.1, OWASP, and VERIS. The
`security-threat`, `security-framework`, and `security-incident` types live **here**, as
SDLC-facing supertypes that the finer STIX / ATT&CK / CWE types (attack-tactic, weakness,
vulnerability) refine.

### Domain

Cybersecurity threat intelligence, vulnerability management, and security compliance.

### Entities, relationships, and traits

**Entity types:** attack-tactic, attack-mitigation, malware, vulnerability, weakness,
security-control, threat-actor, attack-campaign, indicator-of-compromise, security-infrastructure,
security-tool, threat-intelligence-report, supply-chain-risk, security-policy,
security-assessment, poam, security-threat, security-framework, security-incident.

**Key relationships:** `attributed_to`, `categorizes`, `defines`, `documents`, `exploits`,
`hosts`, `indicates`, `mitigates`, `mitigates_threat`, `realizes`, `tracks`, `uses`.

**Traits applied:** `auditable`, `categorized`, `certified`, `inventoried`, `located`,
`measured`, `owned`, `quality_controlled`, `regulated`, `reviewed`, `scheduled`, `scored`,
`tagged`, `versioned`.

**Discovery patterns:** recognizes ATT&CK technique / CAPEC IDs, CVE / CWE ids, NIST
control ids, framework names, breach / ransomware terms, threat-actor and campaign names,
IOC / YARA / STIX / TLP markers, supply-chain / SBOM, pen-test / red-team, and malware
family names.

### When to bind

Bind `software-security` when researching threat intelligence, vulnerability and weakness
analysis, security controls and frameworks, or security compliance and assessment.

### Enable

```sh
jq '(.ontologies[] | select(.id=="software-security") | .enabled) |= true' \
  harness.config.json > harness.config.tmp && mv harness.config.tmp harness.config.json
```

---

## trend-analysis

**Version:** 0.1.0 | **Kind:** ontology

### Purpose

Provides an entity vocabulary for strategic foresight and trend analysis: weak signals,
drivers, trends and megatrends, emerging issues, wild cards, critical uncertainties,
adoption curves, forecasts, scenarios, horizons, implications, visions, and roadmaps.
Grounded in IFTF foresight, EU JRC / K4P, Sitra, Shell / GBN scenario planning, Rogers
Diffusion of Innovations, Gartner Hype Cycle, Three Horizons, the Futures Wheel, and
OECD-OPSI. (Six types the inventory based on `analytical` are remapped to the `semantic`
root, since the mif-base cognitive triad has no `_analytical` root.) This pack's `trend`
is canonical, replacing the former `adoption-trend` (which has been removed).

### Domain

Strategic foresight, futures studies, and technology / market trend analysis.

### Entities, relationships, and traits

**Entity types:** signal, driver, trend, megatrend, emerging-issue, wild-card,
critical-uncertainty, adoption-curve, forecast, scenario, horizon, implication, vision,
roadmap.

**Key relationships:** `constrains`, `generates`, `grounds`, `indicates`, `informs`,
`intensifies`, `matures_into`, `operationalizes`, `placed_on`, `produces`, `specializes`.

**Traits applied:** `auditable`, `bounded`, `categorized`, `measured`, `owned`,
`reviewed`, `scheduled`, `scored`, `tagged`, `versioned`.

**Discovery patterns:** recognizes weak-signal, driver-of-change / STEEP, trend, hype-cycle
/ S-curve, forecast, megatrend, scenario, and wild-card / black-swan terminology.

### When to bind

Bind `trend-analysis` when researching strategic foresight, emerging signals and
megatrends, technology adoption and hype cycles, or scenario and roadmap planning.

### Enable

```sh
jq '(.ontologies[] | select(.id=="trend-analysis") | .enabled) |= true' \
  harness.config.json > harness.config.tmp && mv harness.config.tmp harness.config.json
```
