# ==========================================
# MODULE: ADD REMOTE
# ==========================================

cmd_addRemote() {
    local target_remote=""
    local visibility="private"
    local prompt_desc="false"
    local desc_msg="Repository created via RoguePM"
    local project_name=$(basename "$PWD")

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
                prompt_desc="true"
                shift 1 ;;
            -n|--name)
                [ -z "$2" ] && { log_error "Project name cannot be empty."; return 1; }
                project_name="$2"
                shift 2 ;;
            --help|-h)
                echo -e "\n${ROGUE_RED_ITALIC}[Rogue]${RESET} ${BOLD}ADD REMOTE USAGE${RESET}"
                echo -e "source rogue addRemote --remote <platform> [options]\n"
                echo -e "  --remote <target>   REQUIRED: 'github', 'gitlab', or 'both'"
                echo -e "  -v <public|private> Set repository visibility (default is private)"
                echo -e "  -d, --description   Prompt for a cloud repository description"
                echo -e "  -n <name>           Specific repository name"
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

    if [ "$prompt_desc" == "true" ]; then
        local user_desc
        log_prompt "Enter repository description: " user_desc
        [ -n "$user_desc" ] && desc_msg="$user_desc"
    fi

    log_divider "--- Attaching Cloud Remotes ---"

    if [[ "$target_remote" == "github" || "$target_remote" == "both" ]]; then
        if git remote get-url github > /dev/null 2>&1; then
            log_error "'github' remote already exists."
        else
            check_github_auth || return 1
            log_info "Creating GitHub repository ($visibility)..."
            gh repo create "$project_name" --"$visibility" --description "$desc_msg"
            local gh_user=$(gh api user --jq .login)
            git remote add github "https://github.com/$gh_user/$project_name.git"
            log_info "Pushing to GitHub..."
            git push -u github master
            log_success "GitHub remote attached."
        fi
    fi

    if [[ "$target_remote" == "gitlab" || "$target_remote" == "both" ]]; then
        if git remote get-url gitlab > /dev/null 2>&1; then
            log_error "'gitlab' remote already exists."
        else
            check_gitlab_auth || return 1
            log_info "Creating GitLab repository ($visibility)..."
            glab repo create "$project_name" --"$visibility" --description "$desc_msg"
            local gl_user=$(glab api user -q '.username')
            git remote add gitlab "https://gitlab.com/$gl_user/$project_name.git"
            log_info "Pushing to GitLab..."
            git push -u gitlab master
            log_success "GitLab remote attached."
        fi
    fi
}
