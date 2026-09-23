# ==========================================
# MODULE: WORKSPACE (ws)
# ==========================================

get_config_file() {
    echo "$HOME/.config/rogue/rogueConf.json"
}

get_workspaces_json() {
    local json_file="$(get_config_file)"
    if [ -f "$json_file" ] && command -v jq &>/dev/null; then
        jq -r '.workspaces // []' "$json_file" 2>/dev/null
    else
        echo "[]"
    fi
}

cmd_ws() {
    local sub="$1"
    [ $# -gt 0 ] && shift

    case "$sub" in
        add)
            cmd_ws_add "$@"
            ;;
        remove|rm)
            cmd_ws_remove "$@"
            ;;
        list|ls|"")
            cmd_ws_list "$@"
            ;;
        link)
            cmd_ws_link "$@"
            ;;
        unlink)
            cmd_ws_unlink "$@"
            ;;
        sync|clone)
            cmd_ws_sync "$@"
            ;;
        --help|-h)
            echo -e "\n${ROGUE_RED_ITALIC}[Rogue]${RESET} ${BOLD}WORKSPACE COMMAND USAGE${RESET}"
            echo -e "source rogue ws [action] [options]\n"
            echo -e "  ${BOLD}add <name>${RESET}               Register a new workspace / organization folder"
            echo -e "    --path <path>           Path to workspace folder (defaults to \$PROJECTS_DIR/<name>)"
            echo -e "    --org <gh_org>          GitHub organization name associated with this workspace"
            echo -e "    --email <email>         Git author email for projects in this workspace"
            echo -e "    --skip-snapshot         Skip this workspace during bulk snapshots"
            echo -e "    --hidden                Hide from default list and top-level open view\n"
            echo -e "  ${BOLD}list${RESET}                     List all registered workspaces"
            echo -e "  ${BOLD}remove <name>${RESET}            Unregister a workspace (does not delete files)\n"
            echo -e "  ${BOLD}link <dir>${RESET}               Link an external directory as a local project"
            echo -e "    --ws <name>             Associate directory with a workspace (or orphan if omitted)\n"
            echo -e "  ${BOLD}unlink <dir>${RESET}             Unlink an external local project"
            echo -e "  ${BOLD}clone, sync <name>${RESET}       Clone all missing repositories from the GitHub org"
            return 0
            ;;
        *)
            log_error "Unknown workspace action: $sub"
            echo -e "  Run ${BOLD}source rogue ws --help${RESET} for usage."
            return 1
            ;;
    esac
}

cmd_ws_add() {
    local name=""
    local ws_path=""
    local gh_org=""
    local git_email=""
    local skip_snapshot="false"
    local hidden="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path|-p)
                [ -z "$2" ] || [[ "$2" == -* ]] && { log_error "--path requires a directory path"; return 1; }
                ws_path="$2"; shift 2 ;;
            --org|-o)
                [ -z "$2" ] || [[ "$2" == -* ]] && { log_error "--org requires a GitHub org name"; return 1; }
                gh_org="$2"; shift 2 ;;
            --email|-e)
                [ -z "$2" ] || [[ "$2" == -* ]] && { log_error "--email requires an email address"; return 1; }
                git_email="$2"; shift 2 ;;
            --skip-snapshot)
                skip_snapshot="true"; shift ;;
            --hidden)
                hidden="true"; shift ;;
            --help|-h)
                echo -e "\n${ROGUE_RED_ITALIC}[Rogue]${RESET} ${BOLD}WORKSPACE ADD USAGE${RESET}"
                echo -e "source rogue ws add <name> [options]\n"
                echo -e "  --path <path>       Directory path"
                echo -e "  --org <gh_org>      GitHub organization"
                echo -e "  --email <email>     Git author email"
                echo -e "  --skip-snapshot     Exclude from rogue snapshot"
                echo -e "  --hidden            Hide from default list/open"
                return 0 ;;
            *)
                if [ -z "$name" ] && [[ "$1" != -* ]]; then
                    name="$1"
                else
                    log_error "Invalid argument for 'ws add': $1"; return 1
                fi
                shift ;;
        esac
    done

    if [ -z "$name" ]; then
        log_prompt "Enter workspace name: " name
        [ -z "$name" ] && { log_error "Workspace name cannot be empty."; return 1; }
    fi

    if [ -z "$ws_path" ]; then
        local default_path="$PROJECTS_DIR/$name"
        log_prompt "Enter workspace path (default: $default_path): " ws_path
        ws_path="${ws_path:-$default_path}"
    fi

    # Expand tilde in path
    ws_path="${ws_path/#\~/$HOME}"
    ws_path="$(realpath -m "$ws_path")"

    local json_file="$(get_config_file)"
    if [ ! -f "$json_file" ]; then
        mkdir -p "$(dirname "$json_file")"
        echo '{"workspaces":[]}' > "$json_file"
    fi

    if ! command -v jq &>/dev/null; then
        log_error "jq is required for workspace configuration."
        return 1
    fi

    # Check if workspace already exists
    local exists
    exists=$(jq --arg name "$name" '.workspaces[]? | select(.name == $name) | .name' "$json_file" 2>/dev/null)
    if [ -n "$exists" ]; then
        log_error "Workspace '$name' is already registered."
        return 1
    fi

    # Create folder if it doesn't exist
    if [ ! -d "$ws_path" ]; then
        local create_dir
        log_prompt "Directory '$ws_path' does not exist. Create it? (Y/n): " create_dir
        create_dir=${create_dir:-y}
        if [[ "$create_dir" =~ ^[Yy]$ ]]; then
            mkdir -p "$ws_path"
            log_step "Created directory: $ws_path"
        fi
    fi

    local new_entry
    new_entry=$(jq -n \
        --arg name "$name" \
        --arg path "$ws_path" \
        --arg gh_org "$gh_org" \
        --arg git_email "$git_email" \
        --argjson skip "$skip_snapshot" \
        --argjson hidden "$hidden" \
        '{
            name: $name,
            path: $path,
            gh_org: (if $gh_org == "" then null else $gh_org end),
            git_user_email: (if $git_email == "" then null else $git_email end),
            skip_snapshot: $skip,
            hidden: $hidden
        }')

    local updated_json
    updated_json=$(jq --argjson entry "$new_entry" '.workspaces = (.workspaces // []) + [$entry]' "$json_file")
    echo "$updated_json" > "$json_file"

    log_success "Registered workspace: ${BOLD}$name${RESET} -> $ws_path"
    [ -n "$gh_org" ] && log_step "GitHub Org: $gh_org"
    [ -n "$git_email" ] && log_step "Git Email: $git_email"
}

cmd_ws_list() {
    local json_file="$(get_config_file)"
    if [ ! -f "$json_file" ] || ! command -v jq &>/dev/null; then
        log_info "No workspaces configured."
        return 0
    fi

    local ws_count
    ws_count=$(jq '.workspaces | length // 0' "$json_file" 2>/dev/null)
    if [ -z "$ws_count" ] || [ "$ws_count" -eq 0 ]; then
        log_info "No workspaces configured. Add one with: ${BOLD}source rogue ws add <name>${RESET}"
        return 0
    fi

    echo -e "\n────────────────────────────────────────────"
    echo -e "${ROGUE_RED_ITALIC}[Rogue]${RESET} ${BOLD_ITALIC_UNDERLINE}Registered Workspaces${RESET}\n"

    local col_headers=("Workspace" "Path" "GitHub Org" "Email" "Projects" "Flags")
    local col_align=("l" "l" "l" "l" "r" "l")
    local col_count=6

    local names=() paths=() orgs=() emails=() proj_counts=() flags=()

    while IFS=$'\t' read -r w_name w_path w_org w_email w_skip w_hidden; do
        names+=("$w_name")
        paths+=("$w_path")
        
        [ "$w_org" = "null" ] || [ -z "$w_org" ] && orgs+=("-") || orgs+=("$w_org")
        [ "$w_email" = "null" ] || [ -z "$w_email" ] && emails+=("-") || emails+=("$w_email")

        local p_count=0
        if [ -d "$w_path" ]; then
            for d in "$w_path"/*/; do
                [ -d "$d" ] && ((p_count++))
            done
        fi
        proj_counts+=("$p_count")

        local flg=""
        [ "$w_skip" = "true" ] && flg+="[no-snap] "
        [ "$w_hidden" = "true" ] && flg+="[hidden] "
        [ -z "$flg" ] && flg="-"
        flags+=("$flg")
    done < <(jq -r '.workspaces[]? | [ .name, .path, (.gh_org // "-"), (.git_user_email // "-"), (.skip_snapshot // false), (.hidden // false) ] | @tsv' "$json_file")

    local count=${#names[@]}
    local widths=()
    for ((c = 0; c < col_count; c++)); do
        widths[$c]=${#col_headers[$c]}
    done

    for ((idx = 0; idx < count; idx++)); do
        [ ${#names[$idx]} -gt ${widths[0]} ] && widths[0]=${#names[$idx]}
        [ ${#paths[$idx]} -gt ${widths[1]} ] && widths[1]=${#paths[$idx]}
        [ ${#orgs[$idx]} -gt ${widths[2]} ] && widths[2]=${#orgs[$idx]}
        [ ${#emails[$idx]} -gt ${widths[3]} ] && widths[3]=${#emails[$idx]}
        [ ${#proj_counts[$idx]} -gt ${widths[4]} ] && widths[4]=${#proj_counts[$idx]}
        [ ${#flags[$idx]} -gt ${widths[5]} ] && widths[5]=${#flags[$idx]}
    done

    local row_fmt="  "
    for ((c = 0; c < col_count; c++)); do
        [ $c -gt 0 ] && row_fmt+=" | "
        row_fmt+="%b"
    done
    row_fmt+="\n"

    local cells=()
    for ((c = 0; c < col_count; c++)); do
        local val=""
        if [ "${col_align[$c]}" = "r" ]; then
            val=$(printf "%*s" "${widths[$c]}" "${col_headers[$c]}")
        else
            val=$(printf "%-*s" "${widths[$c]}" "${col_headers[$c]}")
        fi
        cells+=("$val")
    done
    printf "$row_fmt" "${cells[@]}"

    local total=0
    for ((c = 0; c < col_count; c++)); do
        total=$((total + widths[c]))
    done
    total=$((total + (col_count - 1) * 3))
    printf "  ─"
    for ((i = 0; i < total; i++)); do printf "─"; done
    echo ""

    for ((idx = 0; idx < count; idx++)); do
        cells=()
        for ((c = 0; c < col_count; c++)); do
            case $c in
                0) cells+=("$(printf "%-*s" "${widths[0]}" "${names[$idx]}")") ;;
                1) cells+=("$(printf "%-*s" "${widths[1]}" "${paths[$idx]}")") ;;
                2) cells+=("$(printf "%-*s" "${widths[2]}" "${orgs[$idx]}")") ;;
                3) cells+=("$(printf "%-*s" "${widths[3]}" "${emails[$idx]}")") ;;
                4) cells+=("$(printf "%*s" "${widths[4]}" "${proj_counts[$idx]}")") ;;
                5) cells+=("$(printf "%-*s" "${widths[5]}" "${flags[$idx]}")") ;;
            esac
        done
        printf "$row_fmt" "${cells[@]}"
    done
    echo ""
}

cmd_ws_remove() {
    local name="$1"
    if [ -z "$name" ]; then
        log_error "Usage: source rogue ws remove <name>"
        return 1
    fi

    local resolved_name
    resolved_name=$(resolve_workspace_name "$name") || return 1
    name="$resolved_name"

    local json_file="$(get_config_file)"
    if [ ! -f "$json_file" ] || ! command -v jq &>/dev/null; then
        log_error "No config file found."
        return 1
    fi

    local exists
    exists=$(jq --arg name "$name" '.workspaces[]? | select(.name == $name) | .name' "$json_file" 2>/dev/null)
    if [ -z "$exists" ]; then
        log_error "Workspace '$name' not found."
        return 1
    fi

    local updated_json
    updated_json=$(jq --arg name "$name" '.workspaces = [.workspaces[] | select(.name != $name)]' "$json_file")
    echo "$updated_json" > "$json_file"

    log_success "Unregistered workspace '$name'."
    log_info "Note: The physical directory was NOT deleted."
}

cmd_ws_link() {
    local dir_path=""
    local target_ws=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ws|-w)
                [ -z "$2" ] || [[ "$2" == -* ]] && { log_error "--ws requires a workspace name"; return 1; }
                target_ws="$2"; shift 2 ;;
            --help|-h)
                echo -e "\n${ROGUE_RED_ITALIC}[Rogue]${RESET} ${BOLD}WORKSPACE LINK USAGE${RESET}"
                echo -e "source rogue ws link <dir> [options]\n"
                echo -e "  --ws <name>    Associate with a registered workspace profile (orphan if omitted)"
                return 0 ;;
            *)
                if [ -z "$dir_path" ] && [[ "$1" != -* ]]; then
                    dir_path="$1"
                else
                    log_error "Invalid argument for 'ws link': $1"; return 1
                fi
                shift ;;
        esac
    done

    if [ -n "$target_ws" ]; then
        local resolved_ws
        resolved_ws=$(resolve_workspace_name "$target_ws") || return 1
        target_ws="$resolved_ws"
    fi

    [ -z "$dir_path" ] && dir_path="$(pwd)"
    dir_path="${dir_path/#\~/$HOME}"
    dir_path="$(realpath "$dir_path" 2>/dev/null || echo "$dir_path")"

    if [ ! -d "$dir_path" ]; then
        log_error "Directory does not exist: $dir_path"
        return 1
    fi

    local list_file="${LOCAL_PROJECTS_LIST:-$HOME/.config/rogue/rp.list}"
    mkdir -p "$(dirname "$list_file")"
    touch "$list_file"

    local entry="$dir_path"
    if [ -n "$target_ws" ]; then
        entry="$dir_path|$target_ws"
    fi

    # Remove existing reference to this dir if present
    if [ -f "$list_file" ]; then
        grep -v "^$dir_path" "$list_file" > "${list_file}.tmp" 2>/dev/null || true
        mv "${list_file}.tmp" "$list_file"
    fi

    echo "$entry" >> "$list_file"
    awk '!seen[$0]++' "$list_file" > "${list_file}.tmp" && mv "${list_file}.tmp" "$list_file"

    if [ -n "$target_ws" ]; then
        log_success "Linked local project $dir_path to workspace '${BOLD}$target_ws${RESET}'"
    else
        log_success "Linked local project $dir_path as ${YELLOW}[orphan]${RESET}"
    fi
}

cmd_ws_unlink() {
    local dir_path="$1"
    [ -z "$dir_path" ] && dir_path="$(pwd)"
    dir_path="${dir_path/#\~/$HOME}"
    dir_path="$(realpath "$dir_path" 2>/dev/null || echo "$dir_path")"

    local list_file="${LOCAL_PROJECTS_LIST:-$HOME/.config/rogue/rp.list}"
    if [ ! -f "$list_file" ]; then
        log_error "No local projects list found."
        return 1
    fi

    grep -v "^$dir_path" "$list_file" > "${list_file}.tmp" 2>/dev/null || true
    mv "${list_file}.tmp" "$list_file"
    log_success "Unlinked local project: $dir_path"
}

cmd_ws_sync() {
    local ws_name="$1"
    if [ -z "$ws_name" ]; then
        log_error "Usage: source rogue ws sync <workspace_name>"
        return 1
    fi

    local resolved_ws
    resolved_ws=$(resolve_workspace_name "$ws_name") || return 1
    ws_name="$resolved_ws"

    local json_file="$(get_config_file)"
    local ws_info
    ws_info=$(jq --arg name "$ws_name" '.workspaces[]? | select(.name == $name)' "$json_file" 2>/dev/null)

    if [ -z "$ws_info" ] || [ "$ws_info" = "null" ]; then
        log_error "Workspace '$ws_name' not found."
        return 1
    fi

    local ws_path gh_org
    ws_path=$(echo "$ws_info" | jq -r '.path')
    gh_org=$(echo "$ws_info" | jq -r '.gh_org // empty')

    if [ -z "$gh_org" ] || [ "$gh_org" = "null" ]; then
        log_error "Workspace '$ws_name' does not have an associated GitHub Organization (--org)."
        return 1
    fi

    if ! command -v gh &>/dev/null; then
        log_error "GitHub CLI (gh) is required for org sync."
        return 1
    fi

    echo -e "\n────────────────────────────────────────────"
    echo -e "${ROGUE_RED_ITALIC}[Rogue]${RESET} ${BOLD_ITALIC_UNDERLINE}Syncing Workspace: $ws_name (GitHub Org: $gh_org)${RESET}\n"

    mkdir -p "$ws_path"
    local repos
    repos=$(gh repo list "$gh_org" --limit 100 --json name,sshUrl,url --jq '.[] | "\(.name)\t\(.sshUrl)\t\(.url)"' 2>/dev/null)

    if [ -z "$repos" ]; then
        log_info "No repositories found for org '$gh_org' or authorization failed."
        return 0
    fi

    local cloned=0 skipped=0
    while IFS=$'\t' read -r repo_name ssh_url clone_url; do
        local target_repo_dir="$ws_path/$repo_name"
        if [ -d "$target_repo_dir" ]; then
            ((skipped++))
        else
            log_step "Cloning $repo_name..."
            if git clone "$clone_url" "$target_repo_dir" >/dev/null 2>&1; then
                ((cloned++))
            else
                log_error "Failed to clone $repo_name"
            fi
        fi
    done <<< "$repos"

    log_success "Sync complete: $cloned cloned, $skipped already present."
}
