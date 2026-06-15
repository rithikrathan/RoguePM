cmd_update() {
    local repo_dir="$ROGUE_DIR"
    local branch=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                echo -e "\n${ROGUE_RED_ITALIC}[Rogue]${RESET} ${BOLD}UPDATE COMMAND USAGE${RESET}"
                echo -e "source rogue update [options]\n"
                echo -e "Pulls the latest version of RoguePM from its git repository and reinstalls.\n"
                echo -e "  --help, -h     Show this help message\n"
                return 0 ;;
            *) log_error "Invalid flag for 'update': $1"; return 1 ;;
        esac
    done

    if [ ! -d "$repo_dir/.git" ]; then
        log_error "RoguePM repository not found at $repo_dir"
        log_info "Update only works when running from the cloned RoguePM repo."
        return 1
    fi

    echo -e "\n────────────────────────────────────────────"
    echo -e "${ROGUE_RED_ITALIC}[Rogue]${RESET} ${BOLD_ITALIC_UNDERLINE}Updating RoguePM${RESET}\n"

    branch=$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
    log_info "Current branch: ${BOLD}$branch${RESET}"

    if ! git -C "$repo_dir" diff --quiet 2>/dev/null; then
        log_info "You have uncommitted changes. Stashing them..."
        git -C "$repo_dir" stash push -m "rogue-update-auto-stash" 2>/dev/null
        local stashed=true
    fi

    log_step "Fetching latest from origin..."
    if ! git -C "$repo_dir" fetch origin 2>&1; then
        log_error "Failed to fetch from origin. Check your network or remote config."
        return 1
    fi

    local behind=$(git -C "$repo_dir" rev-list --count "HEAD..origin/$branch" 2>/dev/null)
    local ahead=$(git -C "$repo_dir" rev-list --count "origin/$branch..HEAD" 2>/dev/null)

    if [ "$behind" -eq 0 ]; then
        log_info "Already up to date. No update needed."
        return 0
    fi

    if [ "$ahead" -gt 0 ]; then
        log_info "Local repo has $ahead unpushed commit(s) and is behind by $behind — skipping auto-pull."
        log_info "Run 'git pull' manually in $repo_dir, then 'rogue setup --force'."
        return 1
    fi

    log_info "Behind origin/$branch by ${BOLD}$behind${RESET} commit(s). Pulling..."
    if ! git -C "$repo_dir" pull origin "$branch" 2>&1; then
        log_error "Pull failed. There may be merge conflicts."
        log_info "Resolve conflicts in $repo_dir, then run 'rogue setup --force'."
        return 1
    fi
    log_success "Pulled latest changes from origin/$branch."

    local sym_flag=""
    [ -L "$HOME/.local/bin/rogue" ] && sym_flag="--sym"

    echo ""
    log_step "Removing old installation..."
    cmd_setup --remove

    echo ""
    log_step "Installing updated version..."
    cmd_setup --force $sym_flag
}
