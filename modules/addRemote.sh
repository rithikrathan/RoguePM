# ==========================================
# MODULE: ADD REMOTE
# ==========================================

cmd_addRemote() {
    local target_remote=""
    local visibility="private"
    local prompt_desc="false"
    local desc_msg="Repository created via RoguePM"
    local project_name=$(basename "$PWD")
    local target_org=""
    local target_ws=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --remote)
                if [[ "$2" != "github" && "$2" != "gitlab" && "$2" != "both" ]]; then
                    log_error "--remote must be 'github', 'gitlab', or 'both'."
                    return 1
                fi
                target_remote="$2"
                shift 2 ;;
            -v|--visibility)
                if [[ "$2" != "public" && "$2" != "private" ]]; then
                    log_error "Visibility must be 'public' or 'private'."
                    return 1
                fi
                visibility="$2"
                shift 2 ;;
            -d|--description)
                if [[ -n "$2" && "$2" != -* ]]; then
                    desc_msg="$2"
                    shift 2
                else
                    prompt_desc="true"
                    shift 1
                fi ;;
            -n|--name)
                [ -z "$2" ] && { log_error "Project name cannot be empty."; return 1; }
                project_name="$2"
                shift 2 ;;
            -o|--org)
                [ -z "$2" ] && { log_error "Organization name cannot be empty."; return 1; }
                target_org="$2"
                shift 2 ;;
            -w|--ws|--workspace)
                [ -z "$2" ] && { log_error "Workspace name cannot be empty."; return 1; }
                target_ws="$2"
                shift 2 ;;
            --help|-h)
                echo -e "\n${ROGUE_RED_ITALIC}[Rogue]${RESET} ${BOLD}ADD REMOTE USAGE${RESET}"
                echo -e "source rogue addRemote --remote <platform> [options]\n"
                echo -e "  --remote <target>   REQUIRED: 'github', 'gitlab', or 'both'"
                echo -e "  -v <public|private> Set repository visibility (default is private)"
                echo -e "  -o, --org <org>     GitHub organization to create repository in"
                echo -e "  -w, --ws <name>     Target workspace profile to inherit GitHub org"
                echo -e "  -d, --description   Repository description"
                echo -e "  -n <name>           Specific repository name\n"
                return 0 ;;
            *) log_error "Invalid flag for 'addRemote': $1"; return 1 ;;
        esac
    done

    if [ -z "$target_remote" ]; then
        log_error "The '--remote <github|gitlab|both>' flag is REQUIRED."
        return 1
    fi

    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        log_error "Not inside a git repository."
        return 1
    fi

    local json_file="${ROGUE_CONFIG:-$HOME/.config/rogue/rogueConf.json}"

    # If --ws was provided or current dir is inside a registered workspace, lookup gh_org
    if [ -z "$target_org" ] && [ -f "$json_file" ] && command -v jq &>/dev/null; then
        if [ -n "$target_ws" ]; then
            target_org=$(jq -r --arg name "$target_ws" '.workspaces[]? | select(.name == $name) | .gh_org // empty' "$json_file" 2>/dev/null)
        else
            local curr_dir="$(pwd)"
            while IFS=$'\t' read -r w_path w_org; do
                [ -z "$w_path" ] && continue
                w_path="${w_path/#\~/$HOME}"
                if [[ "$curr_dir" == "$w_path"* ]] && [ -n "$w_org" ] && [ "$w_org" != "null" ]; then
                    target_org="$w_org"
                    break
                fi
            done < <(jq -r '.workspaces[]? | [ .path, (.gh_org // empty) ] | @tsv' "$json_file" 2>/dev/null)
        fi
    fi

    if [ "$prompt_desc" == "true" ]; then
        local user_desc
        log_prompt "Enter repository description: " user_desc
        [ -n "$user_desc" ] && desc_msg="$user_desc"
    fi

    echo -e "\n────────────────────────────────────────────"
    echo -e "${ROGUE_RED_ITALIC}[Rogue]${RESET} ${BOLD_ITALIC_UNDERLINE}Attaching Cloud Remotes${RESET}\n"

    if [[ "$target_remote" == "github" || "$target_remote" == "both" ]]; then
        if git remote get-url github > /dev/null 2>&1; then
            log_error "'github' remote already exists."
        else
            check_github_auth || return 1
            if [ -n "$target_org" ]; then
                log_step "Creating GitHub repository under organization '$target_org' ($visibility)..."
                gh repo create "$target_org/$project_name" --"$visibility" --description "$desc_msg"
                git remote add github "https://github.com/$target_org/$project_name.git"
            else
                log_step "Creating GitHub repository ($visibility)..."
                gh repo create "$project_name" --"$visibility" --description "$desc_msg"
                local gh_user=$(gh api user --jq .login)
                git remote add github "https://github.com/$gh_user/$project_name.git"
            fi
            log_step "Pushing to GitHub..."
            git push -u github master 2>/dev/null || git push -u github main 2>/dev/null
            log_success "GitHub remote attached."
        fi
    fi

    if [[ "$target_remote" == "gitlab" || "$target_remote" == "both" ]]; then
        if git remote get-url gitlab > /dev/null 2>&1; then
            log_error "'gitlab' remote already exists."
        else
            check_gitlab_auth || return 1
            log_step "Creating GitLab repository ($visibility)..."
            glab repo create "$project_name" --"$visibility" --description "$desc_msg"
            local gl_user=$(glab api user -q '.username')
            git remote add gitlab "https://gitlab.com/$gl_user/$project_name.git"
            log_step "Pushing to GitLab..."
            git push -u gitlab master 2>/dev/null || git push -u gitlab main 2>/dev/null
            log_success "GitLab remote attached."
        fi
    fi
}
