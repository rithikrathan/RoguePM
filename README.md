# RoguePM

RoguePM is a CLI-based project manager that automates local folder creation, template generation, GitHub/GitLab repository provisioning, bulk version control, and interactive tmux session generation.

---

## Quick Setup

```bash
cd RoguePM
source rogue setup
```

This installs `rogue` to `~/.local/bin`, adds shell integration (bash/zsh/fish), and copies modules/templates to `~/.config/rogue/`. Restart your terminal or source your shell config to use `rogue` anywhere.

---

## Requirements

- `git` — Core VCS.
- `gh` (GitHub CLI) — Authenticated via `gh auth login`.
- `glab` (GitLab CLI) — Authenticated via `glab auth login`.
- `fzf` — Interactive menus (template picker, open, session subdir).
- `jq` — JSON config support.
- `tree` — Directory tree display after template creation.
- `rsync` — File copying during setup.

---

## Commands

### `new`

Creates a project directory, initializes Git, runs a template, commits, and optionally provisions cloud remotes.

**Usage:** `rogue new [project_name] [options]`

**Options:**

- `session` — Launch the interactive session.sh generator (see below).
- `--remote <target>` — `github`, `gitlab`, or `both`. Creates a cloud repo and pushes.
- `--local` — Create project in the current directory (logged to `rp.list`).
- `-r`, `--replace` — Overwrite existing directory without prompt.
- `-v`, `--visibility <public|private>` — Repo visibility (default: private).
- `-t`, `--template <name>` — Template to use. Omit name for fzf picker.
- `-m`, `--message <msg>` — Initial commit message.
- `-d`, `--description` — Prompt for a cloud repo description.
- `-l`, `--license <type>` — License type (default: MIT).

#### `rogue new session`

Interactive generator that produces a `session.sh` file in the project directory. It prompts for:

- Session name
- Optional fzf subdirectory selection at runtime (configurable depth + ignore dirs)
- Windows: editor (nvim), shells (multiple with names + startup commands), lazygit, superfile, opencode (split pane 69/31)
- Custom windows: any number, each with panes, layout (horizontal/vertical/tiled), and per-pane commands
- Reordering: accept default order or rearrange by index

---

### `template`

**Usage:** `rogue template <action> [name]`

- `rogue template list` — List all available templates.
- `rogue template tree <name>` — Show the file tree for a template.

---

### `snapshot`

Bulk push all projects in `PROJECTS_DIR` and `rp.list` to every configured remote.

**Usage:** `rogue snapshot`

---

### `addRemote`

Add a cloud remote to an existing local Git repo.

**Usage:** `rogue addRemote --remote <platform> [options]`

**Options:**

- `--remote <target>` — **Required.** `github`, `gitlab`, or `both`.
- `-v <public|private>` — Repo visibility.
- `-n <name>` — Remote repo name (default: current folder name).
- `-d` — Prompt for description.

---

### `setPat`

Embeds `$GHPAT` / `$GLPAT` into HTTPS remote URLs for password-less auth.

**Usage:** `rogue setPat`

---

### `open`

Fuzzy-find and open a tracked project.

**Usage:** `rogue open [options]`

**Options:**

- `-g`, `--gui` — Use `rofi` instead of `fzf`.
- `-t`, `--terminal` — Run `./session.sh` in the selected project.
- `--term` — Open in a new terminal window.
- `--explorer` — Open in file manager.

---

### `setup`

Install or remove RoguePM.

**Usage:** `rogue setup [options]`

- `--force` — Overwrite existing installation.
- `--remove` — Completely remove RoguePM and shell hooks.
- `--sym` — Symlink `rogue` script instead of copying (points to repo).

---

## Local Project Tracking (`rp.list`)

Projects created with `rogue new --local` are logged to `rp.list`. Both `open` and `snapshot` read this list, so scattered projects receive the same management as centralized ones.
