# RoguePM Features

Feature index across all branches (`main`, `experimental`, `trash`, `Development`, and roadmap plans).

---

## 1. Implemented Features (`main`)

### Project Lifecycle
- **`rogue new`**: Scaffold projects with templates, git init, GitHub/GitLab remote, and tmux session scripts.
- **`rogue open`**: Fuzzy picker (fzf/bemenu) to quickly launch project tmux sessions.
- **`rogue list`**: Formatted table of projects (branch, clean/dirty state, last commit, remote).
- **`rogue archive / unarchive`**: Shelve inactive projects using rsync without deletion.
- **`rogue snapshot`**: One-command commit & push across all dirty projects in workspaces.

### Workspaces & Templates
- **Workspaces (`rogue ws`)**: Multi-directory workspace groups with GitHub Org integration and hide flags.
- **Templates (`rogue template`)**: 16+ language/tool scaffolds (C, Rust, Go, Python, React, Godot, KiCad, Verilog, etc.).
- **Standalone list (`rp.list`)**: Quick access to external/orphan directories outside workspaces.

### Management & Auth
- **`rogue addRemote` / `setPat`**: Manage remote repositories and Personal Access Tokens.
- **`rogue update`**: Self-update CLI directly from the git repo.
- **Session generator**: Dynamic tmux session launcher with customized windows, panes, and tools.

---

## 2. Native C Acceleration (`experimental`)

- **`rogue-core`**: Native C engine replacing slow shell loops.
- **Parallel git scanner**: Multi-threaded repo status checks using `libgit2` and `pthreads`.
- **Fast fuzzy matcher**: Instant candidate filtering for CLI queries.
- **Table renderer**: ANSI-styled, column-aligned terminal table generator.

---

## 3. P2P LAN Daemon (`trash` / `rogued`)

- **Discovery**: Zero-conf LAN discovery via mDNS (`_rogued._tcp.local.`).
- **Control socket**: UNIX domain socket (`/tmp/rogued.sock`) with JSON API.
- **Peer management**: Subcommands to `discover`, `ping`, `pair`, `accept`, `reject`, `forget`.
- **Identity & storage**: UID-based peer addressing with embedded Sled KV database.
- **Transport roadmap**: TCP socket mesh, TLS/TOFU trust model, and SSHFS auto-mounts.

---

## 4. RoguePM 2.0 Architecture (`Development`)

- **Index resolution**: Uniform data model where index `0` is local machine; non-zero indices are remote peers.
- **Profile boundary**: Isolated identities (personal, work, consulting) with linked GitHub accounts.
- **Intent domains**: Functional project groups (e.g., `embedded`, `systems`, `gamedev`).
- **`rg.lock`**: Network-wide concurrency lock to prevent simultaneous edits across peers.
- **`source_pointer`**: Decouple logical project tree from physical disk paths (relative & absolute).
- **`.rgSession`**: Binary snapshot of workspace state for deterministic layout replaying.
- **`knowledge` vault**: Machine reference storage (datasheets, pinouts, POSIX/Vulkan specs) decoupled from git.
- **`workbench`**: Ephemeral runner mounting local/remote sources into isolated tmux sessions.

---

## 5. Planned CLI Commands (Roadmap)

| Command | Purpose |
|---|---|
| `init` | Import existing directory into RoguePM |
| `recent` | List last N active projects by commit time |
| `purge` | Permanently delete local + remote repo |
| `rename` | Rename project folder & update remotes |
| `tag` / `note` / `diary` | Attach metadata, notes, and log entries |
| `task` | Markdown-based project TODO tracker |
| `inspect` / `health` / `doctor` | Tech stack detection and repo integrity checks |
| `next` | Suggest next project to work on |
| `tidy` / `prune` | Clean build artifacts and stale remotes |
| `daily` | Quick summary of today's git activity |
| `share` | Export shareable project card (Markdown/JSON) |
| `serve` | Auto-detect and run project dev server |
| `lint` / `test` | Auto-detect and run linters / test suites |
| `changelog` | Generate formatted changelog from git history |
| `graph` | Generate DOT graph of project dependencies/tags |
| `sync` | Fetch & pull latest changes across all projects |
| `ai context` | Export compact project summary for LLM prompts |
