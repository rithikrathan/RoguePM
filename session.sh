#!/bin/bash

SESSION="RoguePM"

tmux kill-session -t "$SESSION" 2>/dev/null

# editor window (shell first, then start nvim)
tmux new-session -d -s "$SESSION" -n "editor" -c "/home/rithik/Desktop/projects/RoguePM"
tmux send-keys -t "$SESSION:editor" "nvim" C-m

# shell window
tmux new-window -t "$SESSION" -n "shell" -c "/home/rithik/Desktop/projects/RoguePM"

# lazygit window
tmux new-window -t "$SESSION" -n "lazygit" -c "/home/rithik/Desktop/projects/RoguePM"
tmux send-keys -t "$SESSION:lazygit" "lazygit" C-m

# spf window
tmux new-window -t "$SESSION" -n "superfile" -c "/home/rithik/Desktop/projects/RoguePM"
tmux send-keys -t "$SESSION:superfile" "spf" C-m

# opencode window (opencode left 69%, terminal right 31%)
tmux new-window -t "$SESSION" -n "opencode" -c "/home/rithik/Desktop/projects/RoguePM"
tmux send-keys -t "$SESSION:opencode" "opencode" C-m
tmux split-window -h -t "$SESSION:opencode" -p 31 -c "/home/rithik/Desktop/projects/RoguePM"

tmux select-window -t "$SESSION:editor"
tmux attach-session -t "$SESSION"
