# RoguePM Architecture Overview

Distributed project management and session orchestration across autonomous peer nodes.

---

## System Topology

```text
Workbench / CLI
       │
       ▼
GSLUT (Global State Lookup Table)
  ├── Local State (Index 0 / Sled)
  └── Peer Catalogs (Index <UID> / rogued)
       │
       ▼
IndexResolver
  ├── Local Mount: /mnt/sda4/projects/* + .rogue/session.sh
  └── Remote Mount: rogued P2P tunnel + rg.lock lease
```

---

## Core Subsystems

### 1. State Registry & GSLUT
- **Local Index (`local.index/`):** Embedded Sled KV store managing physical path mappings, Profiles, and Intents.
- **Global Catalogs (`global.index/`):** Cached project manifests published by peer nodes.
- **GSLUT (`gslut/`):** Unified query table. Workbench queries GSLUT exclusively; zero disk or network I/O during project discovery.

### 2. Rogue Core (Governance & Lineage)
- **Profiles:** Identity labels (`user.name`, `user.email`, Git forge org). OpenSSH manages keys; Core manages commit context.
- **Intents:** Domain namespaces (`systems`, `embedded`, `gamedev`) scoping toolchains and vault assets.
- **Lineage:** Parent-child dependency graphs, dynamic re-parenting, detached root promotion, and child adoption without moving disk files.
- **`source_pointer`:** Decouples logical database keys from physical disk paths.

### 3. Rogue Daemon (`rogued` - Mesh & Leases)
- **Peer Discovery:** Zero-conf mDNS (`_rogued._tcp.local.`) and gossip loops.
- **Peer Reconciler:** Background routine exchanging sanitized project catalogs and updating GSLUT on join/leave.
- **Distributed Lease Protocol (`rg.lock`):** Network mutex preventing concurrent writes across peers.
- **Transport Tunneling:** Automatic SSHFS or TCP sockets for remote project mounting.

### 4. IndexResolver (Dispatch Layer)
- Decouples UI selection from filesystem execution.
- Translates `Index 0` to local disk mount, session bootstrap (`session.sh`), and profile author environment.
- Translates `Index <UID>` to daemon lease negotiation and remote filesystem attachment.

### 5. Shell Abstraction Layer (SAL)
- Spawns `tmux` instances (Linux/macOS) or Windows Terminal panes.
- Manages symlink trees linking repository sources into ephemeral `workspace/` directories.

### 6. Knowledge Vault
- Machine-level reference storage (datasheets, pinout charts, specs) decoupled from git repositories.
- Local keyword and vector embeddings for offline retrieval.

