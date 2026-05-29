# ==========================================
# MODULE: NEW SESSION (session.sh generator)
# ==========================================

cmd_new_session() {
    local prefill_name=""
    local prefill_dir=""

    if [[ $# -ge 2 ]]; then
        prefill_name="$1"
        prefill_dir="$2"
    fi

    log_divider "--- Session Configuration ---"

    local session_name="$prefill_name"
    if [ -z "$session_name" ]; then
        local dir_name
        dir_name=$(basename "$(pwd)")
        log_prompt "Enter session name (default: $dir_name): " session_name
        [ -z "$session_name" ] && session_name="$dir_name"
    fi

    local target_dir="${prefill_dir:-$(pwd)}"
    local session_file="$target_dir/session.sh"

    if [ -f "$session_file" ]; then
        local overwrite_choice
        log_prompt "session.sh exists. Overwrite / Append / Skip (O/a/s): " overwrite_choice
        overwrite_choice=${overwrite_choice:-O}
        if [[ "$overwrite_choice" =~ ^[Ss] ]]; then
            log_info "Skipped."
            return 0
        fi
    fi

    local use_fzf="n"
    local depth=3
    local ignore_dirs="examples,.git,libraries,modes,reference,templates"

    log_prompt "Use fzf to pick a subdirectory at runtime? (y/N): " use_fzf
    use_fzf=${use_fzf:-n}
    if [[ "$use_fzf" =~ ^[Yy]$ ]]; then
        local depth_input
        log_prompt "Search depth (default: 3): " depth_input
        [ -n "$depth_input" ] && depth="$depth_input"
        local ignore_input
        log_prompt "Dirs to ignore (comma-sep, default: examples,.git,...): " ignore_input
        [ -n "$ignore_input" ] && ignore_dirs="$ignore_input"
    fi

    log_divider "--- Window Configuration ---"

    local add_editor="y"
    log_prompt "Add editor window (nvim)? (Y/n): " add_editor
    add_editor=${add_editor:-y}

    local add_shell="y"
    local shell_count=1
    local -a shell_names=()
    local -a shell_cmds=()
    log_prompt "Add shell window? (Y/n): " add_shell
    add_shell=${add_shell:-y}
    if [[ "$add_shell" =~ ^[Yy]$ ]]; then
        local shell_count_input
        log_prompt "How many shell windows? (default: 1): " shell_count_input
        [ -n "$shell_count_input" ] && shell_count="$shell_count_input"
        for ((i=1; i<=shell_count; i++)); do
            local default_name="shell"
            [ "$i" -gt 1 ] && default_name="shell$i"
            local sname
            log_prompt "Name for shell $i (default: $default_name): " sname
            [ -z "$sname" ] && sname="$default_name"
            shell_names+=("$sname")
            local scmd
            log_prompt "Startup command for '$sname' (optional): " scmd
            shell_cmds+=("$scmd")
        done
    fi

    local add_lazygit="y"
    log_prompt "Add lazygit window? (Y/n): " add_lazygit
    add_lazygit=${add_lazygit:-y}

    local add_spf="y"
    log_prompt "Add superfile (spf) window? (Y/n): " add_spf
    add_spf=${add_spf:-y}

    local add_opencode="n"
    log_prompt "Add opencode window (split pane 69/31)? (y/N): " add_opencode
    add_opencode=${add_opencode:-n}

    local add_custom="n"
    local -a custom_names=()
    local -a custom_panes=()
    local -a custom_layouts=()
    local -a custom_cmds=()
    log_prompt "Add a custom window? (y/N): " add_custom
    add_custom=${add_custom:-n}
    if [[ "$add_custom" =~ ^[Yy]$ ]]; then
        while true; do
            local cname
            log_prompt "Custom window name: " cname
            [ -z "$cname" ] && { log_error "Name cannot be empty."; continue; }
            local cpane_input
            log_prompt "Number of panes (default: 1): " cpane_input
            local cpane_count=1
            [ -n "$cpane_input" ] && cpane_count="$cpane_input"
            local clayout
            if [ "$cpane_count" -gt 1 ]; then
                log_prompt "Pane layout (1=horizontal, 2=vertical, 3=tiled) [default: 1]: " clayout
                clayout=${clayout:-1}
                case "$clayout" in
                    1) clayout="horizontal" ;;
                    2) clayout="vertical" ;;
                    3) clayout="tiled" ;;
                    *) clayout="horizontal" ;;
                esac
            else
                clayout="single"
            fi
            local -a pane_cmds=()
            for ((p=1; p<=cpane_count; p++)); do
                local pcmd
                log_prompt "Pane $p command (optional): " pcmd
                pane_cmds+=("$pcmd")
            done
            custom_names+=("$cname")
            custom_panes+=("$cpane_count")
            custom_layouts+=("$clayout")
            custom_cmds+=("$(IFS='|'; echo "${pane_cmds[*]}")")

            local another
            log_prompt "Add another custom window? (y/N): " another
            another=${another:-n}
            [[ ! "$another" =~ ^[Yy]$ ]] && break
        done
    fi

    log_divider "--- Ordering ---"

    local -a order_list=()
    [[ "$add_editor" =~ ^[Yy]$ ]] && order_list+=("editor")
    [[ "$add_shell" =~ ^[Yy]$ ]] && { for s in "${shell_names[@]}"; do order_list+=("shell:$s"); done; }
    [[ "$add_lazygit" =~ ^[Yy]$ ]] && order_list+=("lazygit")
    [[ "$add_spf" =~ ^[Yy]$ ]] && order_list+=("superfile")
    [[ "$add_opencode" =~ ^[Yy]$ ]] && order_list+=("opencode")
    for c in "${custom_names[@]}"; do order_list+=("custom:$c"); done

    if [ ${#order_list[@]} -gt 1 ]; then
        log_info "Current order: ${order_list[*]}"
        local accept_order
        log_prompt "Accept this order? (Y/n): " accept_order
        accept_order=${accept_order:-y}
        if [[ ! "$accept_order" =~ ^[Yy]$ ]]; then
            log_info "Enter the numbers in desired order (1-${#order_list[@]}):"
            for i in "${!order_list[@]}"; do
                local display="${order_list[$i]}"
                display="${display#shell:}"
                display="${display#custom:}"
                echo "  $((i+1)). $display"
            done
            local new_order_input
            log_prompt "Enter new order (e.g. 3 1 2 4): " new_order_input
            local -a indices=($new_order_input)
            if [ ${#indices[@]} -eq ${#order_list[@]} ]; then
                local -a new_order=()
                for idx in "${indices[@]}"; do
                    new_order+=("${order_list[$((idx-1))]}")
                done
                order_list=("${new_order[@]}")
            else
                log_error "Invalid input. Keeping current order."
            fi
        fi
    fi

    log_divider "--- Generating Session Script ---"

    {
        echo '#!/bin/bash'
        echo ''
        echo "SESSION=\"$session_name\""

        if [[ "$use_fzf" =~ ^[Yy]$ ]]; then
            echo 'ROOT_DIR="$(pwd)"'
            echo "DEPTH=$depth"
            IFS=',' read -ra ignore_array <<< "$ignore_dirs"
            echo -n 'IGNORE_DIRS=('
            local first=true
            for d in "${ignore_array[@]}"; do
                d="$(echo "$d" | xargs)"
                $first && echo -n "\"$d\"" || echo -n " \"$d\""
                first=false
            done
            echo ')'
            echo 'PATTERN=$(IFS="|"; echo "${IGNORE_DIRS[*]}")'
            echo 'TARGET_DIR=$(find "$ROOT_DIR" -mindepth 1 -maxdepth $DEPTH -type d \'
            echo '    | grep -Ev "/($PATTERN)(/|$)" \'
            echo '    | fzf)'
            echo ''
            echo '[ -z "$TARGET_DIR" ] && exit 1'
            echo ''
        else
            echo 'TARGET_DIR=.'
            echo ''
        fi

        echo 'tmux kill-session -t "$SESSION" 2>/dev/null'
        echo ''

        local first_window=true
        for item in "${order_list[@]}"; do
            local type="${item%%:*}"
            local name="${item#*:}"

            case "$type" in
                editor)
                    if $first_window; then
                        echo "# editor window"
                        echo 'tmux new-session -d -s "$SESSION" -n "editor" -c "$TARGET_DIR"'
                        echo 'tmux send-keys -t "$SESSION:editor" "nvim" C-m'
                        echo ''
                        first_window=false
                    else
                        echo "# editor window"
                        echo 'tmux new-window -t "$SESSION" -n "editor" -c "$TARGET_DIR"'
                        echo 'tmux send-keys -t "$SESSION:editor" "nvim" C-m'
                        echo ''
                    fi
                    ;;
                shell)
                    if $first_window; then
                        echo "# $name window"
                        echo "tmux new-session -d -s \"\$SESSION\" -n \"$name\" -c \"\$TARGET_DIR\""
                        first_window=false
                    else
                        echo "# $name window"
                        echo "tmux new-window -t \"\$SESSION\" -n \"$name\" -c \"\$TARGET_DIR\""
                    fi
                    echo ''
                    ;;
                lazygit)
                    echo "# lazygit window"
                    if $first_window; then
                        echo 'tmux new-session -d -s "$SESSION" -n "lazygit" -c "$TARGET_DIR"'
                        first_window=false
                    else
                        echo 'tmux new-window -t "$SESSION" -n "lazygit" -c "$TARGET_DIR"'
                    fi
                    echo 'tmux send-keys -t "$SESSION:lazygit" "lazygit" C-m'
                    echo ''
                    ;;
                superfile)
                    echo "# superfile window"
                    if $first_window; then
                        echo 'tmux new-session -d -s "$SESSION" -n "superfile" -c "$TARGET_DIR"'
                        first_window=false
                    else
                        echo 'tmux new-window -t "$SESSION" -n "superfile" -c "$TARGET_DIR"'
                    fi
                    echo 'tmux send-keys -t "$SESSION:superfile" "spf" C-m'
                    echo ''
                    ;;
                opencode)
                    echo "# opencode window (shell left 31%, opencode right 69%)"
                    if $first_window; then
                        echo 'tmux new-session -d -s "$SESSION" -n "opencode" -c "$TARGET_DIR"'
                        first_window=false
                    else
                        echo 'tmux new-window -t "$SESSION" -n "opencode" -c "$TARGET_DIR"'
                    fi
                    echo 'tmux split-window -h -t "$SESSION:opencode" -p 69 -c "$TARGET_DIR"'
                    echo 'tmux send-keys -t "$SESSION:opencode.right" "opencode" C-m'
                    echo ''
                    ;;
                custom)
                    local custom_idx=-1
                    for ci in "${!custom_names[@]}"; do
                        if [ "${custom_names[$ci]}" = "$name" ]; then
                            custom_idx=$ci
                            break
                        fi
                    done
                    if [ "$custom_idx" -ge 0 ]; then
                        local pc=${custom_panes[$custom_idx]}
                        local lay=${custom_layouts[$custom_idx]}
                        echo "# custom: $name ($pc panes, $lay layout)"
                        if $first_window; then
                            echo "tmux new-session -d -s \"\$SESSION\" -n \"$name\" -c \"\$TARGET_DIR\""
                            first_window=false
                        else
                            echo "tmux new-window -t \"\$SESSION\" -n \"$name\" -c \"\$TARGET_DIR\""
                        fi
                        IFS='|' read -ra pane_cmds <<< "${custom_cmds[$custom_idx]}"
                        if [ "$pc" -gt 1 ]; then
                            local split_dir
                            case "$lay" in
                                vertical) split_dir="-v" ;;
                                tiled) split_dir="-v" ;;
                                *) split_dir="-h" ;;
                            esac
                            for ((p=1; p<pc; p++)); do
                                local pct=$((100 / (pc - p + 1)))
                                if [ "$lay" = "tiled" ]; then
                                    if [ $((p % 2)) -eq 1 ]; then
                                        echo "tmux split-window -h -t \"\$SESSION:$name\" -p $((100 - 100/pc)) -c \"\$TARGET_DIR\""
                                    else
                                        echo "tmux split-window -v -t \"\$SESSION:$name\" -p $((100 - 100/pc)) -c \"\$TARGET_DIR\""
                                    fi
                                else
                                    echo "tmux split-window $split_dir -t \"\$SESSION:$name\" -p $pct -c \"\$TARGET_DIR\""
                                fi
                            done
                        fi
                        for ((p=0; p<pc; p++)); do
                            local cmd="${pane_cmds[$p]}"
                            [ -n "$cmd" ] && echo "tmux send-keys -t \"\$SESSION:$name.$((pc - 1 - p))\" \"$cmd\" C-m"
                        done
                        echo ''
                    fi
                    ;;
            esac
        done

        echo "tmux select-window -t \"\$SESSION:editor\""
        echo "tmux attach-session -t \"\$SESSION\""
    } > "$session_file"

    chmod +x "$session_file"
    log_success "Session script created at $session_file"
}
