# ==========================================
# MODULE: SNAPSHOT
# ==========================================

cmd_snapshot() {
    local target_ws=""
    local include_all="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -w|--ws|--workspace)
                [ -z "$2" ] || [[ "$2" == -* ]] && { log_error "--ws requires a workspace name"; return 1; }
                target_ws="$2"; shift 2 ;;
            -a|--all)
                include_all="true"; shift ;;
            --help|-h)
                echo -e "\n${ROGUE_RED_ITALIC}[Rogue]${RESET} ${BOLD}SNAPSHOT COMMAND USAGE${RESET}"
                echo -e "source rogue snapshot [options]\n"
                echo -e "  -w, --ws <name>     Snapshot only projects in a specific workspace"
                echo -e "  -a, --all           Include workspaces marked with skip_snapshot\n"
                return 0 ;;
            *)
                log_error "Unknown option for snapshot: $1"; return 1 ;;
        esac
    done

    # Resolve target_ws if provided
    if [ -n "$target_ws" ]; then
        local resolved_ws
        resolved_ws=$(resolve_workspace_name "$target_ws") || return 1
        target_ws="$resolved_ws"
    fi

    echo -e "\n────────────────────────────────────────────"
    echo -e "${ROGUE_RED_ITALIC}[Rogue]${RESET} ${BOLD_ITALIC_UNDERLINE}Running Project Snapshots${RESET}\n"

    local json_file="${ROGUE_CONFIG:-$HOME/.config/rogue/rogueConf.json}"
    local list_file="${LOCAL_PROJECTS_LIST:-$HOME/.config/rogue/rp.list}"

    declare -a ws_names=() ws_paths=() ws_skips=()
    if [ -f "$json_file" ] && command -v jq &>/dev/null; then
        while IFS=$'\t' read -r w_name w_path w_skip; do
            [ -n "$w_name" ] && [ "$w_name" != "null" ] || continue
            ws_names+=("$w_name")
            ws_paths+=("${w_path/#\~/$HOME}")
            ws_skips+=("$w_skip")
        done < <(jq -r '.workspaces[]? | [ .name, .path, (.skip_snapshot // false) ] | @tsv' "$json_file" 2>/dev/null)
    fi

    declare -a target_dirs=()

    if [ -n "$target_ws" ]; then
        local found_path=""
        for i in "${!ws_names[@]}"; do
            if [ "${ws_names[$i]}" = "$target_ws" ]; then
                found_path="${ws_paths[$i]}"
                break
            fi
        done
        [ -z "$found_path" ] && [ -d "$PROJECTS_DIR/$target_ws" ] && found_path="$PROJECTS_DIR/$target_ws"

        if [ -d "$found_path" ]; then
            for d in "$found_path"/*/; do
                [ -d "$d" ] && target_dirs+=("$d")
            done
        fi
        if [ -f "$list_file" ]; then
            while IFS= read -r line; do
                [ -z "$line" ] && continue
                local l_path="${line%|*}"
                local l_ws="${line#*|}"
                if [ "$l_ws" = "$target_ws" ] && [ -d "$l_path" ]; then
                    target_dirs+=("$l_path")
                fi
            done < "$list_file"
        fi
    else
        # 1. Registered active workspaces
        for i in "${!ws_names[@]}"; do
            local w_name="${ws_names[$i]}"
            local w_path="${ws_paths[$i]}"
            local w_skip="${ws_skips[$i]}"

            if [ "$w_skip" = "true" ] && [ "$include_all" != "true" ]; then
                continue
            fi

            if [ -d "$w_path" ]; then
                for d in "$w_path"/*/; do
                    [ -d "$d" ] && target_dirs+=("$d")
                done
            fi

            if [ -f "$list_file" ]; then
                while IFS= read -r line; do
                    [ -z "$line" ] && continue
                    local l_path="${line%|*}"
                    local l_ws="${line#*|}"
                    if [ "$l_ws" = "$w_name" ] && [ -d "$l_path" ]; then
                        target_dirs+=("$l_path")
                    fi
                done < "$list_file"
            fi
        done

        # 2. Root default projects
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
                    [ "$is_ws" = false ] && target_dirs+=("$dir")
                fi
            done
        fi

        # 3. Orphan projects from rp.list
        if [ -f "$list_file" ]; then
            while IFS= read -r line; do
                [ -z "$line" ] && continue
                local l_path="${line%|*}"
                local l_ws=""
                [[ "$line" == *"|"* ]] && l_ws="${line#*|}"
                if [ -z "$l_ws" ] || [ "$l_ws" = "$line" ]; then
                    [ -d "$l_path" ] && target_dirs+=("$l_path")
                fi
            done < "$list_file"
        fi
    fi

    if [ ${#target_dirs[@]} -eq 0 ]; then
        log_info "No projects found to snapshot."
        return 0
    fi

    declare -a report_repos=() report_statuses=()

    for dir in "${target_dirs[@]}"; do
        local dirBaseName=$(basename "$dir")
        log_step "Target: $dirBaseName"

        if [ -d "$dir/.git" ]; then
            cd "$dir" || continue

            if ! git diff --quiet || ! git diff --cached --quiet; then
                log_step "Committing changes..."
                git add -A
                git commit -m "RoguePM: Project snapshot"

                local remotes=$(git remote)
                if [ -z "$remotes" ]; then
                    log_step "No cloud remotes configured. Changes committed locally."
                    report_repos+=("$dirBaseName")
                    report_statuses+=("${GREEN}Committed locally${RESET}")
                    continue
                fi

                local push_failed=false
                for r in $remotes; do
                    log_step "Pushing to $r..."
                    if ! git push "$r" master 2>/dev/null && ! git push "$r" main 2>/dev/null; then
                        push_failed=true
                        log_error "Push failed for remote: $r"
                    fi
                done

                if [ "$push_failed" = true ]; then
                    report_repos+=("$dirBaseName")
                    report_statuses+=("${ROGUE_RED_ITALIC}Push Error/Conflict${RESET}")
                else
                    report_repos+=("$dirBaseName")
                    report_statuses+=("${GREEN}Pushed Successfully${RESET}")
                fi
            else
                log_step "No changes, up to date. Skipping..."
                report_repos+=("$dirBaseName")
                report_statuses+=("${YELLOW}Up to date${RESET}")
            fi
        else
            log_step "Not a git repository. Skipping..."
            report_repos+=("$dirBaseName")
            report_statuses+=("${YELLOW}Not a git repo${RESET}")
        fi
    done

    echo ""
    echo -e "────────────────────────────────────────────"
    echo -e "${ROGUE_RED_ITALIC}[Rogue]${RESET} ${BOLD_ITALIC_UNDERLINE}Snapshot Summary Report${RESET}\n"
    printf "  %-25s | %s\n" "Repository" "Status"
    printf "  %.0s-" {1..55}
    echo ""
    for i in "${!report_repos[@]}"; do
        printf "  %-25s | %b\n" "${report_repos[$i]}" "${report_statuses[$i]}"
    done
    echo ""
}
