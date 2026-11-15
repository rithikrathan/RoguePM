# Rogue Interface: CLI & TUI Architecture

Rogue combines fast command-line workflows with interactive terminal user interfaces (built with Ratatui and
fzf). Most actions execute as direct CLI commands, while discovery, navigation, and document browsing
transition smoothly into lightweight, responsive TUIs.

---

## 1. Interaction Model

- **Direct CLI Execution:** basic cli usage for rogue as god intended, status queries, and scripts.
- **Interactive TUI Screens:** Additional tui applications used whenever visual filtering, multi-column
  navigation, or interactive solution is required (e.g., project discovery and document viewing).
- **Session-Aware Context:** Interactive commands automatically infer project context from the current working

---

## 2. CLI Command Hierarchy (RoguePm 1.0)

```
rogue
├── new               Scaffold projects with templates, git repo, and workbench scripts
├── open              Interactive picker (TUI/fzf) to launch project workbench sessions
├── list              Display projects across profiles and intents (tabular / TUI board)
├── docs              Session-aware TUI document manager for borrowed project assets
├── snapshot          Commit and sync workspace state across active projects
├── archive           Safely shelve inactive projects without data loss
├── unarchive         Restore archived projects to active profile directories
├── remote
│   ├── add           Attach Git remote repositories (GitHub, GitLab, self-hosted)
│   └── token         Set or update Personal Access Tokens (PAT)
├── peer              Mesh networking and remote node management
│   ├── discover      Scan local network via mDNS
│   ├── ping          Check node connectivity and latency
│   ├── pair          Request pairing with a peer node
│   ├── accept        Approve incoming peer pairing requests
│   └── forget        Remove paired peer from local registry
└── update            Self-update Rogue binary from source repository
```
