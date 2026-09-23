# ==========================================
# MODULE: ARCHIVE / UNARCHIVE
# ==========================================

_get_archive_dir() {
    local json_file="${ROGUE_CONFIG:-$HOME/.config/rogue/rogueConf.json}"
    local arch_dir=""
    if [ -f "$json_file" ] && command -v jq &>/dev/null; then
        arch_dir=$(jq -r '.workspaces[]? | select(.name == "Archived") | .path // empty' "$json_file" 2>/dev/null)
    fi
    [ -z "$arch_dir" ] && arch_dir="$PROJECTS_DIR/Archived"
    arch_dir="${arch_dir/#\~/$HOME}"
    echo "$arch_dir"
}

_extract_repo_slug() {
    local url="$1"
    # Converts https://github.com/owner/repo.git or git@github.com:owner/repo.git -> owner/repo
    echo "$url" | sed -E 's|^https?://[^/]+/||; s|^git@[^:]+:||; s|\.git$||'
}

_rsync_move_dir() {
    local src="$1"
    local dest="$2"

    mkdir -p "$dest"
    if command -v rsync &>/dev/null; then
        # -a: archive mode (recurse, perms, times, symlinks, owner, group)
        # -P: --partial (keep partially transferred files to resume later) + --progress
        # -h: human-readable numbers
        # --remove-source-files: deletes source files after verified transfer
        rsync -ahP --remove-source-files "$src/" "$dest/"
        local status=$?
        if [ $status -eq 0 ]; then
            rm -rf "$src"
            return 0
        else
            log_error "Transfer interrupted or failed (exit code $status). Re-run command to resume."
            return $status
        fi
    else
        log_warning "rsync not found; falling back to mv."
        mv "$src" "$dest"
    fi
}

cmd_archive() {
    local project_name=""
    local local_only="false"
    local source_ws=""
    local assume_yes="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --local-only) local_only="true"; shift ;;
            -w|--ws|--workspace)
                [ -z "$2" ] || [[ "$2" == -* ]] && { log_error "--ws requires a workspace name"; return 1; }
                source_ws="$2"; shift 2 ;;
            -y|--yes) assume_yes="true"; shift ;;
            --help|-h)
                echo -e "\n${ROGUE_RED_ITALIC}[Rogue]${RESET} ${BOLD}ARCHIVE COMMAND USAGE${RESET}"
                echo -e "source rogue archive [project_name] [options]\n"
                echo -e "  --local-only      Move project folder without archiving remote on GitHub/GitLab"
                echo -e "  -w, --ws <name>   Source workspace if project is inside a workspace"
                echo -e "  -y, --yes         Skip confirmation prompt\n"
                return 0 ;;
            *)
                if [ -z "$project_name" ] && [[ "$1" != -* ]]; then
                    project_name="$1"
                else
                    log_error "Invalid flag for 'archive': $1"; return 1
                fi
                shift ;;
        esac
    done

    [ -z "$project_name" ] && log_prompt "Enter project name to archive: " project_name
    [ -z "$project_name" ] && { log_error "Project name cannot be empty."; return 1; }

    if [ -n "$source_ws" ]; then
        local resolved_ws
        resolved_ws=$(resolve_workspace_name "$source_ws" "$assume_yes") || return 1
        source_ws="$resolved_ws"
    fi

    local resolved_pname
    resolved_pname=$(resolve_project_name "$project_name" "$source_ws" "$assume_yes") || return 1
    project_name="$resolved_pname"

    local json_file="${ROGUE_CONFIG:-$HOME/.config/rogue/rogueConf.json}"
    local list_file="${LOCAL_PROJECTS_LIST:-$HOME/.config/rogue/rp.list}"
    local found_dir=""
    local found_ws=""

    # 1. If source_ws was specified, check there
    if [ -n "$source_ws" ] && [ -f "$json_file" ] && command -v jq &>/dev/null; then
        local ws_path
        ws_path=$(jq -r --arg name "$source_ws" '.workspaces[]? | select(.name == $name) | .path // empty' "$json_file" 2>/dev/null)
        ws_path="${ws_path/#\~/$HOME}"
        if [ -n "$ws_path" ] && [ -d "$ws_path/$project_name" ]; then
            found_dir="$ws_path/$project_name"
            found_ws="$source_ws"
        fi
    fi

    # 2. Check default PROJECTS_DIR
    if [ -z "$found_dir" ] && [ -d "$PROJECTS_DIR/$project_name" ]; then
        found_dir="$PROJECTS_DIR/$project_name"
    fi

    # 3. Check registered workspaces
    if [ -z "$found_dir" ] && [ -f "$json_file" ] && command -v jq &>/dev/null; then
        while IFS=$'\t' read -r w_name w_path; do
            [ -z "$w_path" ] || [ "$w_name" = "Archived" ] && continue
            w_path="${w_path/#\~/$HOME}"
            if [ -d "$w_path/$project_name" ]; then
                found_dir="$w_path/$project_name"
                found_ws="$w_name"
                break
            fi
        done < <(jq -r '.workspaces[]? | [ .name, .path ] | @tsv' "$json_file" 2>/dev/null)
    fi

    # 4. Check rp.list
    if [ -z "$found_dir" ] && [ -f "$list_file" ]; then
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            local l_path="${line%|*}"
            local l_ws="${line#*|}"
            if [ "$(basename "$l_path")" = "$project_name" ] && [ -d "$l_path" ]; then
                found_dir="$l_path"
                found_ws="$l_ws"
                break
            fi
        done < "$list_file"
    fi

    if [ -z "$found_dir" ] || [ ! -d "$found_dir" ]; then
        log_error "Project '$project_name' not found."
        return 1
    fi

    local archive_dir="$(_get_archive_dir)"
    mkdir -p "$archive_dir"

    if [ "$found_dir" = "$archive_dir/$project_name" ]; then
        log_error "Project '$project_name' is already in the Archived workspace."
        return 1
    fi

    echo -e "\n────────────────────────────────────────────"
    echo -e "${ROGUE_RED_ITALIC}[Rogue]${RESET} ${BOLD_ITALIC_UNDERLINE}Archiving Project: $project_name${RESET}\n"
    log_step "Current location: $found_dir"

    # Cloud Archival
    if [ "$local_only" != "true" ] && [ -d "$found_dir/.git" ]; then
        # Check GitHub remote
        local gh_url
        gh_url=$(git -C "$found_dir" remote get-url github 2>/dev/null)
        if [ -z "$gh_url" ]; then
            local origin_url
            origin_url=$(git -C "$found_dir" remote get-url origin 2>/dev/null)
            [[ "$origin_url" == *github.com* ]] && gh_url="$origin_url"
        fi

        if [ -n "$gh_url" ] && command -v gh &>/dev/null; then
            local gh_slug="$(_extract_repo_slug "$gh_url")"
            log_step "Archiving remote on GitHub ($gh_slug)..."
            if gh repo archive "$gh_slug" --yes >/dev/null 2>&1; then
                log_success "GitHub repository archived: $gh_slug"
            else
                log_error "Failed to archive GitHub repository (check gh auth or permissions)."
            fi
        fi

        # Check GitLab remote
        local gl_url
        gl_url=$(git -C "$found_dir" remote get-url gitlab 2>/dev/null)
        if [ -n "$gl_url" ] && command -v glab &>/dev/null; then
            local gl_slug="$(_extract_repo_slug "$gl_url")"
            local encoded_slug=$(echo "$gl_slug" | sed 's|/|%2F|g')
            log_step "Archiving remote on GitLab ($gl_slug)..."
            if glab api -X POST "projects/$encoded_slug/archive" >/dev/null 2>&1; then
                log_success "GitLab repository archived: $gl_slug"
            else
                log_error "Failed to archive GitLab repository (check glab auth)."
            fi
        fi
    fi

    # Local Filesystem Relocation
    log_step "Moving project to $archive_dir/$project_name..."
    if ! _rsync_move_dir "$found_dir" "$archive_dir/$project_name"; then
        log_error "Archiving failed during file movement."
        return 1
    fi

    # Update rp.list if the project was tracked there
    if [ -f "$list_file" ]; then
        grep -v "^$found_dir" "$list_file" > "${list_file}.tmp" 2>/dev/null || true
        mv "${list_file}.tmp" "$list_file"
    fi

    log_success "Project '$project_name' has been archived."
}

cmd_unarchive() {
    local project_name=""
    local local_only="false"
    local target_ws=""
    local assume_yes="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --local-only) local_only="true"; shift ;;
            -w|--ws|--workspace)
                [ -z "$2" ] || [[ "$2" == -* ]] && { log_error "--ws requires a workspace name"; return 1; }
                target_ws="$2"; shift 2 ;;
            -y|--yes) assume_yes="true"; shift ;;
            --help|-h)
                echo -e "\n${ROGUE_RED_ITALIC}[Rogue]${RESET} ${BOLD}UNARCHIVE COMMAND USAGE${RESET}"
                echo -e "source rogue unarchive [project_name] [options]\n"
                echo -e "  --local-only      Move project folder without unarchiving remote on GitHub/GitLab"
                echo -e "  -w, --ws <name>   Destination workspace (defaults to \$PROJECTS_DIR)"
                echo -e "  -y, --yes         Skip confirmation prompt\n"
                return 0 ;;
            *)
                if [ -z "$project_name" ] && [[ "$1" != -* ]]; then
                    project_name="$1"
                else
                    log_error "Invalid flag for 'unarchive': $1"; return 1
                fi
                shift ;;
        esac
    done

    [ -z "$project_name" ] && log_prompt "Enter project name to unarchive: " project_name
    [ -z "$project_name" ] && { log_error "Project name cannot be empty."; return 1; }

    if [ -n "$target_ws" ]; then
        local resolved_ws
        resolved_ws=$(resolve_workspace_name "$target_ws" "$assume_yes") || return 1
        target_ws="$resolved_ws"
    fi

    local resolved_pname
    resolved_pname=$(resolve_archived_project "$project_name" "$assume_yes") || return 1
    project_name="$resolved_pname"

    local archive_dir="$(_get_archive_dir)"
    local src_dir="$archive_dir/$project_name"

    if [ ! -d "$src_dir" ]; then
        log_error "Project '$project_name' was not found in the Archived workspace ($archive_dir)."
        return 1
    fi

    local json_file="${ROGUE_CONFIG:-$HOME/.config/rogue/rogueConf.json}"
    local dest_dir=""

    if [ -n "$target_ws" ] && [ -f "$json_file" ] && command -v jq &>/dev/null; then
        local ws_path
        ws_path=$(jq -r --arg name "$target_ws" '.workspaces[]? | select(.name == $name) | .path // empty' "$json_file" 2>/dev/null)
        ws_path="${ws_path/#\~/$HOME}"
        if [ -n "$ws_path" ]; then
            dest_dir="$ws_path/$project_name"
        fi
    fi

    [ -z "$dest_dir" ] && dest_dir="$PROJECTS_DIR/$project_name"

    if [ -d "$dest_dir" ]; then
        log_info "Destination directory already exists; resuming transfer into $dest_dir..."
    fi

    echo -e "\n────────────────────────────────────────────"
    echo -e "${ROGUE_RED_ITALIC}[Rogue]${RESET} ${BOLD_ITALIC_UNDERLINE}Unarchiving Project: $project_name${RESET}\n"

    # Cloud Unarchival
    if [ "$local_only" != "true" ] && [ -d "$src_dir/.git" ]; then
        local gh_url
        gh_url=$(git -C "$src_dir" remote get-url github 2>/dev/null)
        if [ -z "$gh_url" ]; then
            local origin_url
            origin_url=$(git -C "$src_dir" remote get-url origin 2>/dev/null)
            [[ "$origin_url" == *github.com* ]] && gh_url="$origin_url"
        fi

        if [ -n "$gh_url" ] && command -v gh &>/dev/null; then
            local gh_slug="$(_extract_repo_slug "$gh_url")"
            log_step "Unarchiving remote on GitHub ($gh_slug)..."
            if gh repo unarchive "$gh_slug" --yes >/dev/null 2>&1; then
                log_success "GitHub repository unarchived: $gh_slug"
            else
                log_error "Failed to unarchive GitHub repository."
            fi
        fi

        local gl_url
        gl_url=$(git -C "$src_dir" remote get-url gitlab 2>/dev/null)
        if [ -n "$gl_url" ] && command -v glab &>/dev/null; then
            local gl_slug="$(_extract_repo_slug "$gl_url")"
            local encoded_slug=$(echo "$gl_slug" | sed 's|/|%2F|g')
            log_step "Unarchiving remote on GitLab ($gl_slug)..."
            if glab api -X POST "projects/$encoded_slug/unarchive" >/dev/null 2>&1; then
                log_success "GitLab repository unarchived: $gl_slug"
            else
                log_error "Failed to unarchive GitLab repository."
            fi
        fi
    fi

    # Local Filesystem Relocation
    log_step "Moving project to $dest_dir..."
    if ! _rsync_move_dir "$src_dir" "$dest_dir"; then
        log_error "Unarchiving failed during file movement."
        return 1
    fi

    log_success "Project '$project_name' has been unarchived to $dest_dir"
}
