# Plan 2: Per-Project `.rogue` Metadata Directory

## Concept

Each project gets a `.rogue/` directory at its root:

```
~/Desktop/projects/my-project/
├── .git/
├── .rogue/
│   ├── tags          # newline-separated tags
│   ├── todo          # markdown-style task list
│   ├── note          # freeform description
│   ├── diary         # timestamped entries
│   ├── config        # key=value project-level overrides
│   └── meta.json     # structured metadata (last_active, etc.)
├── src/
└── ...
```

This moves metadata out of a central `manifest.json` and into the project itself. The central manifest is simpler — just tracks which projects Rogue knows about.

## Why

- **Portable** — metadata stays with the project if you move/copy it
- **Git-friendly** — each file is plain text, easy to diff, easy to edit manually
- **No jq dependency for reads** — `cat .rogue/tags` is faster and simpler than `jq` queries
- **Works without central config** — inspect a project directly by reading its `.rogue/` directory
- **Easy to extend** — just add a new file in `.rogue/`, no schema changes needed

## Suggested Contents

| File | Format | Purpose |
|------|--------|---------|
| `tags` | newline-separated | Project labels (`web\npersonal\n`) |
| `todo` | markdown list | `- [ ] Fix auth\n- [x] Add tests` |
| `note` | plain text | Freeform project description |
| `diary` | ISO date + text | `2026-06-15: Restyled list output` |
| `config` | key=value | `build_command=npm run dev`, `linter=shellcheck` |
| `meta.json` | JSON | Structured data: last_active timestamp, remote info, etc. |

## Relationship with Commands

Several proposed commands would read/write `.rogue/`:

| Command | Reads | Writes |
|---------|-------|--------|
| `rogue tag` | `tags` | `tags` |
| `rogue note` | `note` | `note` |
| `rogue diary` | `diary` | `diary` |
| `rogue task` | `todo` | `todo` |
| `rogue inspect` | `meta.json`, `config` | — |
| `rogue serve` | `config` | — |
| `rogue lint / test` | `config` | — |
| `rogue health` | All | — |

## Suggestions for Future Additions

- **`.rogue/ignore`** — list of patterns/files for `rogue tidy` to skip in this project
- **`.rogue/remotes`** — per-project remote alias overrides
- **`.rogue/hooks/`** — shell scripts that run on `snapshot`, `sync`, `tidy`, etc.
- **`.rogue/env`** — environment variables to set when running `rogue serve`
- **`rogue init --rogue-only`** — just create `.rogue/` in an existing project without importing it
- **`rogue sync .rogue`** — sync `.rogue/` contents across machines (metadata as code)
- **Template skeleton** — `rogue new` could scaffold `.rogue/` alongside the project

## Consideration: Central vs Per-Project

A hybrid approach works best:

- **Central** (`~/.config/rogue/`): project registry (which dirs to scan), global config
- **Per-project** (`.rogue/`): all metadata specific to that project

This keeps the registry lightweight and the metadata portable. Searches like "find all web projects" would iterate `.rogue/*/tags` files — still fast with bash globbing.
