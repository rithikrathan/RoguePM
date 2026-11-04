# RoguePM 1.0 Template Architecture & Execution Scope

Detailed documentation of how templates were structured, authored, and executed in RoguePM 1.0, strictly isolated from external project creation functions like Git repositories or session generators.

---

## 1. Physical Layout on Disk
In RoguePM 1.0, all templates resided in a single flat directory (`RogueTemplates/`):

```
RogueTemplates/
├── cloneDefault.sh          # Cloning utility and setup scripts for authoring new templates
├── default/                 # Baseline template
│   ├── default.sh           # Generator script
│   └── files/               # Static assets folder
│       ├── .gitignore
│       └── TODO.md
├── c/
│   ├── c.sh
│   └── files/
│       ├── .gitignore
│       └── TODO.md
└── ...
```

---

## 2. Template Anatomy & Internal Responsibilities
Each template directory was strictly self-contained with two components:

### A. Template Generator Script (`<template>.sh`)
- Executable script executed directly inside the target directory.
- Input parameters:
  - `-n <name>`: Project name identifier.
  - `-l <license>`: License slug (e.g., `mit`, `apache-2.0`).
  - `-m <message>`: Readme/initial message string.
- Actions performed by the script:
  1. Fetched license text using GitHub CLI (`gh api "/licenses/$LICENSE"`) and wrote `LICENSE`.
  2. Generated `README.md` populated with the project name and message.
  3. Created language-specific directory trees (e.g. `src/`, `include/`, `CMakeLists.txt`).
  4. Copied all boilerplate assets from the local `files/` folder to the target directory.

### B. Static Assets Directory (`files/`)
- Contained static boilerplate files (`.gitignore`, config headers, `TODO.md`) copied verbatim without variable substitution.

---

## 3. Scope Boundary: Template Execution vs. Rogue Functions
A strict boundary existed between what the template did and what the outer Rogue runner handled:

| Component | Responsibility |
|---|---|
| **Template Script** | Code generation, build configs (`CMakeLists.txt`), writing `README.md`/`LICENSE`, copying static assets. |
| **External Rogue PM** | Directory resolution, Git initialization (`git init`), remote cloud repos (`gh repo create`), and session script creation. |

The template script had zero awareness of Git branches, remotes, or terminal sessions.

---

## 4. Template Authoring (`cloneDefault.sh`)
- Authored by duplicating the baseline `default/` template folder.
- `cloneDefault.sh` prompted for the new template name, copied `default/` to the new directory, and renamed `default.sh` to `<new_name>.sh`.
- The author then customized the code generation in `<new_name>.sh` and populated `files/`.

---

# RoguePM 2.0 Template Manager Evolution

Key architectural enhancements introduced in RoguePM 2.0.

---

## 5. Central Sled Database Tracking
- Template metadata is indexed in Sled under `tmpl:<template_id>` instead of remaining purely unmanaged on disk.
- Tracks template slug, absolute filesystem path, setup script filename, and Intent associations.
- The Template Manager automatically discovers and synchronizes new or deleted template directories into Sled.

---

## 6. Intent Domain Scoping & Global Overrides
- Templates can be associated with zero or more Intent domains (e.g. `c` under `embedded` and `systems`; `react` under `web`).
- When scaffolding inside an Intent, the CLI defaults to showing only domain-relevant templates.
- A global flag (`--all` / `--global`) bypasses Intent filtering, exposing the full flat registry on demand.
- Templates with empty intent associations act as universal/global scaffolds (e.g. `empty`, `basic-git`).

---

## 7. Template Composition & Overloading (Layering)
- Supports specifying multiple templates sequentially during project generation.
- Templates execute in strict order, with subsequent templates layering additional assets, configs, or build scripts on top of earlier layers (e.g. base Rust scaffold followed by a GitHub Actions CI template).
- Overlapping file collision handling is documented as an open problem for future refinement.

---

## 8. Shell Abstraction Layer (SAL) Execution
- Template scripts are dispatched via SAL with structured argument arrays rather than raw shell string concatenation.
- Ensures cross-platform execution safety and proper process isolation.
