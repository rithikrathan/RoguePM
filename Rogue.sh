#!/bin/bash

# Default values
REPLACE= "false"
PROJECTS_DIR=$(pwd)/
PROJECT_NAME="<Placeholder>"
REPO_VISIBILITY="private"  # Default to private
COMMIT_MSG="Initial commit"

TEMPLATES_DIR="/home/rathanthegreatlol/Desktop/projects/RoguePM/RogueTemplates/"
TEMPLATE="default"

# Parse arguments
while [[ $# -gt 0 ]]; do
	case "$1" in
		new)echo "-------------------------------------------------------------------"
			read -p "[Rogue] Enter project name: " PROJECT_NAME
			echo "-------------------------------------------------------------------"
			shift 
			;;
			
		-r) REPLACE="true"; shift ;;
			
		-v) 
			if [[ "$2" != "public" && "$2" != "private" ]]; then
				echo "[Rogue] Error: Visibility must be 'public' or 'private'."
				return 1
			fi
			REPO_VISIBILITY="$2";
			shift 2
			;;
			
		-t) if [[ -z "$2" ]];then
				echo "[Rogue] Error: Template name cannot be empty."
				return 1
			fi
			
			if [[ -d "$TEMPLATE_DIR/$2" ]];then
				TEMPLATE="$2"; 
				shift 2 
			else
				echo "[Rogue] Error: Template does not exist in the template directory using default template"
				TEMPLATE="$2"
			fi
			;;
			
		-m) if [[ -z "$2" ]];then
				echo "[Rogue] Error: Commit message cannot be empty."
				return 1
			fi
			COMMIT_MSG="$2"; 
			shift 2 ;;
			
		*) echo "Usage: project -n <project_name> [-r {replaces existing directory in this name}] [-v <public|private>] [-m <commit_msg>]"; return 1 ;;
	esac
done

PROJECT_DIR="$PROJECTS_DIR$PROJECT_NAME"
# echo "projectDirectory: $PROJECT_DIR"

# Create project directory:
echo "\n [~~~~~~~~~~~~~~~~~~|Creating project directory|~~~~~~~~~~~~~~~~]"
# Creates a project directory {thats how your comment should be}
if [ -e "$PROJECT_DIR" ];then
	if [ "$REPLACE" == "true" ];then
		echo "[Rogue] Replacing existing directory....."
		rm -rf "$PROJECT_DIR"
		mkdir -p "$PROJECT_DIR"
		echo "[Rogue] Current directory is set to $PROJECT_DIR"
		cd "$PROJECT_DIR" 
	else
		echo "[Rogue] Error: Directory already exists! Try again with -r flag to replace it (will delete existing data)"
		echo "[Rogue] Exiting......"
		return 1
	fi
else
	echo "[Rogue] Creating project directory....."
	mkdir -p "$PROJECT_DIR"
	echo "[Rogue] Current directory is set to $PROJECT_DIR"
	cd "$PROJECT_DIR"
fi

echo "\n [~~~~~~~~~~~~~~~~~|Creating GitHub repository|~~~~~~~~~~~~~~~~~]"
# Check if the GitHub CLI is authenticated
if ! gh auth status &>/dev/null; then
	echo "[Rogue] Error: GitHub CLI is not authenticated or timed out. try running  'gh auth login' first or checking your internet connection."
	echo "[Rogue] Exiting....."
	return 1
fi
# Get GitHub username using GitHub API
GITHUB_USER=$(gh api user --jq .login)
echo "-------------------------------------------------------------------"
echo "[Rogue] GitHub username: $GITHUB_USER"
echo "-------------------------------------------------------------------"
# Initialize Git
git init
gh repo create "$PROJECT_NAME" --"$REPO_VISIBILITY" --source=. --remote=origin
echo "[Rogue] GitHub repository created: https://github.com/$GITHUB_USER/$PROJECT_NAME"

echo "\n [~~~~~~~~~~~~~~~|Creating Basic files and folders|~~~~~~~~~~~~~]"
echo "[Rogue] Using $TEMPLATE template......"
~/Desktop/projects/RoguePM/RogueTemplates/$TEMPLATE/$TEMPLATE.sh -n "$PROJECT_NAME"

echo "\n [~~~~~~~~~~~~~~~~~~~~|Making initial commit|~~~~~~~~~~~~~~~~~~~]"
git add .
git commit -m "$COMMIT_MSG"
echo "\n [~~~~~~~~~~~~~~~~~~~~|Pushing to main branch|~~~~~~~~~~~~~~~~~~]"
git push -u origin main


