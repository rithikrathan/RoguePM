# Sled Central State Database Schemas

## 1. Tree: `projects`
Stores project records, paths, and point-lookup indexes.

### Primary Record
- **Key:** `p:<profile_id>:<intent_id>:<project_id>`
- **Value:** `ProjectRecord` (serialized binary)
  - `id`: Unique project UUID or slug.
  - `name`: Human-readable project name.
  - `profile_id`: Associated profile identifier.
  - `primary_intent`: Associated intent domain.
  - `source_pointer`: Absolute path on the local filesystem.
  - `created_at`: Unix epoch timestamp.
  - `updated_at`: Unix epoch timestamp.

### Inverted Indexes
- **Name Lookup:** `lookup:name:<name>` $\rightarrow$ `project_id`
- **Path Lookup:** `lookup:path:<hash(path)>` $\rightarrow$ `project_id`

---

## 2. Tree: `relations`
Tracks project lineage and parent-child dependency graphs.

- **Children List:** `parent:<parent_id>` $\rightarrow$ `Vec<project_id>`
- **Parent Pointer:** `child:<child_id>` $\rightarrow$ `Option<parent_id>`

---

## 3. Tree: `governance`
Stores identity boundaries and domain scopes.

### Profiles
- **Key:** `profile:<profile_id>`
- **Value:** `ProfileConfig`
  - `profile_id`: Unique slug (`personal`, `work`).
  - `display_name`: Label.
  - `git_user_name`: Author name for Git commits.
  - `git_user_email`: Author email for Git commits.
  - `default_org`: Default Git forge organization.
  - `env_overrides`: Key-value environment variables.

### Intents
- **Key:** `intent:<profile_id>:<intent_id>`
- **Value:** `IntentMetadata`
  - `intent_id`: Domain slug (`embedded`, `systems`, `web`).
  - `description`: Domain summary.
  - `env_vars`: Domain-specific environment presets.
  - `knowledge_tags`: Target tags for documentation queries.

---

## 4. Tree: `templates`
Tracks registered templates and their associations.

- **Key:** `tmpl:<template_id>`
- **Value:** `TemplateRecord`
  - `id`: Template slug matching disk directory name.
  - `path`: Absolute filesystem path to template folder.
  - `setup_script`: Script filename (e.g., `c.sh`).
  - `intents`: Optional list of associated intent IDs (`Vec<String>`). Empty means universal/global.

---

## 5. Tree: `gslut` (Global State Lookup Table)
Aggregated cross-node state queried by the Workbench.

- **Cross-Node Record:** `<index_id>:<profile_id>:<intent_id>:<project_id>` $\rightarrow$ `GlobalProjectLookupEntry`
  - Index `0` for local node, `<peer_uid>` for remote peers.
- **Global Name Index:** `gslut:by_name:<name>` $\rightarrow$ `Vec<GlobalProjectPointer>`
- **Peer Rosters:** `gslut:peers:<index_id>` $\rightarrow$ `PeerNodeSummary`
