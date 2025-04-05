#!/bin/bash

DIR_NAME="<placeholder>"
default_folder="default"
template_dir="/home/godz/Desktop/projects/RoguePM/RogueTemplates"  # Change this to your actual template directory

read -p $'Enter the name of the new clone: ' DIR_NAME

new_folder="$template_dir/$DIR_NAME"
cp -r "$template_dir/$default_folder" "$new_folder"
mv "$new_folder/default.sh" "$new_folder/$DIR_NAME.sh"
echo "Created $new_folder with $DIR_NAME.sh"

