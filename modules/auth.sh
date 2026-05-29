# ==========================================
# MODULE: AUTH CHECKERS
# ==========================================

check_github_auth() {
    if ! gh api user --jq .login >/dev/null 2>&1; then
        log_error "Cannot reach GitHub or GitHub CLI (gh) is not authenticated."
        return 1
    fi
    return 0
}

check_gitlab_auth() {
    if ! glab auth status >/dev/null 2>&1; then
        log_error "Cannot reach GitLab or GitLab CLI (glab) is not authenticated."
        return 1
    fi
    return 0
}
