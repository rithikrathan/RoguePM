# ==========================================
# MODULE: LIST
# ==========================================

cmd_list() {
    local filter_name=""
    local filter_status=""
    local filter_branch=""
    local filter_remote=""


    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--filter)
                [ -z "$2" ] || [[ "$2" == -* ]] && { log_error "--filter requires a value"; return 1; }
                filter_name="$2"; shift 2 ;;
            -fs|--filter-status)
                [ -z "$2" ] || [[ "$2" == -* ]] && { log_error "--filter-status requires a value"; return 1; }
                filter_status="$2"; shift 2 ;;
            -fb|--filter-branch)
                [ -z "$2" ] || [[ "$2" == -* ]] && { log_error "--filter-branch requires a value"; return 1; }
                filter_branch="$2"; shift 2 ;;
            -fr|--filter-remote)
                [ -z "$2" ] || [[ "$2" == -* ]] && { log_error "--filter-remote requires a value"; return 1; }
                filter_remote="$2"; shift 2 ;;
            --dirty) filter_status="dirty"; shift ;;
            --help|-h)
                echo -e "\n${ROGUE_RED_ITALIC}[Rogue]${RESET} ${BOLD}LIST COMMAND USAGE${RESET}"
                echo -e "source rogue list [options]\n"
                echo -e "  -f, --filter <text>             Filter projects by name substring"
                echo -e "  -fb, --filter-branch <branch>   Filter projects by branch name (matches any branch)"
                echo -e "  -fr, --filter-remote <text>     Filter projects by remote URL substring"
                echo -e "  -fs, --filter-status <s>        Filter by status: clean, dirty, no-git"
                echo -e "  --dirty                         Shorthand for --filter-status dirty"
                return 0 ;;
            *) log_error "Unknown option: $1"; return 1 ;;
        esac
    done

    declare -a target_dirs is_local_flags

    for dir in "$PROJECTS_DIR"/*; do
        [ -d "$dir" ] && target_dirs+=("$dir") && is_local_flags+=(false)
    done

    if [ -f "$LOCAL_PROJECTS_LIST" ]; then
        while IFS= read -r dir; do
            if [ -d "$dir" ] && [[ ! " ${target_dirs[*]} " =~ " ${dir} " ]]; then
                target_dirs+=("$dir")
                is_local_flags+=(true)
            fi
        done < "$LOCAL_PROJECTS_LIST"
    fi

    if [ ${#target_dirs[@]} -eq 0 ]; then
        log_info "No projects found."
        return 0
    fi
    echo -e "${ROGUE_RED_ITALIC}[Rogue]${RESET} ${BOLD_ITALIC_UNDERLINE}All Projects${RESET}\n"

    declare -a names branches statuses stashes remotes time_strs local_flags

    for i in "${!target_dirs[@]}"; do
        local dir="${target_dirs[$i]}"
        local name=$(basename "$dir")
        local is_local="${is_local_flags[$i]}"

        if [ -n "$filter_name" ]; then
            local name_lower="${name,,}" filter_lower="${filter_name,,}"
            [[ "$name_lower" != *"$filter_lower"* ]] && continue
        fi

        local branch=""
        local dirty=""
        local stash_count=0
        local remote_str="-"
        local time_str=""

        if [ -d "$dir/.git" ]; then
            branch=$(timeout 5 git -C "$dir" --no-optional-locks branch --show-current 2>/dev/null)
            [ -z "$branch" ] && branch=$(timeout 5 git -C "$dir" --no-optional-locks rev-parse --short HEAD 2>/dev/null)

            if ! timeout 5 git -C "$dir" --no-optional-locks diff --quiet 2>/dev/null || ! timeout 5 git -C "$dir" --no-optional-locks diff --cached --quiet 2>/dev/null; then
                dirty="true"
            fi

            stash_count=$(timeout 5 git -C "$dir" --no-optional-locks stash list 2>/dev/null | wc -l)
            stash_count=$((stash_count + 0))

            local remote_names
            remote_names=$(timeout 5 git -C "$dir" remote 2>/dev/null)
            if [ -n "$remote_names" ]; then
                local has_gh=false has_gl=false
                for r in $remote_names; do
                    local url
                    url=$(timeout 5 git -C "$dir" remote get-url "$r" 2>/dev/null)
                    case "$url" in
                        *github*) has_gh=true ;;
                        *gitlab*) has_gl=true ;;
                    esac
                done
                if $has_gh && $has_gl; then
                    remote_str="gh+gl"
                elif $has_gh; then
                    remote_str="github"
                elif $has_gl; then
                    remote_str="gitlab"
                else
                    remote_str="other"
                fi
            fi

            time_str=$(timeout 5 git -C "$dir" --no-optional-locks log -1 --format="%ar" 2>/dev/null)
        fi

        if [ -n "$filter_remote" ]; then
            local fr_lower="${filter_remote,,}"
            local all_urls
            all_urls=$(timeout 5 git -C "$dir" remote -v 2>/dev/null)
            local all_urls_lower="${all_urls,,}"
            if [[ "$all_urls_lower" != *"$fr_lower"* ]]; then
                continue
            fi
        fi

        if [ -n "$filter_branch" ]; then
            local fb_lower="${filter_branch,,}" matched=false
            local all_branches
            all_branches=$(timeout 5 git -C "$dir" --no-optional-locks branch --all --format='%(refname:short)' 2>/dev/null)
            while IFS= read -r b; do
                local b_lower="${b,,}"
                if [[ "$b_lower" == *"$fb_lower"* ]]; then
                    matched=true
                    break
                fi
            done <<< "$all_branches"
            if ! $matched; then
                continue
            fi
        fi

        local status_class=""
        if [ -z "$branch" ] && [ -z "$time_str" ]; then
            status_class="no-git"
        elif [ "$dirty" = "true" ]; then
            status_class="dirty"
        else
            status_class="clean"
        fi

        if [ -n "$filter_status" ] && [ "$status_class" != "$filter_status" ]; then
            continue
        fi

        names+=("$name")
        branches+=("$branch")
        statuses+=("$status_class")
        stashes+=("$stash_count")
        remotes+=("$remote_str")
        time_strs+=("$time_str")
        local_flags+=("$is_local")
    done

    local count=${#names[@]}
    if [ "$count" -eq 0 ]; then
        log_info "No projects match the given filters."
        return 0
    fi

    # column config: header, alignment (l/r), data key
    local col_headers=("Project" "Branch" "Status" "Stash" "Remote" "Last Commit")
    local col_align=("l" "l" "l" "r" "l" "l")
    local col_count=6

    # calculate column widths from headers + data
    local widths=()
    for ((c = 0; c < col_count; c++)); do
        widths[$c]=${#col_headers[$c]}
    done

    for ((idx = 0; idx < count; idx++)); do
        # Project (+ [local] banner)
        local display_name="${names[$idx]}"
        [ "${local_flags[$idx]}" = "true" ] && display_name+=" [local]"
        [ ${#display_name} -gt ${widths[0]} ] && widths[0]=${#display_name}

        # Branch (use - for empty, centered)
        local bv="${branches[$idx]}"
        [ -z "$bv" ] && bv="-"
        [ ${#bv} -gt ${widths[1]} ] && widths[1]=${#bv}

        # Status (visible text before colors)
        local sv=""
        case "${statuses[$idx]}" in
            clean)  sv="● clean" ;;
            dirty)  sv="● dirty" ;;
            no-git) sv="no git" ;;
        esac
        [ ${#sv} -gt ${widths[2]} ] && widths[2]=${#sv}

        # Stash
        [ ${#stashes[$idx]} -gt ${widths[3]} ] && widths[3]=${#stashes[$idx]}

        # Remote
        [ ${#remotes[$idx]} -gt ${widths[4]} ] && widths[4]=${#remotes[$idx]}

        # Last Commit (use -- for empty)
        local tv="${time_strs[$idx]}"
        [ -z "$tv" ] && tv="--"
        [ ${#tv} -gt ${widths[5]} ] && widths[5]=${#tv}
    done

    # build format string: each col is pre-padded, so just %b with " | " separator
    local row_fmt="  "
    for ((c = 0; c < col_count; c++)); do
        [ $c -gt 0 ] && row_fmt+=" | "
        row_fmt+="%b"
    done
    row_fmt+="\n"

    # --- print header ---
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

    # --- divider ---
    local total=0
    for ((c = 0; c < col_count; c++)); do
        total=$((total + widths[c]))
    done
    total=$((total + (col_count - 1) * 3))  # separators
    printf "  ─"
    for ((i = 0; i < total; i++)); do printf "─"; done
    echo ""

    # --- print rows ---
    for ((idx = 0; idx < count; idx++)); do
        cells=()
        for ((c = 0; c < col_count; c++)); do
            local val=""
            case $c in
                0) # Project (+ [local] banner)
                    local display_name="${names[$idx]}"
                    if [ "${local_flags[$idx]}" = "true" ]; then
                        local plain="${display_name} [local]"
                        local padded=$(printf "%-*s" "${widths[0]}" "$plain")
                        padded="${padded/\[local\]/${GRAY}[local]${RESET}}"
                        val="$padded"
                    else
                        val=$(printf "%-*s" "${widths[0]}" "$display_name")
                    fi
                    ;;
                1) # Branch (centered -)
                    local bv="${branches[$idx]}"
                    if [ -z "$bv" ]; then
                        local w=${widths[1]}
                        local left=$(( (w - 1) / 2 ))
                        local right=$(( w - 1 - left ))
                        val=$(printf "%*s-%*s" $left "" $right "")
                    else
                        val=$(printf "%-*s" "${widths[1]}" "$bv")
                    fi
                    ;;
                2) # Status (colored, pre-padded)
                    local sv=""
                    case "${statuses[$idx]}" in
                        clean)  sv="● clean" ;;
                        dirty)  sv="● dirty" ;;
                        no-git) sv="no git" ;;
                    esac
                    local padded=$(printf "%-*s" "${widths[2]}" "$sv")
                    case "${statuses[$idx]}" in
                        clean)  val="\e[32m${padded}\e[0m" ;;
                        dirty)  val="\e[1;31m${padded}\e[0m" ;;
                        no-git) val="\e[33m${padded}\e[0m" ;;
                    esac
                    ;;
                3) # Stash (right-aligned)
                    val=$(printf "%*s" "${widths[3]}" "${stashes[$idx]}")
                    ;;
                4) # Remote (centered -)
                    local rv="${remotes[$idx]}"
                    if [ "$rv" = "-" ]; then
                        local w=${widths[4]}
                        local left=$(( (w - 1) / 2 ))
                        local right=$(( w - 1 - left ))
                        val=$(printf "%*s-%*s" $left "" $right "")
                    else
                        val=$(printf "%-*s" "${widths[4]}" "$rv")
                    fi
                    ;;
                5) # Last Commit (centered --)
                    local tv="${time_strs[$idx]}"
                    if [ -z "$tv" ]; then
                        local w=${widths[5]}
                        local left=$(( (w - 2) / 2 ))
                        local right=$(( w - 2 - left ))
                        local padded=$(printf "%*s--%*s" $left "" $right "")
                        val="\e[33m${padded}\e[0m"
                    else
                        val="$tv"
                    fi
                    ;;
            esac
            cells+=("$val")
        done
        printf "$row_fmt" "${cells[@]}"
    done
    echo ""
}
