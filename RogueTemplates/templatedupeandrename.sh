#!/bin/bash

# List of names
names=("godot2d" "godot3d" "kicad" "logisim" "freecad" "assembly" "bash" "arduino" "java" "rust")

default_folder="default"

template_dir="/home/godz/Desktop/projects/RoguePM/RogueTemplates/"  # Change this to your actual template directory

for name in "${names[@]}"; do
    new_folder="$template_dir/$name"
    cp -r "$template_dir/$default_folder" "$new_folder"
    mv "$new_folder/default.sh" "$new_folder/$name.sh"
    echo "Created $new_folder with $name.sh"
done

