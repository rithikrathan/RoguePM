# RoguePM v1.0.0

RoguePM is a CLI project manager that automates project creation, template scaffolding, GitHub/GitLab remote provisioning, bulk snapshots, and interactive tmux session generation — all from your terminal.

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

## Quick tour

| Command | What it does |
|---------|-------------|
| `rogue new blog` | Create a project, init git, apply template, optional cloud remote |
| `rogue new blog --remote both` | Same as above, plus create GitHub *and* GitLab repos |
| `rogue new session` | Interactive tmux session generator |
| `rogue open` | Fuzzy-find a project and jump to it |
| `rogue snapshot` | Push all projects to every remote at once |
| `rogue template list` | See available project templates |
| `rogue setup` | Install/update/remove RoguePM |

Run `rogue <command> --help` for detailed options.

---

## Requirements

- **git**, **fzf**, **jq**, **tree**, **rsync**
- **gh** (GitHub CLI) — for GitHub remote features
- **glab** (GitLab CLI) — for GitLab remote features

---

## License

MIT — see [LICENSE](./LICENSE)
