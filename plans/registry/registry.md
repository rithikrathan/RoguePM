# Rogue State Registry Implementation Plan

## 1. Overview & Storage Engine
- **Engine:** Sled KV database.
- **Locations:**
  - `~/.local/share/rogue/local.index/` (Index 0 authoritative local storage).
  - `~/.local/share/rogue/global.index/` (Cached peer manifests).
  - `~/.local/share/rogue/gslut/` (Global State Lookup Table).
- **Core Decoupling:**
  - Local database holds private machine state.
  - GSLUT merges local and peer indices for Workbench queries.
  - Workbench queries GSLUT only; never scans disks or networks directly.

---

## 2. Layered Architecture

```text
Layer 4: Workbench UI / CLI (Queries GSLUT exclusively)
   │
Layer 3.5: GSLUT (Unified local + peer index)
   ▲                                   ▲
   │ (Local writes)                    │ (Peer manifests via rogued)
Layer 3: Local Registry Engine         Peer Reconciler Routine
   │                                   │
Layer 2: Database Abstraction (DAL)    Network Transport & Validation
   │                                   │
Layer 1: local.index (Sled)            global.index (Cached Catalogs)
```

---

## 3. Database Schema

### Tree 1: `projects`
- `p:<profile_id>:<intent_id>:<project_id>` $\rightarrow$ `ProjectRecord` (bincode)
- `lookup:name:<project_name>` $\rightarrow$ `project_id`
- `lookup:path:<hash(physical_path)>` $\rightarrow$ `project_id`

### Tree 2: `relations`
- `parent:<parent_project_id>` $\rightarrow$ `Vec<project_id>`
- `child:<child_project_id>` $\rightarrow$ `Option<parent_project_id>`

### Tree 3: `governance`
- `profile:<profile_id>` $\rightarrow$ `ProfileConfig` (Git author credentials, default org)
- `intent:<profile_id>:<intent_id>` $\rightarrow$ `IntentMetadata` (toolchains, env vars)

### Tree 4: `gslut`
- `<index_id>:<profile_id>:<intent_id>:<project_id>` $\rightarrow$ `GlobalProjectLookupEntry`
- `gslut:by_name:<name>` $\rightarrow$ `Vec<GlobalProjectPointer>`
- `gslut:peers:<index_id>` $\rightarrow$ `PeerNodeSummary`

---

## 4. Core Trait Specifications

### A. `HierarchyManager`
```rust
pub trait HierarchyManager {
    fn create_profile(&self, profile_id: &str, author: ProfileConfig) -> Result<()>;
    fn create_intent(&self, profile_id: &str, intent_id: &str, meta: IntentMetadata) -> Result<()>;
    fn list_profiles(&self) -> Result<Vec<String>>;
    fn list_intents(&self, profile_id: &str) -> Result<Vec<String>>;
    fn share_project_across_intents(&self, id: ProjectId, target_intent: &str) -> Result<()>;
    fn unshare_project(&self, id: ProjectId, target_intent: &str) -> Result<()>;
    fn migrate_intent(&self, intent_id: &str, from_profile: &str, to_profile: &str) -> Result<()>;
}
```

### B. `LineageController`
```rust
pub trait LineageController {
    fn reparent(&self, child: ProjectId, new_parent: Option<ProjectId>) -> Result<()>;
    fn detach_as_root(&self, child: ProjectId) -> Result<()>;
    fn adopt_as_subproject(&self, parent: ProjectId, target: ProjectId) -> Result<()>;
    fn get_ancestry_chain(&self, id: ProjectId) -> Result<Vec<ProjectId>>;
    fn get_dependency_graph(&self, id: ProjectId, depth: Option<usize>) -> Result<ProjectTree>;
}
```

### C. `WorkbenchAssembler` & `IndexResolver`
```rust
pub trait WorkbenchAssembler {
    fn resolve_target(&self, name_or_id: &str) -> Result<GlobalProjectPointer>;
    fn query_workbench_projects(&self, filter: GlobalQueryFilter) -> Result<Vec<GlobalProjectSummary>>;
    fn assemble_context(&self, target: &GlobalProjectPointer) -> Result<WorkbenchBundle>;
}
```

### D. `GlobalLookupCoordinator`
```rust
pub trait GlobalLookupCoordinator {
    fn ingest_peer_index(&self, peer_node_id: &str, catalog: PeerPublishedCatalog) -> Result<()>;
    fn handle_peer_leave(&self, peer_node_id: &str) -> Result<()>;
    fn sync_local_index(&self) -> Result<()>;
    fn list_peer_nodes(&self) -> Result<Vec<PeerNodeSummary>>;
}
```
