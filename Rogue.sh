#!/bin/bash

# Default values
REPLACE= "false"
PROJECTS_DIR=$(pwd)/
PROJECT_NAME="<Placeholder>"
REPO_VISIBILITY="private"  # Default to private
COMMIT_MSG="Initial commit"

TEMPLATES_DIR="RogueTemplates/"
TEMPLATE="default"

# Parse arguments
while [[ $# -gt 0 ]]; do
	case "$1" in
		-n) read -p "[Rogue] Enter project name: " PROJECT_NAME
			shift 
			;;

		-r) REPLACE="true"; shift ;;
		-v) 
			if [[ "$2" != "public" && "$2" != "private" ]]; then
				echo "Error: Visibility must be 'public' or 'private'."
				exit 1
			fi
			REPO_VISIBILITY="$2"
			shift 2
			;;
		-t) TEMPLATE="$2"; shift 2 ;;
		-m) COMMIT_MSG="$2"; shift 2 ;;
		*) echo "Usage: project -n <project_name> [-r {replaces existing directory in this name}] [-v <public|private>] [-m <commit_msg>]"; exit 1 ;;
	esac
done

PROJECT_DIR="$PROJECTS_DIR$PROJECT_NAME"
# echo "projectDirectory: $PROJECT_DIR"

# Create project directory:
echo "---------- Creating project directory ----------"
if [ -e "$PROJECT_DIR" ];then
	if [ "$REPLACE" == "true" ];then
		echo "Replacing existing directory....."
		rm -rf "$PROJECT_DIR"
		mkdir -p "$PROJECT_DIR"
		echo "Current directory is set to $PROJECT_DIR......"
		cd "$PROJECT_DIR" 
	else
		echo "Directory already exists! Try again with -r flag to replace it (will delete existing data)"
		echo "Exiting......"
		exit 1
	fi
else
	echo "Creating project directory...."
	mkdir -p "$PROJECT_DIR"
	echo "Current directory is set to $PROJECT_DIR......"
	cd "$PROJECT_DIR"
fi

echo "---------- Creating GitHub repository ----------"
# Check if the GitHub CLI is authenticated
if ! gh auth status &>/dev/null; then
	echo "Error: GitHub CLI is not authenticated or timed out. try running  'gh auth login' first or checking your internet connection."
	echo "Exiting....."
	exit 1
fi

# Get GitHub username using GitHub API
GITHUB_USER=$(gh api user --jq .login)
echo "GitHub username: $GITHUB_USER"

# Initialize Git
git init
gh repo create "$PROJECT_NAME" --"$REPO_VISIBILITY" --source=. --remote=origin
echo "GitHub repository created: https://github.com/$GITHUB_USER/$PROJECT_NAME"

echo "---------- Creating basic files ----------"
echo "Using $TEMPLATE template......"

. "~/Desktop/projects/RougePM/RogueTemplates/$TEMPLATE/$TEMPLATE.sh -n "$PROJECT_NAME""

# basic files
# echo "# $PROJECT_NAME" > README.md
# echo ✔ Created README.md

# cat <<EOL > .gitignore
# # Compiled files
# *.out
# *.o
# *.exe

# # Logs
# *.log

# # IDE / Editor files
# .vscode/
# .idea/
# *.swp

# # Python
# __pycache__/
# *.pyc

# # Node.js
# node_modules/
# EOL
# echo ✔ Created .gitignore

# gh api "/licenses/mit" --jq .body > LICENSE
# echo ✔ Created LICENSE

echo "---------- Making initial commit ----------"
git add .
git commit -m "$COMMIT_MSG"
echo "----------  Pushing to main branch ----------"
git push -u origin main


