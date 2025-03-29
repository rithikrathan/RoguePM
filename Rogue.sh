#!/bin/bash

# Default values
REPLACE= "false"
PROJECTS_DIR=$(pwd)/
PROJECT_NAME="<Placeholder>"
REPO_VISIBILITY="private"  # Default to private
COMMIT_MSG="Initial commit"

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
		-m) COMMIT_MSG="$2"; shift 2 ;;
		*) echo "Usage: project -n <project_name> [-r {replaces existing directory in this name}] [-v <public|private>] [-m <commit_msg>]"; exit 1 ;;
	esac
done

# Create project directory:
echo "---------- Creating project directory ----------"
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

echo "---------- Creating GitHub repository ----------"
# Check if the GitHub CLI is authenticated
if ! gh auth status &>/dev/null; then
	echo "Error: GitHub CLI is not authenticated or timed out. Run 'gh auth login' first."
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
# Create default project files
echo "# $PROJECT_NAME" > README.md
echo ✔ Created README.md
# Basic .gitignore
cat <<EOL > .gitignore
# Compiled files
*.out
*.o
*.exe

# Logs
*.log

# IDE / Editor files
.vscode/
.idea/
*.swp

# Python
__pycache__/
*.pyc

# Node.js
node_modules/
EOL
echo ✔ Created .gitignore

# Generate license
gh api "/licenses/mit" --jq .body > LICENSE
echo ✔ Created LICENSE

echo "---------- Making initial commit ----------"
# Add and push files
git add .
git commit -m "$COMMIT_MSG"
echo "----------  Pushing to main branch ----------"
git push -u origin main


