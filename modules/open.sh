# ==========================================
# MODULE: OPEN
# ==========================================

accent="#db293f"
bg="#060505"
searchBg="#1c1c1c"
fg="#d0c0c0"

cmd_open() {
    local use_gui="false"
    local open_explorer="false"
    local search_query=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -gt|--gui-term) use_gui="gui-term"; shift ;;
            -ge|--gui-explorer) use_gui="gui-explorer"; shift ;;
            -e|--explorer) open_explorer="true"; shift ;;
            --help|-h)
                echo -e "\n${ROGUE_RED_ITALIC}[Rogue]${RESET} ${BOLD}OPEN COMMAND USAGE${RESET}"
                echo -e "source rogue open [options] [query]\n"
                echo -e "  -gt, --gui-term   Pick project via bemenu, open in $TERMINAL_APP"
                echo -e "  -ge, --gui-explorer Pick project via bemenu, open in $FILE_MANAGER"
                echo -e "  -e, --explorer    Pick project via fzf, open in $FILE_MANAGER"
                echo -e "\n  [query]          Automatically filter to the first directory that matches"
                return 0 ;;
            *) search_query="$1"; shift ;;
        esac
    done

    declare -a fzf_entries
    declare -a proj_paths
    declare -a display_names

    if [ -d "$PROJECTS_DIR" ]; then
        for dir in "$PROJECTS_DIR"/*; do
            if [ -d "$dir" ]; then
                local pname="$(basename "$dir")"
                proj_paths+=("$dir")
                display_names+=("  $pname")
                fzf_entries+=("$pname  |  $dir")
            fi
        done
    fi

    if [ -f "$LOCAL_PROJECTS_LIST" ]; then
        while IFS= read -r line; do
            if [[ "$line" == *"/*" ]]; then
                local base="${line%/\*}"
                [ -d "$base" ] || continue
                for sub in "$base"/*/; do
                    [ -d "$sub" ] && [[ ! " ${proj_paths[*]} " =~ " ${sub} " ]] && local pname="$(basename "$sub")" && proj_paths+=("$sub") && display_names+=("  $pname [Local]") && fzf_entries+=("$pname [Local]  |  $sub")
                done
            else
                [ -d "$line" ] && [[ ! " ${proj_paths[*]} " =~ " ${line} " ]] && local pname="$(basename "$line")" && proj_paths+=("$line") && display_names+=("  $pname [Local]") && fzf_entries+=("$pname [Local]  |  $line")
            fi
        done < "$LOCAL_PROJECTS_LIST"
    fi

    if [ ${#fzf_entries[@]} -eq 0 ]; then
        log_error "No projects found."
        return 1
    fi

    # Align the '|' separator
    local max_width=0
    for entry in "${fzf_entries[@]}"; do
        local name="${entry%  |  *}"
        (( ${#name} > max_width )) && max_width=${#name}
    done

    local padded_entries=()
    for entry in "${fzf_entries[@]}"; do
        local name="${entry%  |  *}"
        local path="${entry#*  |  }"
        padded_entries+=("$(printf "%-*s  |  %s" "$max_width" "$name" "$path")")
    done
    fzf_entries=("${padded_entries[@]}")

    local selected_line
    local selected_idx=""
    if [ "$use_gui" != "false" ]; then
        if ! command -v bemenu &> /dev/null; then log_error "'bemenu' is not installed."; return 1; fi
        local bemenu_args=(
            --nb "$bg" --nf "$fg"
            --tb "$bg" --tf "$accent"
            --fb "$searchBg" --ff "$fg"
            --hb "$accent" --hf "#000000"
            --cb "$accent" --cf "#000000"
            --ab "$bg" --af "$fg"
            --scb "$searchBg" --scf "$accent"
            --bdr "$accent" -B 4 -R 8 -W 0.3 -c
            -p "[rogue] Open:" -s --hp 0 -i
            --fn "JetBrainsMono Nerd Font Medium 20" -H 32 -l 7
        )
        [[ -n "$search_query" ]] && bemenu_args+=(--filter "$search_query")
        selected_line=$(printf "%s\n" "${display_names[@]}" | bemenu "${bemenu_args[@]}")
        if [ -n "$selected_line" ]; then
            for i in "${!display_names[@]}"; do
                if [ "${display_names[$i]}" = "$selected_line" ]; then
                    selected_idx=$i
                    break
                fi
            done
        fi
    else
        if ! command -v fzf &> /dev/null; then log_error "'fzf' is not installed."; return 1; fi
        local fzf_args=(
            --prompt="[Rogue] Open > "
            --height=40%
            --border=rounded
            --color="prompt:#ff2030,info:#40ff20,pointer:#ff2030"
        )

        [[ -n "$search_query" ]] && fzf_args+=(--filter "$search_query")

        selected_line=$(printf "%s\n" "${fzf_entries[@]}" | fzf "${fzf_args[@]}" | head -1)
    fi

    [ -z "$selected_line" ] && return 0

    local target_dir
    if [ "$use_gui" != "false" ] && [ -n "$selected_idx" ]; then
        target_dir="${proj_paths[$selected_idx]}"
    else
        target_dir=$(echo "$selected_line" | awk -F ' \\|  ' '{print $2}')
    fi

    if [ "$use_gui" == "gui-term" ]; then
        command -v "$TERMINAL_APP" &> /dev/null && "$TERMINAL_APP" --working-directory "$target_dir" > /dev/null 2>&1 &
        return 0
    fi

    if [ "$use_gui" == "gui-explorer" ] || [ "$open_explorer" == "true" ]; then
        command -v "$FILE_MANAGER" &> /dev/null && "$FILE_MANAGER" "$target_dir" > /dev/null 2>&1 &
        return 0
    fi

    cd "$target_dir" || return 1
    echo "$target_dir" > /tmp/.rogue_cd
}
