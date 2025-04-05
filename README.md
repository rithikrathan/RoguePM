# Rogue_PM

Rogue_PM is a lightweight CLI-based project manager written in Bash. It automates the creation of new project directories, initializes Git repositories, connects them to GitHub via the GitHub CLI, and populates them using predefined templates.

## Features

- Create and scaffold new project folders
- Initialize local Git repos and push to GitHub
- Use custom templates for different project types
- Simple CLI interface

## Potential future additions

- Task tracking
- Environment config
- Dependency setup
- Build/run/test automation
- ...i ran out of ideas

## Requirements

- Bash
- `git`
- `gh` (GitHub CLI)

## Installation

1. Clone the repository:
    ```bash
    git clone https://github.com/rithikrathan/RoguePM.git
    cd RoguePM
2. Make the script executable:
    ```bash
    chmod +x Rogue.sh

## Usage

```bash
source Rogue.sh new <flags>

# Flags:
# -t <template name>        : Creates the project directory based on the given template
# -r                        : If a directory with the project name already exists, it will be replaced (existing files will be deleted)
# -v <public/private>       : Sets the GitHub repository's visibility (default: private)
# -m <initial commit msg>   : Initial commit message (default: "initial commit")
# -l <project license>      : Specifies the license to add (default: "mit")t")

