# RoguePM Feature Plan

## Data Storage

A single central manifest at `~/.config/rogue/manifest.json` stores all metadata:

```json
{
  "tags": {
    "project-name": ["web", "personal", "archived"]
  },
  "notes": {
    "project-name": "Any freeform description"
  },
  "diaries": {
    "project-name": [
      {"date": "2026-05-29", "entry": "Worked on auth module"}
    ]
  },
  "archive": ["project-name"],
  "last_active": {
    "project-name": "2026-05-29T14:30:00"
  }
}
```

Uses `jq` for read/write (already a dependency). All commands source this file.

---

## 1. `rogue init <dir>`

**Purpose:** Import an existing directory as a RoguePM project.

**Usage:** `rogue init /path/to/existing-project`

**Implementation:**

```bash
cmd_init() {
    local src_dir="$1"
    # validate dir exists and is not already tracked
    # if --local flag, add to rp.list
    # otherwise, cp -r or mv into PROJECTS_DIR
    # cd and echo to /tmp/.rogue_cd
}
```

**Edge cases:**
- dir already in `$PROJECTS_DIR` or `rp.list` → skip with warning
- no argument → `fzf` pick a directory
- `--move` flag → `mv` instead of `cp`

**Output style:**
```
────────────────────────────────────────────
[Rogue] Initializing Project

  ◆ Copying project to workspace...
  ◆ Registering project...
  ◆ Done
```

---

## 2. `rogue list`

**Purpose:** Print a formatted table of all projects with metadata.

**Usage:** `rogue list [--tag <tag>] [--archived]`

**Implementation:**

```bash
cmd_list() {
    # Assemble proj dirs from PROJECTS_DIR + rp.list
    # For each:
    #   basename, branch, clean/dirty, last commit time
    # Pull tags from manifest
    # Print aligned table with color-coded status
}
```

**Flags:**
- `--tag web` — filter by tag
- `--archived` — include archived projects
- `--dirty` — show only uncommitted projects

**Output style:**
```
────────────────────────────────────────────
[Rogue] All Projects

  Project           Branch     Status     Tag           Last Commit
  rogue             main       ● clean    tool          2h ago
  my-site           dev        ● dirty    web,personal  5m ago
  notes-app         main       ● clean    web           3d ago
```

- Status dot: green clean, yellow dirty, red broken
- If no projects → `[Rogue] No projects found.`

---

## 3. `rogue recent`

**Purpose:** Show last N projects by latest commit time.

**Usage:** `rogue recent [count]`

**Implementation:**

```bash
cmd_recent() {
    local limit="${1:-10}"
    # Collect all projects, git log -1 --format=%ct for each
    # Sort by timestamp descending, take top $limit
    # Show in concise list: number, name, time ago
}
```

**Edge cases:**
- No commits yet → ignore empty repos
- count > total projects → show all

**Output style:**
```
────────────────────────────────────────────
[Rogue] Recent Projects

  1  rogue         2h ago
  2  my-site       5m ago
  3  notes-app     3d ago
  4  old-project   2w ago
```

---

## 4. `rogue archive <name>` / `rogue unarchive <name>`

**Purpose:** Shelf a project without deleting it.

**Usage:** `rogue archive rogue` / `rogue unarchive rogue`

**Implementation:**

```bash
cmd_archive() {
    local name="$1"
    # mv PROJECTS_DIR/name -> ARCHIVE_DIR/name
    # Add to manifest["archive"] array
    # Remove from rp.list if there
}

cmd_unarchive() {
    local name="$1"
    # mv ARCHIVE_DIR/name -> PROJECTS_DIR/name
    # Remove from manifest["archive"]
}
```

**Config:** Add `ARCHIVE_DIR="$HOME/Desktop/archived"` variable.

**Edge cases:**
- project already archived → error
- no name given → list archived projects with fzf to pick
- unarchive when name exists in PROJECTS_DIR → error

**Output style:**
```
────────────────────────────────────────────
[Rogue] Archiving Project

  ◆ Moving project to archive...
  ◆ Done
```

---

## 5. `rogue purge <name>`

**Purpose:** Permanently delete a project (local + remote).

**Usage:** `rogue purge rogue`

**Implementation:**

```bash
cmd_purge() {
    local name="$1"
    # Confirm: "Delete rogue? This cannot be undone. (y/N): "
    # Remove local dir: rm -rf PROJECTS_DIR/name
    # If remote exists:
    #   Prompt: "Delete GitHub remote too? (y/N): "
    #   gh repo delete
    # Remove from rp.list, manifest, archive list
}
```

**Flags:**
- `--force` — skip confirmation
- `--local-only` — skip remote deletion

**Edge cases:**
- project not found → error
- gh/glab auth expired → warn and skip remote

**Output style:**
```
────────────────────────────────────────────
[Rogue] Purging Project

  ◆ Deleting local directory...
  ◆ Deleting GitHub remote...
  ◆ Done
```

---

## 6. `rogue rename <old> <new>`

**Purpose:** Rename project folder + update remote.

**Usage:** `rogue rename old-name new-name`

**Implementation:**

```bash
cmd_rename() {
    local old="$1" new="$2"
    # mv PROJECTS_DIR/old -> PROJECTS_DIR/new
    # Update manifest key from old -> new
    # Update rp.list entries
    # If remote exists, prompt: rename remote too?
    #   gh repo rename new-name
}
```

**Edge cases:**
- new-name already exists → error
- old-name not found → error
- remote rename fails → warn but keep local rename

**Output style:**
```
────────────────────────────────────────────
[Rogue] Renaming Project

  ◆ Renaming folder...
  ◆ Updating references...
  ◆ Renaming GitHub remote...
  ◆ Done
```

---

## 7. `rogue tag`

**Purpose:** Tag/unfilter projects with labels.

**Usage:**
- `rogue tag rogue add web personal` — add tags
- `rogue tag rogue remove web` — remove a tag
- `rogue tag rogue list` — list tags for project
- `rogue tag list` — list all tags in use
- `rogue tag list --tag web` — list projects tagged "web"

**Implementation:**

```bash
cmd_tag() {
    local sub="$1"; shift
    case "$sub" in
        add)    # read manifest, add tags to project's array
        remove) # read manifest, remove tags
        list)   # list tags for a project, or all tags
        *)      # error
    esac
}
```

**Data:** stored in `manifest.json["tags"]`.

**Output style:**
```
────────────────────────────────────────────
[Rogue] Tagging Project

  ◆ Adding tags: web, personal
  ◆ Done
```

---

## 8. `rogue note`

**Purpose:** Attach a freeform description to a project.

**Usage:**
- `rogue note rogue "A CLI tool for project management"`
- `rogue note rogue` — edit existing note with nvim
- `rogue note rogue --show` — print note

**Flags:** `--show`, `--edit` (default: interactive)

**Implementation:**

```bash
cmd_note() {
    local name="$1"; shift
    # If no args and note exists, open $EDITOR on temp file
    # Then write back to manifest
}
```

**Data:** stored in `manifest.json["notes"]`.

**Output style:**
```
────────────────────────────────────────────
[Rogue] Note for rogue

  A CLI tool for project management
```

---

## 9. `rogue diary`

**Purpose:** Append a timestamped diary entry for a project.

**Usage:**
- `rogue diary rogue` — prompts for entry text
- `rogue diary rogue "Worked on auth flow"` — one-liner
- `rogue diary rogue --recent` — show last 5 entries

**Implementation:**

```bash
cmd_diary() {
    local name="$1"; shift
    # Read entry (from arg or prompt)
    # Append to manifest["diaries"][name] with ISO date
}
```

**Data:** stored in `manifest.json["diaries"]`.

**Output style:**
```
────────────────────────────────────────────
[Rogue] Diary Entry for rogue

  ◆ 2026-05-29 — Worked on auth flow
```

---

## 10. `rogue inspect`

**Purpose:** Detect tech stack, framework, language of a project.

**Usage:** `rogue inspect rogue`

**Heuristics (checklist):**

```bash
cmd_inspect() {
    # Check for indicator files:
    #   package.json        → Node.js + read "dependencies" for framework
    #   Cargo.toml          → Rust
    #   go.mod              → Go
    #   pyproject.toml      → Python
    #   *.py                → Python
    #   CMakeLists.txt      → C/C++ (CMake)
    #   Makefile            → C/C++
    #   *.c / *.h           → C
    #   *.cpp / *.hpp       → C++
    #   *.rs                → Rust
    #   *.tsx / *.jsx       → React/TypeScript
    #   *.vue               → Vue
    #   *.svelte            → Svelte
    #   shopt -s nullglob to check globs
    # Print detected stack
}
```

**Output style:**
```
────────────────────────────────────────────
[Rogue] Inspecting rogue

  Language:    Bash
  Framework:   (none)
  Build tool:  (none)
  Dependencies: git, fzf, jq, gh, glab, tree
  Type:        CLI tool

────────────────────────────────────────────
[Rogue] Inspecting my-site

  Language:    TypeScript, CSS, HTML
  Framework:   React (Next.js)
  Build tool:  npm
  Dependencies: react, next, tailwindcss
  Type:        Web app
```

---

## 11. `rogue health`

**Purpose:** Per-project checklist showing quality indicators.

**Usage:** `rogue health rogue`

**Checklist:**

```bash
cmd_health() {
    local name="$1"
    # Checks:
    #   ✓ Has README.md
    #   ✓ Has LICENSE
    #   ✓ Has .gitignore
    #   ✓ Has remote configured
    #   ✓ Last commit < 30 days
    #   ✓ Clean working tree
    #   ✓ Has description/note
    #   ✓ Has tags
}
```

**Flags:**
- `--all` — run health check on every project, show summary

**Output style:**
```
────────────────────────────────────────────
[Rogue] Health Check: rogue

  ✓ README.md
  ✓ LICENSE
  ✓ .gitignore
  ✓ Remote configured
  ✓ Recent commit (2h ago)
  ✓ Clean working tree
  ✗ No description note
  ✗ No tags

  6/8 passing
```

---

## 12. `rogue doctor`

**Purpose:** Check project integrity (low-level issues).

**Usage:** `rogue doctor`

**Checks:**
- `.git` directory exists and is valid
- Project path exists on disk
- rp.list entries point to real dirs
- Remote URLs are valid format
- No broken symlinks
- Owner matches current user

**Output style:**
```
────────────────────────────────────────────
[Rogue] Doctor — Project Integrity

  ◆ Checking rogue...    ✓ OK
  ◆ Checking my-site...  ✗ Broken remote URL
  ◆ Checking notes-app... ✓ OK
  ◆ Checking rp.list...  ✓ All paths valid

  Found 1 issue.
  ── my-site ──
  Remote 'github' URL is malformed. Run 'rogue setPat' to fix.
```

---

## 13. `rogue next`

**Purpose:** Suggest which project to work on.

**Algorithm:**
- Collect all projects
- Filter: must have recent commit (< 90 days)
- Score: stale days + dirty bonus + no recent entry in diary
- Return top pick

**Usage:** `rogue next`

**Flags:**
- `--list` — show top 5 ranked
- `--tag web` — only projects with that tag

**Output style:**
```
────────────────────────────────────────────
[Rogue] Next Project

  ◆ my-site — 5 days stale, 3 uncommitted files
```

Or with `--list`:
```
────────────────────────────────────────────
[Rogue] Next Projects

  1  my-site       5 days stale, dirty
  2  notes-app     12 days stale
  3  rogue         2 days stale
```

---

## 14. `rogue tidy`

**Purpose:** Find and delete build artifacts across all projects.

**Usage:** `rogue tidy` (dry-run by default)

**Flags:**
- `--apply` — actually delete
- `--project rogue` — only one project

**Targets:**
- `node_modules/`
- `target/` (Rust)
- `build/`, `dist/`, `.next/`, `out/`
- `__pycache__/`, `*.pyc`
- `.terraform/`
- `vendor/` (Go)
- `.venv/`, `venv/`
- `*.o`, `*.obj`, `*.class`

**Implementation:**

```bash
cmd_tidy() {
    # For each project (or specified), run find with -d depth limits
    # Show total reclaimed size with du -sh
    # Dry-run: just list what would be deleted
}
```

**Output style:**
```
────────────────────────────────────────────
[Rogue] Project Cleanup (dry-run)

  ◆ my-site
      node_modules/  45.2 MB
      .next/         12.1 MB
  ◆ notes-app
      node_modules/  28.7 MB

  Total reclaimable: 86.0 MB
  Run with --apply to delete.
```

---

## 15. `rogue daily`

**Purpose:** Quick summary of activity across all projects today.

**Usage:** `rogue daily`

**Implementation:**

```bash
cmd_daily() {
    # For each project with git log --since=midnight --oneline
    # Show commits today
    # Also check diary entries from today
    # Print summary
}
```

**Output style:**
```
────────────────────────────────────────────
[Rogue] Daily Summary — 2026-05-29

  ◆ rogue
      2 commits — style: fancy output, fix divider
      Diary: Restyled all command output

  ◆ my-site
      1 commit — fix navbar
```

---

## 16. `rogue share <name>`

**Purpose:** Print project info in a custom format for sharing.

**Usage:** `rogue share rogue`

**Flags:**
- `--format markdown` — output as markdown
- `--format json` — machine-readable
- `--format pretty` — colored terminal output (default)

**Implementation:**

```bash
cmd_share() {
    local name="$1"
    # Collect: name, description (from note), tech stack (from inspect),
    #          tags, remote URL, last commit, repo visibility
    # Format and print based on --format flag
}
```

**Output style (default pretty):**
```
────────────────────────────────────────────
[Rogue] rogue

  RoguePM — A CLI project manager
  https://github.com/rithikrathan/RoguePM

  Bash        Private     Updated 2h ago
  #cli #tool  MIT license 1 commit today
```

**Markdown format:**
```
## rogue

RoguePM — A CLI project manager
- **URL:** https://github.com/rithikrathan/RoguePM
- **Stack:** Bash
- **License:** MIT
- **Tags:** cli, tool
```

---

## 17. `rogue serve <name>`

**Purpose:** Auto-detect and start the dev server for a project.

**Heuristics:**

```bash
cmd_serve() {
    # package.json → npm run dev
    # Cargo.toml   → cargo run
    # Makefile     → make
    # *.py         → python main.py or flask run
    # go.mod       → go run .
    # index.html   → python -m http.server
    # else → error: no known dev command
}
```

**Flags:**
- `--port 3000` — override port (for servers that accept it)
- `--detach` — run in background

**Output style:**
```
────────────────────────────────────────────
[Rogue] Serving my-site

  ◆ Detected: Next.js (npm run dev)
  ◆ Starting on port 3000...
  ◆ http://localhost:3000
```

---

## 18. `rogue task <name>`

**Purpose:** Quick per-project TODO notes (lightweight task list).

**Usage:**
- `rogue task rogue` — list pending tasks for the project
- `rogue task rogue add "Fix auth bug"` — add a task
- `rogue task rogue done 1` — mark task 1 as done
- `rogue task rogue clear` — clear all done tasks

**Implementation:**

```bash
cmd_task() {
    local name="$1"; shift
    local action="${1:-list}"; [ $# -gt 0 ] && shift
    # Data stored in manifest.json["tasks"]["project-name"]
    # Each task: {id, text, done, created}
    case "$action" in
        add)   # append to tasks array
        done)  # mark index as done
        clear) # remove done tasks
        list)  # print pending and done
    esac
}
```

**Data:** stored in `manifest.json["tasks"]`.

**Output style:**
```
────────────────────────────────────────────
[Rogue] Tasks for rogue

  Pending:
    1  Fix auth bug                           2h ago
    2  Write tests for list command           yesterday

  Done:
    3  Style all command output               3d ago

────────────────────────────────────────────
[Rogue] Tasks for rogue

  ◆ Added task: "Fix auth bug"
```

---

## 19. `rogue template create`

**Purpose:** Turn an existing project into a reusable template.

**Usage:** `rogue template create rogue`

**Implementation:**

```bash
cmd_template_create() {
    local name="$1"
    # Copy PROJECTS_DIR/name -> TEMPLATES_DIR/name
    # Remove .git/ and any project-specific files
    # Create template_name.sh with same structure as other templates
    # Open the new .sh in $EDITOR for customization
    # Show: "Template created. Edit it: rogue template tree name"
}
```

**Flags:**
- `--name my-template` — override template name
- `--files-only` — just copy the files dir, skip script generation

**Output style:**
```
────────────────────────────────────────────
[Rogue] Creating Template

  ◆ Copying project structure...
  ◆ Stripping .git...
  ◆ Generating template script...
  ◆ Opening template.sh for editing...
  ◆ Done. Run 'rogue template tree my-project' to verify.
```

---

## 20. `rogue config`

**Purpose:** Interactive editor for `rogueConf.json`.

**Usage:** `rogue config`

**Implementation:**

```bash
cmd_config() {
    # Show current config in a numbered menu
    # 1. Projects dir: ~/Desktop/projects
    # 2. Templates dir: ~/.config/rogue/templates
    # 3. Default remote: github
    # 4. Terminal app: alacritty
    # 5. File manager: dolphin
    # Enter number to edit, or 'q' to quit
    # Use jq to update the JSON
}
```

**Flags:**
- `--get <key>` — print single value
- `--set <key> <value>` — set value directly

**Output style:**
```
────────────────────────────────────────────
[Rogue] Configuration

  1  Projects dir     ~/Desktop/projects
  2  Templates dir    ~/.config/rogue/templates
  3  Default remote   github
  4  Terminal app     alacritty
  5  File manager     dolphin

  Enter number to edit (q to quit):
```

---

## 21. `rogue stats`

**Purpose:** Show aggregate project statistics.

**Usage:** `rogue stats`

**Metrics:**
- Total projects (active / archived)
- Templates used (count per template)
- Languages detected (from inspect heuristics)
- Total commits across all projects
- Total disk usage (du -sh)
- Last snapshot time
- Most tagged tags

**Output style:**
```
────────────────────────────────────────────
[Rogue] Project Statistics

  Total projects:  12 (10 active, 2 archived)
  Disk usage:      1.2 GB
  Languages:       JavaScript (4), Python (3), Rust (2), Bash (2), Go (1)
  Templates used:  default (6), web (3), python (2), rust (1)
  Top tags:        web (4), personal (3), tool (2), archived (2)
  Most active:     rogue (18 commits this month)
```

---

## 22. `rogue update`

**Purpose:** Self-update RoguePM from its Git repository.

**Usage:** `rogue update`

**Implementation:**

```bash
cmd_update() {
    # Detect RoguePM repo dir (ROGUE_DIR)
    # git fetch origin
    # Compare local HEAD vs origin/main
    # If behind:
    #   Show changelog (git log HEAD..origin/main --oneline)
    #   Prompt: "Update? (Y/n): "
    #   git pull --ff-only
    #   Re-run setup logic (reinstall modules, templates)
    #   log_success "Updated to $(git rev-parse --short HEAD)"
    # If up-to-date: log_info "Already up to date."
}
```

**Flags:**
- `--force` — update without prompt
- `--check` — just check, don't update

**Edge cases:**
- Not a git repo → error
- Dirty working tree → stash before pull, then pop
- Merge conflict → abort, tell user to resolve manually

**Output style:**
```
────────────────────────────────────────────
[Rogue] Checking for Updates

  ◆ Fetching origin...
  ◆ 3 commits behind main
    d4f2e1a fix: typo in divider
    a7b3c2d feat: add list command
    9e1f5b0 style: new output format

  Update to latest? (Y/n): y
  ◆ Pulling changes...
  ◆ Reinstalling modules...
  ◆ Reinstalling templates...
  ◆ Done

[Rogue] Updated to a7b3c2d
```

---

## 23. `rogue prune`

**Purpose:** Clean up dead remotes and stale project config.

**Usage:** `rogue prune`

**Flags:**
- `--remote` — only check remote health
- `--orphan` — check manifest for projects not on disk
- `--all` — run all checks

**Implementation:**

```bash
cmd_prune() {
    # For each project with remotes:
    #   gh repo view owner/name --json name 2>/dev/null
    #   If fails → remote is dead, offer to remove
    # For manifest entries:
    #   Check if project dir exists on disk
    #   If not, offer to remove manifest entry
}
```

**Output style:**
```
────────────────────────────────────────────
[Rogue] Pruning

  ◆ Checking remotes...
    dead-project — GitHub remote 404. Remove? (y/N):
  ◆ Checking manifest...
    old-test — project dir missing. Clean up manifest? (y/N):
  ◆ Done
```

---

## 24. `rogue remote cleanup`

**Purpose:** Scan GitHub/GitLab for repos without a local project.

**Usage:** `rogue remote cleanup`

**Implementation:**

```bash
cmd_remote_cleanup() {
    # gh repo list --limit 100 --json name
    # glab api projects --paginate
    # Cross-reference with local projects (basename match)
    # Show orphaned repos in a numbered list
    # Prompt: "Delete these 5 repos on GitHub? (y/N): "
    # On confirm: gh repo delete for each
}
```

**Flags:**
- `--dry-run` — just list, don't delete
- `--platform github` — only GitHub

**Output style:**
```
────────────────────────────────────────────
[Rogue] Remote Cleanup (dry-run)

  Orphaned on GitHub:
    1  test-playground     last push 2024-11-01
    2  old-blog            last push 2024-08-15
    3  learning-rust       last push 2025-01-20

  Orphaned on GitLab:
    4  sandbox-project     last push 2024-12-01

  Run with --apply to delete.
```

---

## Dispatcher & Module Structure

**In `rogue` (main dispatcher), add to the case statement:**

```bash
case "$command" in
    # existing commands...
    init|list|recent|archive|unarchive|purge|rename|tag|note|diary|task|inspect|health|doctor|next|tidy|daily|share|serve|update|prune|cleanup|stats|config)
        "cmd_$command" "$@" ;;
esac
```

**File organization:**

| File | Commands |
|---|---|
| `modules/project.sh` | init, list, recent, rename, purge |
| `modules/archive.sh` | archive, unarchive |
| `modules/meta.sh` | tag, note, diary, task |
| `modules/inspect.sh` | inspect, health, doctor, next |
| `modules/maintain.sh` | tidy, prune, remote cleanup, update |
| `modules/daily.sh` | daily, share, serve |
| `modules/stats.sh` | stats |
| `modules/template.sh` | (existing) + template create |
| `rogue` (inline) | setup, config |

Or fewer files if preferred — all new commands can go into `modules/project.sh` and `modules/ops.sh`.

---

## Styling Convention

All new commands follow the same output style:

```
────────────────────────────────────────────
[Rogue] Command Title (BOLD_ITALIC_UNDERLINE)

  ◆ Step message...    (log_step — red ◆, no [Rogue])
  ◆ Another step...

[Rogue] Final result   (log_success — [Rogue] + green)
```

- `log_step()` — `echo -e "  ${ROGUE_RED_SOLID}◆${RESET} $1"`
- `log_success()` — `echo -e "${ROGUE_RED_ITALIC}[Rogue]${RESET} ${GREEN}$1${RESET}"`
- `log_error()` — unchanged
- `log_prompt()` — unchanged
- Separator — `echo -e "\n────────────────────────────────────────────"`
- Section title — `echo -e "${ROGUE_RED_ITALIC}[Rogue]${RESET} ${BOLD_ITALIC_UNDERLINE}Title${RESET}\n"`
