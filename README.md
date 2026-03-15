```text
  ____                                  ____   __  __ 
 |  _ \  ___    __ _  _   _  ___       |  _ \ |  \/  |
 | |_) |/ _ \  / _` || | | | / _ \     | |_) || |\/| |
 |  _ <| (_) || (_| || |_| ||  __/     |  __/ | |  | |
 |_| \_\\___/  \__, | \__,_| \___|_____|_|    |_|  |_|
               |___/             |_____|

```

# RoguePM

RoguePM is a CLI-based project manager made as a hobby to learn Bash scripting. The methods are simple and straightforward. It automates local folder creation, template generation, GitHub/GitLab repository provisioning, and bulk version control tasks.

---

## Installation

1. Clone the repository anywhere on your system:

```bash
git clone [https://github.com/rithikrathan/RoguePM.git](https://github.com/rithikrathan/RoguePM.git)
cd RoguePM

```

2. Make the script executable:

```bash
chmod +x rogue

```

---

## Quick Setup

To use the `rogue` command anywhere in your terminal, add the following snippet to your shell configuration file (e.g., `~/.bashrc` or `~/.zshrc`).

Replace `/path/to/your/cloned/RoguePM` with the actual directory where you cloned the repository, and insert your Personal Access Tokens.

```bash
# ========================
# RoguePM Setup
# ========================
export GHPAT="your_github_personal_access_token_here"
export GLPAT="your_gitlab_personal_access_token_here"

rogue() {
    source /path/to/your/cloned/RoguePM/rogue "$@"
}

```

After pasting this into your config file, reload your shell:

```bash
source ~/.bashrc  # or source ~/.zshrc

```

---

## Requirements

* `git` - Core version control.
* `gh` (GitHub CLI) - Must be authenticated (`gh auth login`).
* `glab` (GitLab CLI) - Must be authenticated (`glab auth login`).
* `fzf` or `rofi` - Required for the interactive `open` menu.

---

## Configuration (`.roguerc`)

RoguePM looks for a configuration file at `~/.roguerc` to override its default variables.

Creating a `.roguerc` file is optional. The hardcoded defaults will work perfectly for most setups, but the system is there for future-proofing. If you use it, you can define:

* `PROJECTS_DIR` (Default: `$HOME/Desktop/projects`) - The main directory where new projects are generated.
* `TEMPLATES_DIR` (Default: `$HOME/Desktop/projects/RoguePM/RogueTemplates`) - The folder containing your custom bash setup scripts.
* `LOCAL_PROJECTS_LIST` (Default: `$HOME/Desktop/projects/RoguePM/rp.list`) - The tracker file for projects generated outside the main directory.
* `DEFAULT_REMOTE` (Default: `github`) - The fallback platform.

---

## Commands

### `new`

Creates a new project directory, initializes Git, runs a setup template, makes an initial commit, and provisions cloud remotes.

**Usage:** `rogue new <project_name> [options]`

**Options:**

* `--remote <target>`: Provisions a cloud repository and pushes the initial commit. Accepts `github`, `gitlab`, or `both`.
* `--local`: Creates the project in your current working directory instead of the global `PROJECTS_DIR`. Automatically logs the path to `rp.list`.
* `-r`, `--replace`: Deletes and overwrites the directory if it already exists.
* `-t`, `--template <name>`: Executes a specific setup script from `TEMPLATES_DIR`. Defaults to `default.sh`.
* `-m`, `--message <msg>`: Sets the initial commit message.
* `-d`, `--description <msg>`: Sets the repository description on GitHub/GitLab.
* `-l`, `--license <type>`: Specifies the project license. Defaults to MIT.

---

### `addRemote`

Retroactively creates a cloud repository for an existing local Git project, links it using the platform's name (`github` or `gitlab`), and pushes the `master` branch.

**Usage:** `rogue addRemote --remote <platform> [options]`

**Options:**

* `--remote <target>`: **Required.** Must be `github`, `gitlab`, or `both`. Will fail safely if the remote name already exists locally.
* `-n`, `--name <name>`: Specifies the remote repository name. Defaults to the current folder name.
* `-d`, `--description <msg>`: Sets the cloud repository description.

---

### `snapshot`

A bulk-action command. It iterates through all projects inside `PROJECTS_DIR` and every path tracked in `rp.list`. Outputs a clean summary table upon completion.

**Workflow per project:**

1. Checks for uncommitted changes.
2. If changes exist, stages all files and commits them with a standard "Project snapshot" message.
3. Detects all configured remotes for the project.
4. Pushes the changes to every detected remote (handles `github`, `gitlab`, and legacy `origin` remotes).
5. Reports success, push conflicts, or skips the project if it is up-to-date.

**Usage:** `rogue snapshot`

---

### `setPat`

Secures your remote connections by embedding Personal Access Tokens directly into the Git remote URLs. This allows you to push/pull without relying on global credential managers.

**Workflow:**

1. Scans all remotes attached to the current repository.
2. Checks the URL of each remote.
3. If it detects `github.com`, it updates the URL with your `$GHPAT`.
4. If it detects `gitlab.com`, it updates the URL using the `oauth2:$GLPAT` format.
5. **Safeguards:** Skips SSH URLs entirely to prevent breaking them. Detects and handles legacy `origin` remotes by parsing their domain.

**Usage:** `rogue setPat`

---

### `open`

Provides an interactive menu to jump into any tracked project. It pulls directories from both `PROJECTS_DIR` and the `rp.list` file (marking the latter with a `[Local]` tag).

**Usage:** `rogue open [options]`

**Options:**

* `-g`, `--gui`: Uses `rofi` for the selection menu instead of the default `fzf`.
* `-t`, `--terminal`: Automatically executes `./session.sh` in the selected project directory if the file exists.
* `--term`: Opens the selected project in a new Alacritty terminal window.
* `--explorer`: Opens the selected project in the Nautilus file manager.

---

## Local Project Tracking (`rp.list`)

RoguePM supports managing projects stored anywhere on your system, not just in `PROJECTS_DIR`.

When you use the `rogue new --local` command, the absolute path of the new project is appended to the `rp.list` file. Both the `open` menu and the `snapshot` batch processor read this list automatically, ensuring your scattered projects receive the exact same management as your centralized ones.

