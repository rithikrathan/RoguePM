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
    local target_ws=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -gt|--gui-term) use_gui="gui-term"; shift ;;
            -ge|--gui-explorer) use_gui="gui-explorer"; shift ;;
            -e|--explorer) open_explorer="true"; shift ;;
            -w|--ws|--workspace)
                [ -z "$2" ] || [[ "$2" == -* ]] && { log_error "--ws requires a workspace name"; return 1; }
                target_ws="$2"; shift 2 ;;
            --help|-h)
                echo -e "\n${ROGUE_RED_ITALIC}[Rogue]${RESET} ${BOLD}OPEN COMMAND USAGE${RESET}"
                echo -e "source rogue open [options] [query]\n"
                echo -e "  -gt, --gui-term       Pick project via bemenu, open in $TERMINAL_APP"
                echo -e "  -ge, --gui-explorer   Pick project via bemenu, open in $FILE_MANAGER"
                echo -e "  -e, --explorer        Pick project via fzf, open in $FILE_MANAGER"
                echo -e "  -w, --ws <name>       Directly open sub-picker for a specific workspace"
                echo -e "\n  [query]               Automatically filter by name / substring"
                return 0 ;;
            *) search_query="$1"; shift ;;
        esac
    done

    local json_file="${ROGUE_CONFIG:-$HOME/.config/rogue/rogueConf.json}"
    local list_file="${LOCAL_PROJECTS_LIST:-$HOME/.config/rogue/rp.list}"

    # Load workspaces
    declare -a ws_names=() ws_paths=() ws_hidden=()
    if [ -f "$json_file" ] && command -v jq &>/dev/null; then
        while IFS=$'\t' read -r w_name w_path w_hide; do
            [ -n "$w_name" ] && [ "$w_name" != "null" ] || continue
            ws_names+=("$w_name")
            ws_paths+=("${w_path/#\~/$HOME}")
            ws_hidden+=("$w_hide")
        done < <(jq -r '.workspaces[]? | [ .name, .path, (.hidden // false) ] | @tsv' "$json_file" 2>/dev/null)
    fi

    # Helper function to open directory according to gui flags
    _open_directory() {
        local target_dir="$1"
        [ -z "$target_dir" ] && return 0

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

    # Sub-picker for a specific workspace
    _open_workspace_picker() {
        local chosen_ws="$1"
        local chosen_path=""

        for i in "${!ws_names[@]}"; do
            if [ "${ws_names[$i]}" = "$chosen_ws" ]; then
                chosen_path="${ws_paths[$i]}"
                break
            fi
        done

        if [ -z "$chosen_path" ] && [ -d "$PROJECTS_DIR/$chosen_ws" ]; then
            chosen_path="$PROJECTS_DIR/$chosen_ws"
        fi

        declare -a sub_display_names=() sub_fzf_entries=() sub_paths=()

        # 1. Back option
        sub_paths+=("__BACK__")
        sub_display_names+=("    ..")
        sub_fzf_entries+=("..  |  ..")

        # 2. Workspace root directory
        if [ -d "$chosen_path" ]; then
            sub_paths+=("$chosen_path")
            sub_display_names+=("    .")
            sub_fzf_entries+=(".  |  $chosen_path")
        fi

        # 3. Subdirectories
        if [ -d "$chosen_path" ]; then
            for dir in "$chosen_path"/*/; do
                if [ -d "$dir" ]; then
                    local pname="$(basename "$dir")"
                    sub_paths+=("$dir")
                    sub_display_names+=("  › $pname")
                    sub_fzf_entries+=("$pname  |  $dir")
                fi
            done
        fi

        # 4. Linked local projects
        if [ -f "$list_file" ]; then
            while IFS= read -r line; do
                [ -z "$line" ] && continue
                local l_path="${line%|*}"
                local l_ws="${line#*|}"
                if [ "$l_ws" = "$chosen_ws" ] && [ -d "$l_path" ]; then
                    local pname="$(basename "$l_path")"
                    sub_paths+=("$l_path")
                    sub_display_names+=("  › $pname [linked]")
                    sub_fzf_entries+=("$pname [linked]  |  $l_path")
                fi
            done < "$list_file"
        fi

        # Align FZF separator in sub-picker
        local max_sub_width=0
        for entry in "${sub_fzf_entries[@]}"; do
            local name="${entry%  |  *}"
            (( ${#name} > max_sub_width )) && max_sub_width=${#name}
        done

        local padded_sub_fzf=()
        for entry in "${sub_fzf_entries[@]}"; do
            local name="${entry%  |  *}"
            local path="${entry#*  |  }"
            padded_sub_fzf+=("$(printf "%-*s  |  %s" "$max_sub_width" "$name" "$path")")
        done
        sub_fzf_entries=("${padded_sub_fzf[@]}")

        local selected_sub=""
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
                -p "[rogue] >" -s --hp 0 -i
                --fn "JetBrainsMono Nerd Font Medium 20" -H 32 -l 7
            )
            local ws_lower="${chosen_ws,,}"
            local sq_lower="${search_query,,}"
            if [[ -n "$search_query" && "$sq_lower" != "$ws_lower" && "$ws_lower" != *"$sq_lower"* ]]; then
                bemenu_args+=(--filter "$search_query")
            fi
            local picked
            picked=$(printf "%s\n" "${sub_display_names[@]}" | bemenu "${bemenu_args[@]}")
            [ -z "$picked" ] && return 0
            for i in "${!sub_display_names[@]}"; do
                if [ "${sub_display_names[$i]}" = "$picked" ]; then
                    selected_sub="${sub_paths[$i]}"
                    break
                fi
            done
        else
            if ! command -v fzf &> /dev/null; then log_error "'fzf' is not installed."; return 1; fi
            local fzf_args=(
                --prompt="[rogue] > "
                --height=40%
                --border=rounded
                --color="prompt:#ff2030,info:#40ff20,pointer:#ff2030"
            )
            local ws_lower="${chosen_ws,,}"
            local sq_lower="${search_query,,}"
            if [[ -n "$search_query" && "$sq_lower" != "$ws_lower" && "$ws_lower" != *"$sq_lower"* ]]; then
                fzf_args+=(--filter "$search_query")
            fi
            local picked_line
            picked_line=$(printf "%s\n" "${sub_fzf_entries[@]}" | fzf "${fzf_args[@]}" | head -1)
            [ -z "$picked_line" ] && return 0
            local picked_raw
            picked_raw=$(echo "$picked_line" | awk -F ' \\|  ' '{print $1}' | xargs)
            for i in "${!sub_fzf_entries[@]}"; do
                local plain_name="${sub_fzf_entries[$i]%  |  *}"
                plain_name="$(echo "$plain_name" | xargs)"
                if [ "$plain_name" = "$picked_raw" ]; then
                    selected_sub="${sub_paths[$i]}"
                    break
                fi
            done
        fi

        if [ "$selected_sub" = "__BACK__" ] || [ "$selected_sub" = ".." ]; then
            return 2
        fi

        _open_directory "$selected_sub"
    }

    # Direct target_ws resolution if passed via CLI
    if [ -n "$target_ws" ]; then
        local resolved_ws
        resolved_ws=$(resolve_workspace_name "$target_ws") || return 1
        _open_workspace_picker "$resolved_ws"
        local status=$?
        if [ $status -ne 2 ]; then
            return $status
        fi
    fi

    # Direct match if search_query precisely matches a workspace name
    if [ -n "$search_query" ]; then
        local q_lower="${search_query,,}"
        local matched_ws=""
        for i in "${!ws_names[@]}"; do
            local w_lower="${ws_names[$i],,}"
            if [ "$w_lower" = "$q_lower" ]; then
                matched_ws="${ws_names[$i]}"
                break
            elif [[ "$w_lower" == *"$q_lower"* ]] && [ -z "$matched_ws" ]; then
                matched_ws="${ws_names[$i]}"
            fi
        done

        if [ -n "$matched_ws" ]; then
            _open_workspace_picker "$matched_ws"
            local status=$?
            if [ $status -ne 2 ]; then
                return $status
            fi
            search_query=""
        fi
    fi

    # STEP 1: Top-level navigation loop
    while true; do
        declare -a item_types=() item_keys=() item_paths=() bemenu_entries=() fzf_entries=()

        # 1. Registered Workspaces
        for i in "${!ws_names[@]}"; do
            local w_name="${ws_names[$i]}"
            local w_path="${ws_paths[$i]}"
            item_types+=("workspace")
            item_keys+=("$w_name")
            item_paths+=("$w_path")
            bemenu_entries+=("  [WS] $w_name")
            fzf_entries+=("[WS] $w_name  |  $w_path")
        done

        # 2. Loose projects directly under PROJECTS_DIR (excluding registered workspace directories)
        if [ -d "$PROJECTS_DIR" ]; then
            for dir in "$PROJECTS_DIR"/*; do
                if [ -d "$dir" ]; then
                    local real_d="$(realpath "$dir")"
                    local is_ws=false
                    for wp in "${ws_paths[@]}"; do
                        if [ "$real_d" = "$wp" ]; then
                            is_ws=true
                            break
                        fi
                    done
                    if [ "$is_ws" = false ]; then
                        local pname="$(basename "$dir")"
                        item_types+=("project")
                        item_keys+=("$pname")
                        item_paths+=("$dir")
                        bemenu_entries+=("  $pname")
                        fzf_entries+=("$pname  |  $dir")
                    fi
                fi
            done
        fi

        # 3. If a search query is passed, also include all workspace subprojects
        if [ -n "$search_query" ]; then
            for i in "${!ws_names[@]}"; do
                local w_name="${ws_names[$i]}"
                local w_path="${ws_paths[$i]}"
                if [ -d "$w_path" ]; then
                    for sub in "$w_path"/*/; do
                        if [ -d "$sub" ]; then
                            local pname="$(basename "$sub")"
                            item_types+=("project")
                            item_keys+=("$pname")
                            item_paths+=("$sub")
                            bemenu_entries+=("  › $pname [$w_name]")
                            fzf_entries+=("$pname [$w_name]  |  $sub")
                        fi
                    done
                fi
            done
        fi

        # 4. Orphan local projects from rp.list
        if [ -f "$list_file" ]; then
            while IFS= read -r line; do
                [ -z "$line" ] && continue
                local l_path="${line%|*}"
                local l_ws=""
                [[ "$line" == *"|"* ]] && l_ws="${line#*|}"

                if [ -z "$l_ws" ] || [ "$l_ws" = "$line" ]; then
                    if [ -d "$l_path" ]; then
                        local pname="$(basename "$l_path")"
                        item_types+=("orphan")
                        item_keys+=("$pname")
                        item_paths+=("$l_path")
                        bemenu_entries+=("  [orphan] $pname")
                        fzf_entries+=("$pname [orphan]  |  $l_path")
                    fi
                fi
            done < "$list_file"
        fi

        if [ ${#item_types[@]} -eq 0 ]; then
            log_error "No projects or workspaces found."
            return 1
        fi

        # Align FZF separator
        local max_width=0
        for entry in "${fzf_entries[@]}"; do
            local name="${entry%  |  *}"
            (( ${#name} > max_width )) && max_width=${#name}
        done

        local padded_fzf=()
        for entry in "${fzf_entries[@]}"; do
            local name="${entry%  |  *}"
            local path="${entry#*  |  }"
            padded_fzf+=("$(printf "%-*s  |  %s" "$max_width" "$name" "$path")")
        done
        fzf_entries=("${padded_fzf[@]}")

        local selected_type="" selected_key="" selected_path=""

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
                -p "[rogue] >" -s --hp 0 -i
                --fn "JetBrainsMono Nerd Font Medium 20" -H 32 -l 7
            )
            [[ -n "$search_query" ]] && bemenu_args+=(--filter "$search_query")
            local picked
            picked=$(printf "%s\n" "${bemenu_entries[@]}" | bemenu "${bemenu_args[@]}")
            [ -z "$picked" ] && return 0

            for i in "${!bemenu_entries[@]}"; do
                if [ "${bemenu_entries[$i]}" = "$picked" ]; then
                    selected_type="${item_types[$i]}"
                    selected_key="${item_keys[$i]}"
                    selected_path="${item_paths[$i]}"
                    break
                fi
            done
        else
            if ! command -v fzf &> /dev/null; then log_error "'fzf' is not installed."; return 1; fi
            local fzf_args=(
                --prompt="[rogue] > "
                --height=40%
                --border=rounded
                --color="prompt:#ff2030,info:#40ff20,pointer:#ff2030"
            )
            [[ -n "$search_query" ]] && fzf_args+=(--filter "$search_query")
            local picked_line
            picked_line=$(printf "%s\n" "${fzf_entries[@]}" | fzf "${fzf_args[@]}" | head -1)
            [ -z "$picked_line" ] && return 0

            local picked_raw
            picked_raw=$(echo "$picked_line" | awk -F ' \\|  ' '{print $1}' | xargs)

            for i in "${!fzf_entries[@]}"; do
                local plain_name="${fzf_entries[$i]%  |  *}"
                plain_name="$(echo "$plain_name" | xargs)"
                if [ "$plain_name" = "$picked_raw" ]; then
                    selected_type="${item_types[$i]}"
                    selected_key="${item_keys[$i]}"
                    selected_path="${item_paths[$i]}"
                    break
                fi
            done
        fi

        # Reset search_query after first selection
        search_query=""

        if [ "$selected_type" = "workspace" ]; then
            # STEP 2: Drill down into selected workspace
            _open_workspace_picker "$selected_key"
            local sub_status=$?
            if [ $sub_status -eq 2 ]; then
                # User chose ".." -> loop back to top menu
                continue
            fi
            return $sub_status
        else
            _open_directory "$selected_path"
            return $?
        fi
    done
}
