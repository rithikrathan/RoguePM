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

# opencode window (shell left 31%, opencode right 69%)
# tmux new-window -t "$SESSION" -n "opencode" -c "/home/rithik/Desktop/projects/RoguePM"
# tmux split-window -h -t "$SESSION:opencode" -p 69 -c "/home/rithik/Desktop/projects/RoguePM"
# tmux send-keys -t "$SESSION:opencode.right" "opencode" C-m

tmux select-window -t "$SESSION:editor"
tmux attach-session -t "$SESSION"
