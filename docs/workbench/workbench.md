# RoguePM Workbench Architecture

A **workbench** is an executable tmux session generator script stored in `~/.workbench/`.

When opening a project, Rogue executes its workbench script to start an isolated tmux session configured with all required panes, windows, and tools.

---

## 1. Design & Workflow

- **Session Generator:** Each project maps to a workbench shell script in `~/.workbench/`. Running the script creates and attaches to a dedicated tmux session.
- **Root Directory:** The session starts rooted directly inside the project directory.
- **Semi-TUI Workflow:** Rogue operates primarily through CLI commands, using focused Ratatui interfaces for selection menus, project switching, and status overviews.

---

## 2. Local and Peer Projects

- **Local Projects (Index 0):**
  - Resolves directly to the local directory path.
  - Launches tmux directly in the native project directory.
- **Remote Peer Projects (Index > 0):**
  - Mounted locally over SSHFS via `rogued` and `IndexResolver` under the `rg.lock` network lease.
  - Launches the tmux session inside the mount path.

---

## 3. Project Documentation via `rogue docs`

Reference manuals, datasheets, and guides borrowed from the Knowledge Vault are decoupled from the code tree:

- **Manifest:** Borrowed documents are tracked in a simple file (such as `docs.json`) inside the project's `workspace/` directory.
- **`rogue docs`:** Running `rogue docs` inside an active session reads `workspace/docs.json` and opens an interactive `fzf` picker.
- **Viewing:** Selecting an entry opens the document in the user's preferred viewer (such as a terminal pager, PDF viewer, or image viewer) directly from the Knowledge Vault storage path.

---

## 4. Templates & Lifecycle

- **Layout Compilation:** Project templates provide initial window and pane configurations. Rogue Core compiles these layouts into the project's workbench script in `~/.workbench/`.
- **Session Replay:** Workspace state snapshots (`.rgSession`) store active tab arrangements and regenerate the workbench script on demand.
