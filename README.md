# RoguePM v1.2.0

RoguePM is a fast CLI project manager with hierarchical workspaces, organization linking, template scaffolding, multi-remote provisioning (GitHub Organizations / GitLab), bulk snapshots, and interactive tmux session generation.

---

## Getting Started

```bash
# Clone and install
git clone https://github.com/rithikrathan/RoguePM
cd RoguePM
source rogue setup

# Restart your terminal, then use rogue anywhere:
rogue --version
rogue --help
```

---

## Command Quick Tour

| Command | What it does |
|---|---|
| `rogue new [name]` | Create a project (interactive or flags for template, remote, workspace) |
| `rogue new [name] --ws <name>` | Create a project inside a registered workspace / GitHub Org |
| `rogue ws add <name>` | Register a folder as a workspace profile (with optional GitHub Org link) |
| `rogue ws list` | View all registered workspaces, paths, linked GitHub orgs, and project counts |
| `rogue ws remove <name>` | Unregister a workspace profile |
| `rogue ws link <dir> [--ws <name>]` | Track an external local directory (under a workspace profile or as an orphan) |
| `rogue ws unlink <dir>` | Remove an external directory from tracking |
| `rogue ws sync <name>` | Clone all missing repositories from the workspace's GitHub Org |
| `rogue open [query]` | 2-step drilldown picker (`fzf` or `bemenu`) for workspaces, projects & orphans |
| `rogue open -w <name>` | Jump straight into a specific workspace's project picker |
| `rogue list` | Formatted table of all projects grouped by workspace |
| `rogue archive <name>` | Shelf a project locally to Archived and archive GitHub/GitLab remotes |
| `rogue unarchive <name>` | Restore an archived project locally and unarchive cloud remotes |
| `rogue snapshot` | Commit and push changes across all active workspaces and projects |
| `rogue new session` | Interactive tmux session generator |
| `rogue template list` | See available project templates |
| `rogue setup` | Install/update/remove RoguePM without overwriting user configs |
| `rogue update` | Pull latest from repository and update safely |

---

## Working With Workspaces & Organizations

### 1. Registering a Workspace or GitHub Organization

```bash
# Register an organization workspace linked to GitHub Org 'acme-corp'
rogue ws add work-org --path ~/projects/work-org --org acme-corp --email dev@acme.com

# Register an archived workspace (hidden by default and skipped during snapshots)
rogue ws add Archived --path ~/projects/Archived --skip-snapshot --hidden

# Register reference / vendor repositories (skipped during snapshots)
rogue ws add _notmystuff --path ~/projects/_notmystuff --skip-snapshot
```

### 2. Creating a New Project in a Workspace

You have two ways to create a project in a workspace:

#### A. Interactive Creation (Prompts)
Simply run:
```bash
rogue new
```
1. If workspaces are registered, Rogue opens a fuzzy picker to choose the **Target Workspace** (`Default`, `work-org`, `Opensource`, etc.).
2. Prompts for **Project Name**.
3. Opens the **Template Picker** (`c`, `go`, `rust`, `python`, `arduino`, etc.).
4. Sets the repository remote to `https://github.com/<org>/<name>.git` (if `--remote github` or configured) and applies git author email.

#### B. Direct Flags (Non-Interactive / Fast)
Pass flags directly to bypass prompts:
```bash
# Create an API project in workspace 'work-org' with 'go' template and private GitHub Org remote
rogue new api-service --ws work-org -t go --remote github -v private -m "Initial microservice commit"

# Create a local project in current folder and link to 'work-org'
rogue new quick-tool --local --ws work-org
```

### 3. Tracking External & Orphan Local Projects

If you have repositories outside `$PROJECTS_DIR`:
```bash
# Link an external folder to a workspace profile
rogue ws link ~/work/client-portal --ws work-org

# Track an external folder as an unassociated Standalone / Orphan project
rogue ws link ~/.config/nvim
```

---

## Navigation (`rogue open`)

Running `rogue open` uses a clean 2-step drill-down navigation:
* **Step 1:** Shows top-level workspaces (` [WS]`), default root projects (``), and standalone orphan packages (` [orphan]`).
* **Step 2:** Selecting a workspace expands only its internal projects (`› project-name`).

#### GUI Options:
* `rogue open -gt`: Pick via `bemenu` and open in `$TERMINAL_APP`.
* `rogue open -ge`: Pick via `bemenu` and open in `$FILE_MANAGER`.
* `rogue open -e`: Pick via `fzf` and open in `$FILE_MANAGER`.
* `rogue open -w <name>`: Directly open sub-picker for a specific workspace.

---

## Requirements

- **git**, **fzf**, **jq**, **tree**, **rsync**
- **gh** (GitHub CLI) — for GitHub Organization and remote features
- **glab** (GitLab CLI) — for GitLab remote features
- **bemenu** *(optional)* — for Wayland/X11 GUI pickers

---

## License

MIT — see [LICENSE](./LICENSE)
