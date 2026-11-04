# State Registry: Logical Hierarchy & Design Specifications

## 1. Architectural Role
- **Path & Assembly Locator:** Resolves flat disk locations and runtime contexts for workbench mounting. Does not index code or full text.
- **Physical Decoupling:** Repositories reside flat on disk (`/mnt/sda4/projects/*`). Profiles and Intents exist strictly as metadata partitions in Sled.

---

## 2. Logical Hierarchy

```text
Index (0 = Local Node, <UID> = Remote Peer Node)
└── Profiles (Identity Boundaries)
    └── Intents (Functional Domains)
        └── Projects (Work Units)
```

### Profiles
- Lightweight identity boundary.
- Stores Git author (`user.name`, `user.email`) and target forge organization.
- OpenSSH and SSH agents manage keys and permissions directly; Rogue does not track private key files.

### Intents
- Functional domain boundary (`embedded`, `systems`, `gamedev`).
- Sets toolchain presets, domain-scoped environment variables, and knowledge vault tags.
- Stored as discrete keys (`intent:<profile>:<intent>`) to eliminate write amplification.

### Projects & Lineage
- **Lineage:** Parent ID (`parent_id`) and recursive children list (`sub_projects`).
- **Dynamic Re-parenting:** Move child project to a new parent by updating Sled keys without touching files on disk.
- **Root Promotion:** Detach a sub-project into a standalone top-level project (`detach_as_root`).
- **Child Adoption:** Absorb an existing standalone repo under a parent project (`adopt_as_subproject`).
- **Cross-Intent Sharing:** Secondary logical index pointers allow one repository to exist across multiple intents without file duplication.

---

## 3. Storage Hierarchy (`~/.local/share/rogue/`)
- `local.index/`: Local Sled database (authoritative Index 0 state).
- `global.index/`: Cached peer catalogs.
- `gslut/`: Unified lookup table across all nodes.
- `entries/`: Project scratchpads, metadata, and locks.
- `entries/rp.list`: Unmanaged or orphan directory paths.
