#!/bin/bash

SESSION="RoguePM"

tmux kill-session -t $SESSION 2>/dev/null

# editor window (shell first, then start nvim)
tmux new-session -d -s $SESSION -n "editor" -c "/home/rithik/Desktop/projects/RoguePM"
tmux send-keys -t $SESSION:editor "nvim" C-m

# shell window
tmux new-window -t $SESSION -n "shell" -c "/home/rithik/Desktop/projects/RoguePM"

tmux select-window -t $SESSION:editor
tmux attach-session -t $SESSION
