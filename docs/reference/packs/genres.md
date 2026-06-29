---
title: "Reference: genre packs"
diataxis_type: reference
---

# Genre packs

Spec-genre packs (`packs/genres/`) define the *shape* of an AI-ready, agent-executable
specification; the `ai-spec` channel renders them. Each is optional and toggle-ready
(`enabled:false`). Choose by what the deliverable defines.

| Genre | Use when the deliverable defines | Form |
| --- | --- | --- |
| `architecture-spec` | a **structure** (cross-cutting types, relationships, namespaces) | arc42/C4 §1–§12 + EARS |
| `kiro-spec` | a **single feature** with a clear task decomposition | requirements → design → tasks + EARS |
| `feature-spec` | **one capability** authored for a coding agent | Spec Kit single-feature + EARS |

All three express acceptance criteria in **EARS** (`WHEN … SHALL …` + the goal check's verify
command), and ground every design claim in a surviving finding or a named external standard. The
`architecture-spec` template is self-demonstrating: its own §1–§12 taxonomy is an architecture spec.

## Enable

```bash
bash scripts/pack-toggle.sh architecture-spec on
bash scripts/pack-toggle.sh ai-spec on
bash scripts/sync-packs.sh
```
