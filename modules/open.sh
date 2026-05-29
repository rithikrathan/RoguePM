# ==========================================
# MODULE: OPEN
# ==========================================

cmd_open() {
    local run_session="false"
    local use_gui="false"
    local open_term="false"
    local open_explorer="false"
    local search_query=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t|--terminal) run_session="true"; shift ;;
            -g|--gui) use_gui="true"; shift ;;
            --term) open_term="true"; shift ;;
            --explorer) open_explorer="true"; shift ;;
            --help|-h)
                echo -e "\n${ROGUE_RED_ITALIC}[Rogue]${RESET} ${BOLD}OPEN COMMAND USAGE${RESET}"
                echo -e "source rogue open [options] [query]\n"
                echo -e "  -t, --terminal     Run session.sh"
                echo -e "  -g, --gui          Use rofi instead of fzf"
                echo -e "  --term             Open project in $TERMINAL_APP"
                echo -e "  --explorer         Open project in $FILE_MANAGER"
                echo -e "\n  [query]            Pre-fill search with this text"
                return 0 ;;
            *) search_query="$1"; shift ;;
        esac
    done

    declare -a fzf_entries
    declare -a proj_paths

    if [ -d "$PROJECTS_DIR" ]; then
        for dir in "$PROJECTS_DIR"/*; do
            if [ -d "$dir" ]; then
                proj_paths+=("$dir")
                fzf_entries+=("$(basename "$dir")  |  $dir")
            fi
        done
    fi

    if [ -f "$LOCAL_PROJECTS_LIST" ]; then
        while IFS= read -r dir; do
            if [ -d "$dir" ]; then
                if [[ ! " ${proj_paths[*]} " =~ " ${dir} " ]]; then
                    proj_paths+=("$dir")
                    fzf_entries+=("$(basename "$dir") [Local]  |  $dir")
                fi
            fi
        done < "$LOCAL_PROJECTS_LIST"
    fi

    if [ ${#fzf_entries[@]} -eq 0 ]; then
        log_error "No projects found."
        return 1
    fi

    local selected_line
    if [ "$use_gui" == "true" ]; then
        if ! command -v rofi &> /dev/null; then log_error "'rofi' is not installed."; return 1; fi
        selected_line=$(printf "%s\n" "${fzf_entries[@]}" | rofi -dmenu -i -p "Rogue Open" ${search_query:+-filter "$search_query"})
    else
        if ! command -v fzf &> /dev/null; then log_error "'fzf' is not installed."; return 1; fi
        selected_line=$(printf "%s\n" "${fzf_entries[@]}" | fzf --prompt="[Rogue] Open > " --height=40% --border=rounded --color="prompt:#ff2030,info:#40ff20,pointer:#ff2030" ${search_query:+--query "$search_query"})
    fi

    [ -z "$selected_line" ] && return 0

    local target_dir=$(echo "$selected_line" | awk -F ' \\|  ' '{print $2}')

    if [ "$open_explorer" == "true" ]; then
        command -v "$FILE_MANAGER" &> /dev/null && "$FILE_MANAGER" "$target_dir" > /dev/null 2>&1 &
    fi

    if [ "$open_term" == "true" ]; then
        command -v "$TERMINAL_APP" &> /dev/null && "$TERMINAL_APP" --working-directory "$target_dir" > /dev/null 2>&1 &
    fi

    if [ "$run_session" == "true" ]; then
        if [ -f "$target_dir/session.sh" ]; then
            log_step "Executing session.sh..."
            cd "$target_dir" || return 1
            echo "$target_dir" > /tmp/.rogue_cd
            chmod +x ./session.sh
            ./session.sh
            return 0
        fi
    else
        cd "$target_dir" || return 1
        echo "$target_dir" > /tmp/.rogue_cd
    fi
}
