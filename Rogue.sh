#!/bin/bash

# Default values
REPLACE= "false"
PROJECTS_DIR=$(pwd)/
PROJECT_NAME="<Placeholder>"
REPO_VISIBILITY="private"  # Default to private
COMMIT_MSG="Initial commit"
LICENSE="mit"
TEMPLATES_DIR="/home/rathanthegreatlol/Desktop/projects/RoguePM/RogueTemplates/"
TEMPLATE="default"

# Parse arguments
while [[ $# -gt 0 ]]; do
	case "$1" in
		new)read -p $'\e[1m[Rogue]\e[0m Enter project name: ' PROJECT_NAME
			shift 
			;;
			
		-r) REPLACE="true"; shift ;;
			
		-v) 
			if [[ "$2" != "public" && "$2" != "private" ]]; then
				echo -e "\e[1m[Rogue]\e[0m Error: Visibility must be 'public' or 'private'."
				echo -e "\e[1m[Rogue]\e[0m Exiting......"
				return 1
			fi
			REPO_VISIBILITY="$2";
			shift 2
			;;
			
		-t) if [[ -z "$2" ]];then
				echo -e "\e[1m[Rogue]\e[0m Error: Template name cannot be empty."
				echo -e "\e[1m[Rogue]\e[0m Exiting......"
				return 1
			fi
			
			if [[ -d "$TEMPLATE_DIR/$2" ]];then
				TEMPLATE="$2"; 
			else
				echo -e "\e[1m[Rogue]\e[0m Error: Template does not exist in the template directory using default template"
				TEMPLATE="default"
			fi
			shift 2 
			;;
			
		-m) if [[ -z "$2" ]];then
				echo -e "\e[1m[Rogue]\e[0m Error: Commit message cannot be empty."
				echo -e "\e[1m[Rogue]\e[0m Exiting......"
				return 1
			fi
			COMMIT_MSG="$2"; 
			shift 2 ;;
			
		-l) if [[ -z "$2" ]];then
				echo -e "\e[1m[Rogue]\e[0m Error: License not specified."
				echo -e "\e[1m[Rogue]\e[0m Using MIT license....."
				LICENSE="mit"
			else
				LICENSE="$2"; 
			fi
			
			shift 2 ;;
		*) echo "Usage: project -n <project_name> [-r {replaces existing directory in this name}] [-v <public|private>] [-m <commit_msg>]"; return 1 ;;
	esac
done

PROJECT_DIR="$PROJECTS_DIR$PROJECT_NAME"
# echo "projectDirectory: $PROJECT_DIR"

# Create project directory:
echo -e "\n[~~~~~~~~~~~~~~~~~~|Creating project directory|~~~~~~~~~~~~~~~~]"
# Creates a project directory {thats how your comment should be}
if [ -e "$PROJECT_DIR" ];then
	if [ "$REPLACE" == "true" ];then
		echo -e "\e[1m[Rogue]\e[0m Replacing existing directory....."
		rm -rf "$PROJECT_DIR"
		mkdir -p "$PROJECT_DIR"
		echo -e "\e[1m[Rogue]\e[0m Current directory is set to $PROJECT_DIR"
		cd "$PROJECT_DIR" 
	else
		echo -e "\e[1m[Rogue]\e[0m Error: Directory already exists! Try again with -r flag to replace it (will delete existing data)"
		echo -e "\e[1m[Rogue]\e[0m Exiting......"
		return 1
	fi
else
	echo -e "\e[1m[Rogue]\e[0m Creating project directory....."
	mkdir -p "$PROJECT_DIR"
	echo -e "\e[1m[Rogue]\e[0m Current directory is set to $PROJECT_DIR"
	cd "$PROJECT_DIR"
fi

echo -e "\n[~~~~~~~~~~~~~~~~~|Creating GitHub repository|~~~~~~~~~~~~~~~~~]"
# Check if the GitHub CLI is authenticated
if ! gh auth status &>/dev/null; then
	echo -e "\e[1m[Rogue]\e[0m Error: GitHub CLI is not authenticated or timed out. try running  'gh auth login' first or checking your internet connection."
	echo -e "\e[1m[Rogue]\e[0m Exiting....."
	return 1
fi
# Get GitHub username using GitHub API
GITHUB_USER=$(gh api user --jq .login)
echo -e "\e[1m[Rogue]\e[0m GitHub username: $GITHUB_USER \n"

# Initialize Git
git init
gh repo create "$PROJECT_NAME" --"$REPO_VISIBILITY" --source=. --remote=origin
echo -e "\e[1m[Rogue]\e[0m GitHub repository created: https://github.com/$GITHUB_USER/$PROJECT_NAME"

echo -e "\n[~~~~~~~~~~~~~~~|Creating Basic files and folders|~~~~~~~~~~~~~]"
# runs the template script to setup the files
echo -e "\e[1m[Rogue]\e[0m Using $TEMPLATE template......"
~/Desktop/projects/RoguePM/RogueTemplates/$TEMPLATE/$TEMPLATE.sh -n "$PROJECT_NAME" -l "$LICENSE" -m "$COMMIT_MSG"


echo -e "\n[~~~~~~~~~~~~~~~~~~~~|Making initial commit|~~~~~~~~~~~~~~~~~~~]"
git add .
git commit -m "$COMMIT_MSG"
echo -e "\n[~~~~~~~~~~~~~~~~~~~~|Pushing to main branch|~~~~~~~~~~~~~~~~~~]"
git push -u origin main
echo -e "\n\e[1m[Rogue]\e[0m Exiting......"
