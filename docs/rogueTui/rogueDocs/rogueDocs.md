# `rogue docs`: Project Document Viewer & TUI Manager

`rogue docs` is a read-only terminal document browser built specifically for project reference assets. It behaves like a specialized file manager, but is scoped entirely to the reference documents borrowed by the active project.

---

## 1. Workbench Window Integration

- When a workbench launches, it can allocate a dedicated tmux window specifically running `rogue docs`.
- Running `rogue docs` manually inside any session window opens the interface immediately.

---

## 2. Session Scoping & Automatic Resolution

- **Per-Project Isolation:** Running `rogue docs` across different terminal sessions automatically detects the active project environment.
- **Manifest Lookup:** Rogue reads the document manifest (e.g. `workspace/docs.json`) located inside the active project directory.
- **No Cross-Pollution:** Only documents borrowed and listed in that specific project's manifest are shown. The rest of the large Knowledge Vault remains hidden.

---

## 3. Interface & Navigation Features

- **Read-Only Safety:** The browser acts strictly as a viewer. It does not allow modifying, deleting, or altering files in the Knowledge Vault.
- **Mouse & Keyboard Support:** Full mouse scrolling, mouse click selection, and standard vi-style keyboard navigation.
- **Interactive Search (`fzf`):** Fuzzy filtering over filenames, document titles, tags, and topics.
- **Hierarchy & Views:** Supports list views with file type icons, categorized grouped views, and sorting by name or type.
- **Direct Viewer Launch:** Selecting an entry launches the file in the appropriate application:
  - Text and Markdown: Terminal pager or configured editor.
  - PDFs: Configured GUI viewer (e.g. Zathura, MuPDF).
  - Images & Schematics: Configured image viewer (e.g. feh, imv).
  - Open With: Prompt or shortcut to pass the document to a custom CLI or GUI command.

---

## 4. Manifest Structure

The project manifest tracks metadata and absolute target paths:

```json
{
  "project_id": "embedded-driver-01",
  "documents": [
    {
      "id": "doc_stm32f4_datasheet",
      "title": "STM32F401 Reference Manual",
      "type": "pdf",
      "path": "/home/user/.knowledge/vault/datasheets/stm32f401.pdf",
      "tags": ["datasheet", "arm", "registers"]
    },
    {
      "id": "doc_pinout_schematic",
      "title": "Board Pinout Schematic",
      "type": "image",
      "path": "/home/user/.knowledge/vault/schematics/board_v1.png",
      "tags": ["hardware", "pinout"]
    }
  ]
}
```
