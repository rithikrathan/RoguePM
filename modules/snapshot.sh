# ==========================================
# MODULE: SNAPSHOT
# ==========================================

cmd_snapshot() {
    log_divider "--- Running Project Snapshots ---"

    declare -a report_repos
    declare -a report_statuses
    declare -a target_dirs

    for dir in "$PROJECTS_DIR"/*; do
        [ -d "$dir" ] && target_dirs+=("$dir")
    done

    if [ -f "$LOCAL_PROJECTS_LIST" ]; then
        while IFS= read -r dir; do
            if [ -d "$dir" ]; then
                if [[ ! " ${target_dirs[*]} " =~ " ${dir} " ]]; then
                    target_dirs+=("$dir")
                fi
            fi
        done < "$LOCAL_PROJECTS_LIST"
    fi

    if [ ${#target_dirs[@]} -eq 0 ]; then
        log_info "No projects found to snapshot."
        return 0
    fi

    for dir in "${target_dirs[@]}"; do
        local dirBaseName=$(basename "$dir")
        log_divider "Target: $dirBaseName"

        if [ -d "$dir/.git" ]; then
            cd "$dir" || continue

            if ! git diff --quiet || ! git diff --cached --quiet; then
                log_info "Committing changes..."
                git add -A
                git commit -m "RoguePM: Project snapshot"

                local remotes=$(git remote)
                if [ -z "$remotes" ]; then
                    log_info "No cloud remotes configured. Changes committed locally."
                    report_repos+=("$dirBaseName")
                    report_statuses+=("${GREEN}Committed locally${RESET}")
                    continue
                fi

                local push_failed=false
                for r in $remotes; do
                    log_info "Pushing to remote: ${BOLD}$r${RESET} (master branch)..."
                    if ! git push "$r" master; then
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
                log_info "No changes, up to date. Skipping..."
                report_repos+=("$dirBaseName")
                report_statuses+=("${YELLOW}Up to date${RESET}")
            fi
        else
            log_info "Not a git repository. Skipping..."
            report_repos+=("$dirBaseName")
            report_statuses+=("${YELLOW}Not a git repo${RESET}")
        fi
    done

    echo ""
    log_divider "SNAPSHOT SUMMARY REPORT"
    printf "  %-25s | %s\n" "Repository" "Status"
    printf "  %.0s-" {1..55}
    echo ""
    for i in "${!report_repos[@]}"; do
        printf "  %-25s | %b\n" "${report_repos[$i]}" "${report_statuses[$i]}"
    done
    echo ""
}
