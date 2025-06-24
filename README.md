# Rogue_PM

Rogue_PM is a basic CLI based project manager I made as a hobby to learn Bash scripting. The methods are simple and straightforward, done with the best of my knowledge.

## Features

- Create new project folders
- Use custom templates to create files and folders in the project folder
- Initialize local Git repos and push to GitHub
- Push all changes in all project folders (snapshot feature)
- Add a license automatically from GitHub

## Potential future additions

- Task tracking
- Environment config
- Dependency setup
- Build/run/test automation
- ...i ran out of ideas

## Requirements

- `git`
- `gh` (GitHub CLI)

## Installation

1. Clone the repository:
    ```bash
    git clone https://github.com/rithikrathan/RoguePM.git
    cd RoguePM
2. Make the script executable:
    ```bash
    chmod +x rogue

## Usage

```bash
source rogue <mode> [flags]

#Mode:
# new                       : Creates the project directory based on the given template
# snapshot                       : push changes to github in all of your projects in your project diretory(only if it has a git repo and has changes).

# Flags:
# -t <template name>        : Creates the project directory based on the given template
# -r                        : If a directory with the project name already exists, it will be replaced (existing files will be deleted)
# -v <public/private>       : Sets the GitHub repository's visibility (default: private)
# -m <initial commit msg>   : Initial commit message (default: "initial commit")
# -l <project license>      : Specifies the license to add (default: "mit")
# -d <github description>   : Adds description message to your github repository
# --help                    : Show help message
