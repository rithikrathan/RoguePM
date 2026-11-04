# Rogue State Registry: Architecture Overview

## 1. Core Partitions
- **Local Registry (`Index 0`):** Authoritative Sled database on local hardware. Flat disk paths mapped to logical Profiles (Git/SSH identities), Intents (toolchain/env presets), and Projects (parent-child lineage).
- **Global Registry:** Stores cached project catalogs advertised by remote peer nodes.
- **GSLUT (Global State Lookup Table):** Unified, high-throughput table merging local and peer project catalogs into a single pane of glass.

## 2. Dynamic Peer Synchronization
- **Peer Reconciler Routine:** Runs on peer join, leave, and heartbeat events.
- **Manifest Exchange:** Abstracts local database into sanitized export manifests (strips private keys and disk paths).
- **GSLUT Ingestion:** Reconciles incoming peer manifests into GSLUT without stalling local operations.

## 3. UI and Execution Decoupling
- **Workbench UI:** Agnostic consumer that queries only GSLUT. Has zero disk, network, or path awareness.
- **IndexResolver Layer:** Receives selected project target from Workbench and routes execution:
  - **Local (`Index 0`):** Resolves flat disk path, loads `.rogue/` session, injects Profile Git credentials and Intent toolchains.
  - **Remote (`Index <UID>`):** Initiates P2P connection, session tunneling, or project synchronization.
