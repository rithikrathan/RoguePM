# Lineage Subsystem

The Lineage subsystem manages logical parent-child relationships between projects on the local node.

It enables subproject organization, multi-discipline architectures, and monorepo component nesting without moving physical files on disk.

---

## 1. Physical Decoupling (`source_pointer`)
Lineage relies on `source_pointer` to separate logical database hierarchy from physical disk paths:
- **`DIR_EXPLICIT_ABSOLUTE`:** Points to an independent filesystem path (e.g., `/mnt/sda4/projects/dashboard`). Allows standalone repositories located anywhere to act as subprojects under a common logical parent.
- **`DIR_RELATIVE_TO_PARENT`:** Resolves relative to the physical directory of its `parent_id` (e.g., parent `/mnt/sda4/projects/engine` + `tools/shaderc` resolves to `/mnt/sda4/projects/engine/tools/shaderc`).

---

## 2. Core Lineage Operations
- **Adopt as Subproject:** Absorbs an existing project as a child of a parent project.
- **Reparent:** Changes a child's parent reference to a new parent project without touching disk files.
- **Detach as Root:** Promotes a subproject into an independent root project by clearing its `parent_id`.
- **Ancestry Chain:** Computes the path from any subproject up to its root project.
- **Children Limit (Configurable):** Defaults to 10 direct children per project. This limit can be overridden per project in project configuration. Grandchildren do not count toward the direct parent's limit.
- **Cycle Detection & Prevention:** 
  - Before reparenting or adopting, Rogue Core checks the ancestry chain.
  - If a loop is detected (e.g. attempting to make a project a child of its own subproject), the operation is strictly blocked and an error warning is displayed. Circular ancestry is forbidden.

---

## 3. Parent Deletion & Cascade Rules
When a parent project is removed or deleted:
1. **Absolute Standalone Children:** Children with `DIR_EXPLICIT_ABSOLUTE` pointers are automatically detached and promoted to standalone root projects (`parent_id: None`). No standalone repository files are ever lost.
2. **Relative Subdirectory Children:** Children with `DIR_RELATIVE_TO_PARENT` pointers reside inside the parent's directory on disk; their database records are pruned along with the parent.
3. **Safety Warning:** The CLI warns when deleting a parent with active children:
   `Parent has active subprojects. Promote children to root projects or delete? [promote/delete/abort]`

---

## 4. Intent Locking & Cross-Intent Sharing
- **Intent Locking:** Every project is strictly locked to its native Intent domain. Projects cannot be moved or transferred between Intents.
- **Sharing Across Intents via Child Projects:** The only way to extend or share a project across different engineering disciplines is to create or adopt a child project under that other Intent.
- **Isolation Guarantee:** This ensures multi-discipline architectures (e.g. an `embedded` device communicating with a `web` dashboard) are linked logically in the database while keeping domain toolchains, templates, and environment variables completely isolated and unpolluted.

---

## 5. Session Isolation
- **One Project per Session:** Opening a parent project launches a session exclusively for that project.
- **No Workspace Bleed:** Opening a parent does not automatically mount, symlink, or spawn workspaces for child projects. Each project manages its own independent runtime session.
