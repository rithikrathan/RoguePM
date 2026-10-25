# System Architecture: Distributed Workbench & Project Manager
**Execution Consumer**.
Throughout the software, these physical nodes are referenced by **indices**.
- **Index `0`** is always the local node (current machine). Any process on this
  machine that touches its own local files and directories uses index `0`.
- **Global indices** are the indices assigned to other nodes. A peer identifies
  this machine by its global index/UID; when this machine mounts from a peer it
  uses that peer's global index.
- The runtime treats everything by index - it resolves `0` to local storage and
  non-zero indices to remote peers over SSH/SSHFS/sockets.
- ***Global index != 0***

#### Data Model:
```
index (Logical identifier used by all subsystems)
├── index 0 = local node (current machine)
├── index <global> = remote node (peer identified by its global index/UID)
├──  local node will have an index file, mapping the overall structure of the index
│   which will be exchanged when a new peer connects to add to its global index
└── per index:
    ├── rp.list (to hold the orphan projects/dirs that i might need)
    ├── profile (isolated from one another)
    │   └── intent (list of projects under this intention)
    │       └── project
    │           ├── .rogue/
    │           │   ├── metadata (id,type, category, tags, status, hidden)
    │           │   ├── .rgSession (stores session snapshots and previous session to resume)
    │           │   ├── session.sh (script to start the session either using rgSession or empty)
    │           │   ├── rg.lock (concurrency guard)
    │           │   ├── source_pointer (mode: relative/absolute, path) 
    │           │   ├── sub-projects (recursive -> project) [list of projects] 
    │           │   └── parent (recursive -> project) [parent project id] 
    │           └── workspace/ 
    ├── knowledge (Machine Reference Vault)
    │   └── doc_node (specs, cheatsheets, pinouts, diagrams)
    └── workbench (Isolated Session Runner)
        ├── active_sessions/
        │   └── session (named instance: tmux + source symlink + workspace symlink/)
        └── inbound_leases/ (projects on this node borrowed by peers)
```

#### Dir Structure:
```
~/.local/share/rogue
├── local.index (index=0, global_index=<uid>, profiles, intents, project relationshipts)
├── global.index (list of index=<peer uids>, profiles, intents, project relationshipts)
├── entries/
│   ├── entries.list (project name -> projectID)
│   ├── rp.list (to hold the orphan projects/dirs that i might need)
│   └── projectID
│       ├── .rogue/
│       └── workspace/
├── knowledge (Pointer to Machine Reference Vault)
└── planner (pointer to global plans and management dir)

/mnt/sda4/projects/ will have my project repos in this machine

```

- `rogue open` will traverse the entries.index file to delegate project id to the workbench 
  for session management

---

## 1. Top-Level Entity: `node` vs `index`

A **node** is the physical machine (UUID/hostname). A **index** is what the software
uses throughout. There is no central orchestrator - every node is autonomous.

- **Local index is always `0`:** For processes running on the current machine, index
  `0` refers to this machine's local storage. Mounts, symlinks, and lookups use
  `0` for local files/directories.
- **Global indices:** Other nodes are identified by their global index/UID. When this
  node talks to peers, it uses their global indices. When peers talk to this node, they
  refer to it by its global index.
- **Dual Nature:**
  - **Storage Host:** Exposes its local filesystem projects and knowledge assets to the
    local user or authorized remote network peers.
  - **Compute Client:** Runs the `workbench` engine to check out and mount projects
    hosted locally or on remote peers.
- **Runtime ambiguity:** The workbench does not distinguish "local" vs "remote" by
  special casing - it resolves by index. Index `0` maps to local filesystem access.
  Non-zero indices are resolved by the local node via peer lookup, locking, and
  mounting (SSH/SSHFS/sockets).

---

## 2. Organization & Governance Hierarchy

### `profile`

- **Role:** High-level identity or operational boundary on a node.
- **Purpose:** Isolates projects, defaults, and configs by life context (e.g.,
  `personal`, `work`, `consulting`, `lab`).
- **Storage:** Owned directly by the host node.
- **note:** Even though its isolated in view, things are stored in plain text so it 
           is not meant for security but visiblity, and each profile will have a 
           Github profile linked so all the repos created under that profile will have 
           be created in that profile like orgs or own profile

### `intent`

- **Role:** High-level objective, track, or domain within a profile.
- **Purpose:** Replaces generic folder groupings with functional engineering domains
  (e.g., `systems`, `embedded`, `gamedev`, `client-acme`, `experiments`).
- **Function:** Organizes projects logically so high-level lifecycle queries (e.g.,
  "show all active embedded projects") can be evaluated in `O(1)` from memory.

---

## 3. Project & Workspace Subsystem

### `project`

The primary recursive unit of work representing a codebase, hardware build, or software
tool. A project can be a standalone root repository or contain nested sub-projects.

#### Core Project Attributes

- **`metadata`:**
  - `category`: Freeform grouping string (e.g., `runtime`, `compiler`, `dsp`, `tooling`).
  - `tags`: Array of strings or indexed bitflags for fast cross-cutting searches
    (e.g., `["c", "vulkan", "perf"]`).
  - `status`: Configurable lifecycle state (`ongoing`, `hiatus`, `archived`, `shipped`).
  - `hidden`: Boolean flag (`true`/`false`). When set to `true`, filters the project out
    of default tree listings, CLI views, and fuzzy pickers without deleting records.

- **`rg.lock` (Concurrency & Mutex Guard):**
  - Guarantees that only **one workbench across the entire network** can actively work on
    a project at any given moment.
  - States:
    - `UNLOCKED`: Free to mount.
    - `LOCKED`: Pinned by `session_id @ node_id` with an acquisition timestamp/lease
      heartbeat.
  - If a peer attempts to mount a locked project, the host node immediately denies the
    lease, preventing concurrent edit collisions or split-brain git trees.

- **`source_pointer` (Physical vs. Logical Decoupling):**
  - Decouples where the project sits in your logical database tree from where its bytes
    reside on disk.
  - Structure:
    - `mode`: `DIR_RELATIVE_TO_PARENT` (`0`) or `DIR_EXPLICIT_ABSOLUTE` (`1`).
    - `path`: String representing the folder location.
  - Resolution logic:
    - If `ABSOLUTE` (or root): resolves directly via path expansion (e.g.,
      `~/dev/engine`).
    - If `RELATIVE`: recursively joins the path with the resolved physical path of its
      `parent_id` project (e.g., parent `~/dev/engine` + relative `tools/shaderc` →
      `~/dev/engine/tools/shaderc`).
  - Enables zero-cost database reparenting without touching files on disk, and allows
    monorepo subdirectories and standalone external repositories to live as sibling
    sub-projects under the same logical parent.

- **`.rgSession` (Session Snapshot / Replay List):**
  - A **binary file** stored in `.rogue/` (and conceptually tied to the project). It is not a
    human-editable plaintext template in the sense described before — it acts as a snapshot
    of a workspace.
  - The `workspace/` directory is ephemeral. You can create directories, symlink resources,
    rearrange things, etc. inside it on the fly.
  - `.rgSession` stores a serialized list of sessions/snapshots that can be replayed later.
    Think of it as a record of workspace state (created dirs, linked resources, layout/state)
    that can be restored to recreate that workspace view.
  - `session.sh` is the actual session creation script. `.rgSession` is used to replay
    stored workspace snapshots; `session.sh` is what launches/creates the tmux session
    based off of that data.

- **`sub-project` (Recursive Nesting):**
  - Self-referential child project record (`parent_id == parent.id`).
  - Contains the exact same structure as a top-level project (`metadata`, `rg.lock`,
    `source_pointer`, `.rgSession`, `workspace`).

- **`workspace` (Operational Metadata & Runtime Context):**
    - contains project specific workspace setups including tools and version management with 
      existing tools  
    - project specific planning and management stuffs like issues todos, and much more 
    
- **`rp.list` 
    - used to include some additional dirs when searching for a projects, these dirs are
      not managed by rogue and its data model, instead its there to quickly open those dirs. 
    - just opens these dirs in a terminal and use its built in session.sh to session management
      and is not managed by the workbench.
    - for backward compatiblity and ease of use, same as --local flag in previous rogue

---

## 4. `knowledge` (Machine Reference Vault)

***spoilers: The OTTO project will use this for effecient reference lookups***
A dedicated, machine-level documentation and asset vault residing alongside the project
tree.

- **Purpose:** Stores static references, documentation, and hardware materials that are
  needed *during* development but should **never contaminate the project's git
  repository or `.gitignore`**.
- **Contents:**
  - PDF specification sheets (e.g., Vulkan, POSIX specs).
  - Hardware pinout diagrams, chip datasheets, and register maps.
  - Architecture notes, cheatsheets, and command snippets.
- **`doc_node`:** Discrete entry containing:
  - `id`: Unique 64-bit integer.
  - `target_path`: Real absolute path to the file or directory on the host machine.
  - `tags`: Search terms (e.g., `["esp32", "hardware", "gpio", "pinout"]`).

---

## 5. `workbench` (Isolated Session Runner)

The `workbench` is the ephemeral execution engine. It has **no permanent ownership** of
source code or documentation. Instead, it queries nodes, checks out projects, assembles
virtual workspaces using filesystem symlinks, and boots tmux environments.

### 5.1 Structure & Sub-Entities

- **`active_sessions/`:** Local runtime instances actively being worked on by the user of
  this machine.
- **`session`:** Named runtime environment (e.g., `engine-dev`, `firmware-spike`).
- **`source`:** A symlink/mount pointing directly to the project's `source/` directory:
  - If local: `source -> <resolved by index 0>/<project>/source/`
  - If remote: `source -> ~/.workbench/.mounts/<index>_<project>/source/` (via SSHFS)
- **`workspace`:** A symlink/mount pointing to the project's `workspace/` directory for
  notes/issues/planning:
  - If local: `workspace -> <resolved by index 0>/<project>/workspace/`
  - If remote: kept local to the node by default; only linked/mounted if `.rgSession`
    explicitly opts in.
- **`tmux`:** A dedicated tmux session instance (`wb_<session_name>`) running inside the
  virtual session directory, initialized with the plan's window/pane layout.
- **`inbound_leases/`:** Registry on the host node tracking projects that have been
  borrowed by peer machines.
  - When a peer computer checks out a project from this node, an inbound lease record is
    created, updating the local project's `rg.lock` to prevent the local user from
    editing it concurrently.

### 5.2 Runtime Index Ambiguity

At runtime the workbench does **not** distinguish between local and remote nodes. It
operates purely in terms of **indices**. Index `0` always means "local" from this
machine's perspective and resolves directly to its filesystem. Any other index means
"peer node with that global index" and is resolved by querying/mounting that peer.

The distinction is purely in resolution: index `0` is a direct local mapping; non-zero
indices go through the peer transport (SSH/SSHFS/sockets) with locking/leases handled
by the target node. The workbench API remains identical regardless of whether the
index is `0` or a peer's global index.

