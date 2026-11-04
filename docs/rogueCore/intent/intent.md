# Intent Subsystem Specification

## 1. Core Purpose & Domain Boundary
An **Intent** is an engineering domain boundary within a Profile. It groups related codebases under a unified technical discipline (e.g., `embedded`, `systems`, `web`, `research`).
- **Domain Scope:** Governs toolchain defaults and domain-specific environment variables without depending on specific UI or workbench implementations.
- **Strict Domain Membership:** Every project belongs natively to an Intent, maintaining a clean boundary around its technical domain.

---

## 2. Template Architecture & Scoping
Intents partition project scaffolding templates to keep new project generation focused and relevant:
- **Global Templates:** Universal baselines (e.g., `empty`, `basic-git`, `minimal-docs`) accessible from any Intent across the system.
- **Intent-Scoped Templates:** Domain-specialized scaffolds registered directly to an Intent (e.g., bare-metal ARM or KiCad boards under `embedded`; React or Astro under `web`; Vulkan or kernel modules under `systems`).
- **Global Override Flag (`--all` / `--global`):** When scaffolding via `rogue new`, the CLI defaults to showing that Intent's scoped templates. Passing `--all` bypasses the domain filter, exposing the full global template registry.

---

## 3. Knowledge Vault & Search Boundary
Intents serve as the primary routing and partitioning scope for local and peer-distributed documentation:
- **Lexical & Vector Search Partitioning:** Scopes queries to relevant documentation, preventing cross-domain noise (e.g., searches in `embedded` target microchip datasheets, pinout charts, and register maps, ignoring web framework guides).
- **Local & Mesh RAG Scoping:** When querying reference materials across the peer mesh, the Intent acts as a filter boundary, retrieving only the documents published under matching domains.

---

## 4. Multi-Domain Architecture via Child Projects
Complex systems spanning multiple disciplines avoid environment and toolchain pollution through **Cross-Intent Child Projects**:
- A primary project (e.g., `smart-sensor` under `embedded`) links to a child project (e.g., `dashboard` under `web`).
- Each repository maintains its own unpolluted domain context, toolchains, and environment.
- The parent-child lineage in the local database (`relations` tree) preserves the logical connection between the components.

---

## 5. Intent Operations
1. **Create Intent:** Registers a domain slug under a Profile (`intent:<profile_id>:<intent_id>`).
2. **Migrate Intent:** Moves an intent and its projects from Profile A to Profile B via atomic batch write.
3. **Delete Intent:** Blocked if active projects remain, preventing orphaned database records.
