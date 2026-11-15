#!/bin/bash

SESSION="RoguePM"
TARGET_DIR="$(pwd)"

tmux kill-session -t "$SESSION" 2>/dev/null

# editor window
tmux new-session -d -s "$SESSION" -n "editor" -c "$TARGET_DIR"
tmux send-keys -t "$SESSION:editor" "nvim" C-m

# shell window
tmux new-window -t "$SESSION" -n "shell" -c "$TARGET_DIR"

# agent window
tmux new-window -t "$SESSION" -n "agent" -c "$TARGET_DIR"
tmux send-keys -t "$SESSION:agent" "voicy target here && sleep 2 && agy --dangerously-skip-permissions" C-m

# lazygit window
tmux new-window -t "$SESSION" -n "lazygit" -c "$TARGET_DIR"
tmux send-keys -t "$SESSION:lazygit" "lazygit" C-m

tmux select-window -t "$SESSION:editor"
tmux attach-session -t "$SESSION"
