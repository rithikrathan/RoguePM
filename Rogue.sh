#!/bin/bash

# Default values
REPLACE= "false"
PROJECTS_DIR=~/Desktop/projects/
PROJECT_NAME="<Placeholder>"
REPO_VISIBILITY="private"  # Default to private
COMMIT_MSG="Initial commit"

# Parse arguments
while [[ $# -gt 0 ]]; do
	case "$1" in
		-n) PROJECT_NAME="$2"; shift 2 ;;
		-r) REPLACE="true"; shift ;;
		-v) 
			if [[ "$2" != "public" && "$2" != "private" ]]; then
				echo "Error: Visibility must be 'public' or 'private'."
				exit 1
			fi
			REPO_VISIBILITY="$2"
			shift 2
			;;
		-m) COMMIT_MSG="$2"; shift 2 ;;
		*) echo "Usage: project -n <project_name> [-d <custom_directory>] [-v <public|private>] [-m <commit_msg>]"; exit 1 ;;
	esac
done

# Check if project name is provided
if [ -z "$PROJECT_NAME" ]; then
	echo "Error: Project name is required."
	exit 1
fi

# Create project directory:
if [ -e "$PROJECTS_DIR$PROJECT_NAME" ];then
	if [ "$REPLACE" == "true" ];then
		echo "Replacing existing directory....."
		rm -rf "$PROJECTS_DIR$PROJECT_NAME"
		mkdir -p "$PROJECTS_DIR$PROJECT_NAME"
		echo "Current directory is set to $PROJECTS_DIR$PROJECT_NAME......"
		cd "$PROJECTS_DIR$PROJECT_NAME" 
	else
		echo "Directory already exists! Try again with -r flag to replace it"
		echo "Exiting......"
		exit 1
	fi
else
	echo "Creating project directory...."
	mkdir -p "$PROJECTS_DIR$PROJECT_NAME"
	echo "Current directory is set to $PROJECTS_DIR$PROJECT_NAME......"
	cd "$PROJECTS_DIR$PROJECT_NAME"
fi

# Check if the GitHub CLI is authenticated
if ! gh auth status &>/dev/null; then
	echo "Error: GitHub CLI is not authenticated. Run 'gh auth login' first."
	echo "Exiting....."
	exit 1
fi

# Get GitHub token from gh CLI
GITHUB_TOKEN=$(gh auth token) 
echo "PersonalAccessToken: $GITHUB_TOKEN"

# Get GitHub username using GitHub API
GITHUB_USER=$(gh api user --jq .login)
echo "UserName: $GITHUB_USER"

# # Initialize Git
git init

# # Create default project files
# echo "# $PROJECT_NAME" > README.md

# # Basic .gitignore
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

# # Generate license
# gh api "/licenses/mit" --jq .body > LICENSE

# # Create GitHub repository using gh CLI
# gh repo create "$PROJECT_NAME" --"$REPO_VISIBILITY" --source=. --remote=origin

# # Add and push files
# git add .
# git commit -m "$COMMIT_MSG"
# git push -u origin main

# echo "GitHub repository created: https://github.com/$GITHUB_USER/$PROJECT_NAME"

