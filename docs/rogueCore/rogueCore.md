# Rogue Core

Rogue Core is the primary engine that manages all activities and core functionalities that happen within the local node (Index 0).

Unlike the distributed daemon (`rogued`) which handles network discovery and remote peer leases, Rogue Core runs directly on local hardware and governs local projects, identities, and disk operations.

---

## Core Responsibilities

1. **Local Node Governance:**
   - Controls project creation, organization, and lifecycle on the local machine.
   - Manages local project directories and physical disk paths.

2. **Subsystems:**
   - **Template Manager (`template_manager/`):** Manages project templates, starter files, and generator scripts.
   - **Profiles (`profile/`):** Manages Git identities (`user.name`, `user.email`, and forge accounts) across different life contexts (personal, work, lab).
   - **Intents (`intent/`):** Groups projects by domain focus (systems, embedded, web, gamedev) and scopes relevant tools and templates.
   - **Lineage (`lineage/`):** Handles parent-child subproject relationships and dynamic re-parenting without moving physical disk files.
   - **Project Management (`projectManagement/`):** Tracks project status, metadata, tags, and workspace relationships.
   - **Crawler (`crawler/`):** Scans the local filesystem to discover existing projects, detect orphans, and synchronize changes.
   - **Productivity (`productivity/`):** Manages project-level tasks, notes, snapshots, and activity logs.
