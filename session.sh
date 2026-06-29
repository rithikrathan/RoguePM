#!/bin/bash

SESSION="RoguePM"
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
ROGUED_DIR="$BASE_DIR/rogued"
ROGUED_DIR1="$BASE_DIR"

tmux kill-session -t "$SESSION" 2>/dev/null

# editor window (shell first, then start nvim)
tmux new-session -d -s "$SESSION" -n "editor" -c "$ROGUED_DIR"
tmux send-keys -t "$SESSION:editor" "nvim" C-m

# shell window
tmux new-window -t "$SESSION" -n "shell" -c "$ROGUED_DIR"
tmux send-keys -t "$SESSION:shell" "clear" C-m
tmux split-window -h -t "$SESSION:shell" -p 50 -c "$ROGUED_DIR1"
tmux send-keys -t "$SESSION:shell.2" "clear" C-m

# lazygit window
tmux new-window -t "$SESSION" -n "lazygit" -c "$BASE_DIR"
tmux send-keys -t "$SESSION:lazygit" "lazygit" C-m

# spf window
tmux new-window -t "$SESSION" -n "superfile" -c "$BASE_DIR"
tmux send-keys -t "$SESSION:superfile" "spf" C-m

# tmux new-window -t "$SESSION" -n "docs" -c "$BASE_DIR"
# tmux send-keys -t "$SESSION:docs" "rdocs rust" C-m

# opencode window (opencode left 69%, terminal right 31%)
tmux new-window -t "$SESSION" -n "opencode" -c "$BASE_DIR"
tmux send-keys -t "$SESSION:opencode" "opencode" C-m
tmux split-window -h -t "$SESSION:opencode" -p 31 -c "$ROGUED_DIR"
tmux send-keys -t "$SESSION:opencode.2" "clear" C-m

tmux select-window -t "$SESSION:editor"
tmux attach-session -t "$SESSION"
