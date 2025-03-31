#!/bin/bash
# set -x # Enable debugging
FILES_DIR="/home/rathanthegreatlol/Desktop/projects/RoguePM/RogueTemplates/manim/files/"
PROJECT_DIR=$(pwd)/
PROJECT_NAME="placeholder"
LICENSE="mit"
MESSAGE="another placeholder il;aksjfsdjfa;sdlkf jsalkf"

#Parse arguments
while [[ $# -gt 0 ]]; do 
	case "$1" in
		-n) PROJECT_NAME="$2"; shift 2;;
		-l) LICENSE="$2"; shift 2;;
		-m) MESSAGE="$2"; shift 2;;
		*) echo -e "\e[1m[Rogue]\e[0m invalid arguments"; return 1;; # throws when arguments other than the above two is passed
	esac
done

gh api "/licenses/$LICENSE" --jq .body > "$PROJECT_DIR/LICENSE"
echo "[✔] Created LICENSE"

cat <<EOL > "$PROJECT_DIR/README.md"
Project_Name:  "$PROJECT_NAME"
Commit message: "$MESSAGE"


This is automatically generated by RoguePM,
Descriptions for the repository will be updated in the future commits
EOL
echo "[✔] Created README.md"

# Debug stuffs
# echo "Checking directory: $FILES_DIR"
# ls -l "$FILES_DIR"  # List contents for debugging

# Create predefined files and directories
if [ -d "$FILES_DIR" ];then
	for item in "$FILES_DIR"/.* "$FILES_DIR"/*;do
		# echo $item # Debug stuffs
		if [ -f "$item" ];then
			cp "$item" "$PROJECT_DIR/"
			echo "[✔] Created $(basename "$item")" 
		elif [ -d "$item" ];then
			cp -r "$item" "$PROJECT_DIR/"
			echo "[✔] Created $(basename "$item") directory" 
		fi
	done
	shopt -u dotglob
elif [ ! -d "$FILES_DIR" ];then
	echo -e "\e[1m[Rogue]\e[0m Additional files not found, skipping....."
	return 1
else
	echo -e "\e[1m[Rogue]\e[0m yeah something fishy this shouldn't happen"
fi
