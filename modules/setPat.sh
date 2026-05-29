# ==========================================
# MODULE: SET PAT
# ==========================================

cmd_setPat() {
    log_divider "--- Configuring PATs for all Remotes ---"

    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        log_error "Not inside a git repository."
        return 1
    fi

    local remotes=$(git remote)
    if [ -z "$remotes" ]; then
        log_error "No remotes found to update."
        return 1
    fi

    for r in $remotes; do
        local remote_url=$(git remote get-url "$r")

        if [[ "$remote_url" == git@* ]]; then
            log_info "Remote '$r' uses SSH. Skipping."
            continue
        fi

        if [[ "$r" == "origin" ]]; then
            log_info "[Legacy] Remote named 'origin' detected."
        fi

        if [[ "$remote_url" == *github.com* ]]; then
            if [ -z "$GHPAT" ]; then
                log_error "\$GHPAT missing. Skipping GitHub."
                continue
            fi
            local repo_path_clean=$(echo "$remote_url" | sed -E 's|^https://.*@github\.com/||' | sed -E 's|^https://github\.com/||')
            local new_url="https://${GHPAT}@github.com/${repo_path_clean}"
            git remote set-url "$r" "$new_url"
            log_success "Secured $r (GitHub)"

        elif [[ "$remote_url" == *gitlab.com* ]]; then
            if [ -z "$GLPAT" ]; then
                log_error "\$GLPAT missing. Skipping GitLab."
                continue
            fi
            local repo_path_clean=$(echo "$remote_url" | sed -E 's|^https://.*@gitlab\.com/||' | sed -E 's|^https://gitlab\.com/||')
            local new_url="https://oauth2:${GLPAT}@gitlab.com/${repo_path_clean}"
            git remote set-url "$r" "$new_url"
            log_success "Secured $r (GitLab)"
        else
            log_error "Remote '$r' is not recognized."
        fi
    done
}
