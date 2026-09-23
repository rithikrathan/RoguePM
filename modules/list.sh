# ==========================================
# MODULE: LIST
# ==========================================

cmd_list() {
    # If native rogue-core binary is available, execute it directly for maximum speed
    local core_bin=""
    if command -v rogue-core &>/dev/null; then
        core_bin="rogue-core"
    elif [ -x "$HOME/.local/bin/rogue-core" ]; then
        core_bin="$HOME/.local/bin/rogue-core"
    elif [ -n "$ROGUE_DIR" ] && [ -x "$ROGUE_DIR/bin/rogue-core" ]; then
        core_bin="$ROGUE_DIR/bin/rogue-core"
    fi

    if [ -n "$core_bin" ]; then
        "$core_bin" list "$@"
        return $?
    fi

    local filter_name=""
    local filter_status=""
    local filter_branch=""
    local filter_remote=""
    local filter_ws=""
    local filter_orphan="false"
    local show_all="false"

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
            -w|--ws|--workspace)
                [ -z "$2" ] || [[ "$2" == -* ]] && { log_error "--ws requires a workspace name"; return 1; }
                filter_ws="$2"; shift 2 ;;
            --orphan|--orphans)
                filter_orphan="true"; shift ;;
            -a|--all)
                show_all="true"; shift ;;
            --dirty) filter_status="dirty"; shift ;;
            --help|-h)
                echo -e "\n${ROGUE_RED_ITALIC}[Rogue]${RESET} ${BOLD}LIST COMMAND USAGE${RESET}"
                echo -e "source rogue list [options]\n"
                echo -e "  -w, --ws <name>                 List projects in a specific workspace"
                echo -e "  --orphan                        List only orphan / standalone local projects"
                echo -e "  -a, --all                       Show all projects including hidden/archived"
                echo -e "  -f, --filter <text>             Filter projects by name substring"
                echo -e "  -fb, --filter-branch <branch>   Filter projects by branch name"
                echo -e "  -fr, --filter-remote <text>     Filter projects by remote URL substring"
                echo -e "  -fs, --filter-status <s>        Filter by status: clean, dirty, no-git"
                echo -e "  --dirty                         Shorthand for --filter-status dirty"
                return 0 ;;
            *) log_error "Unknown option: $1"; return 1 ;;
        esac
    done

    local json_file="${ROGUE_CONFIG:-$HOME/.config/rogue/rogueConf.json}"
    local list_file="${LOCAL_PROJECTS_LIST:-$HOME/.config/rogue/rp.list}"

    declare -a ws_names=() ws_paths=() ws_orgs=() ws_hidden=()
    if [ -f "$json_file" ] && command -v jq &>/dev/null; then
        while IFS=$'\t' read -r w_name w_path w_org w_hide; do
            [ -n "$w_name" ] && [ "$w_name" != "null" ] || continue
            ws_names+=("$w_name")
            ws_paths+=("${w_path/#\~/$HOME}")
            ws_orgs+=("$w_org")
            ws_hidden+=("$w_hide")
        done < <(jq -r '.workspaces[]? | [ .name, .path, (.gh_org // "-"), (.hidden // false) ] | @tsv' "$json_file" 2>/dev/null)
    fi

    # Helper function to render a table for a list of directories
    _render_project_table() {
        local section_title="$1"
        shift
        local dirs=("$@")

        [ ${#dirs[@]} -eq 0 ] && return 0

        declare -a names branches statuses stashes remotes time_strs

        for dir in "${dirs[@]}"; do
            [ -d "$dir" ] || continue
            local name=$(basename "$dir")

            if [ -n "$filter_name" ]; then
                local name_lower="${name,,}" filter_lower="${filter_name,,}"
                [[ "$name_lower" != *"$filter_lower"* ]] && continue
            fi

            local branch="" dirty="" stash_count=0 remote_str="-" time_str=""

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
        done

        local count=${#names[@]}
        [ "$count" -eq 0 ] && return 0

        echo -e "\n  ${ROGUE_RED_SOLID}◆${RESET} ${BOLD}$section_title${RESET}"

        local col_headers=("Project" "Branch" "Status" "Stash" "Remote" "Last Commit")
        local col_align=("l" "l" "l" "r" "l" "l")
        local col_count=6

        local widths=()
        for ((c = 0; c < col_count; c++)); do
            widths[$c]=${#col_headers[$c]}
        done

        for ((idx = 0; idx < count; idx++)); do
            local display_name="${names[$idx]}"
            [ ${#display_name} -gt ${widths[0]} ] && widths[0]=${#display_name}

            local bv="${branches[$idx]}"
            [ -z "$bv" ] && bv="-"
            [ ${#bv} -gt ${widths[1]} ] && widths[1]=${#bv}

            local sv=""
            case "${statuses[$idx]}" in
                clean)  sv="● clean" ;;
                dirty)  sv="● dirty" ;;
                no-git) sv="no git" ;;
            esac
            [ ${#sv} -gt ${widths[2]} ] && widths[2]=${#sv}

            [ ${#stashes[$idx]} -gt ${widths[3]} ] && widths[3]=${#stashes[$idx]}
            [ ${#remotes[$idx]} -gt ${widths[4]} ] && widths[4]=${#remotes[$idx]}

            local tv="${time_strs[$idx]}"
            [ -z "$tv" ] && tv="--"
            [ ${#tv} -gt ${widths[5]} ] && widths[5]=${#tv}
        done

        local row_fmt="    "
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
        printf "    ─"
        for ((i = 0; i < total; i++)); do printf "─"; done
        echo ""

        for ((idx = 0; idx < count; idx++)); do
            cells=()
            for ((c = 0; c < col_count; c++)); do
                local val=""
                case $c in
                    0) val=$(printf "%-*s" "${widths[0]}" "${names[$idx]}") ;;
                    1)
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
                    2)
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
                    3) val=$(printf "%*s" "${widths[3]}" "${stashes[$idx]}") ;;
                    4)
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
                    5)
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
    }

    echo -e "${ROGUE_RED_ITALIC}[Rogue]${RESET} ${BOLD_ITALIC}Listing Projects...${RESET}"

    # If --orphan flag is passed, only list orphans
    if [ "$filter_orphan" = "true" ]; then
        declare -a orphan_dirs=()
        if [ -f "$list_file" ]; then
            while IFS= read -r line; do
                [ -z "$line" ] && continue
                local l_path="${line%|*}"
                local l_ws=""
                [[ "$line" == *"|"* ]] && l_ws="${line#*|}"
                if [ -z "$l_ws" ] || [ "$l_ws" = "$line" ]; then
                    [ -d "$l_path" ] && orphan_dirs+=("$l_path")
                fi
            done < "$list_file"
        fi
        _render_project_table "STANDALONE / ORPHAN PROJECTS (${list_file})" "${orphan_dirs[@]}"
        echo ""
        return 0
    fi

    # If --ws flag is passed, only list that workspace
    if [ -n "$filter_ws" ]; then
        local found_ws_path=""
        local found_ws_org=""
        for i in "${!ws_names[@]}"; do
            if [ "${ws_names[$i]}" = "$filter_ws" ]; then
                found_ws_path="${ws_paths[$i]}"
                found_ws_org="${ws_orgs[$i]}"
                break
            fi
        done

        if [ -z "$found_ws_path" ] && [ -d "$PROJECTS_DIR/$filter_ws" ]; then
            found_ws_path="$PROJECTS_DIR/$filter_ws"
        fi

        declare -a ws_dirs=()
        if [ -d "$found_ws_path" ]; then
            for d in "$found_ws_path"/*/; do
                [ -d "$d" ] && ws_dirs+=("$d")
            done
        fi
        if [ -f "$list_file" ]; then
            while IFS= read -r line; do
                [ -z "$line" ] && continue
                local l_path="${line%|*}"
                local l_ws="${line#*|}"
                if [ "$l_ws" = "$filter_ws" ] && [ -d "$l_path" ]; then
                    ws_dirs+=("$l_path")
                fi
            done < "$list_file"
        fi

        local title="WORKSPACE: $filter_ws"
        [ -n "$found_ws_org" ] && [ "$found_ws_org" != "-" ] && title+=" [Org: $found_ws_org]"
        title+=" ($found_ws_path)"
        _render_project_table "$title" "${ws_dirs[@]}"
        echo ""
        return 0
    fi

    # Default Full Tree Listing:
    # 1. Default Root Projects ($PROJECTS_DIR) - TOP
    declare -a default_dirs=()
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
                if [ "$is_ws" = false ]; then
                    default_dirs+=("$dir")
                fi
            fi
        done
    fi
    _render_project_table "DEFAULT PROJECTS ($PROJECTS_DIR)" "${default_dirs[@]}"

    # 2. Registered Workspaces - MIDDLE
    for i in "${!ws_names[@]}"; do
        local w_name="${ws_names[$i]}"
        local w_path="${ws_paths[$i]}"
        local w_org="${ws_orgs[$i]}"
        local w_hide="${ws_hidden[$i]}"

        if [ "$w_hide" = "true" ] && [ "$show_all" != "true" ]; then
            continue
        fi

        declare -a curr_ws_dirs=()
        if [ -d "$w_path" ]; then
            for d in "$w_path"/*/; do
                [ -d "$d" ] && curr_ws_dirs+=("$d")
            done
        fi

        if [ -f "$list_file" ]; then
            while IFS= read -r line; do
                [ -z "$line" ] && continue
                local l_path="${line%|*}"
                local l_ws="${line#*|}"
                if [ "$l_ws" = "$w_name" ] && [ -d "$l_path" ]; then
                    curr_ws_dirs+=("$l_path")
                fi
            done < "$list_file"
        fi

        local title="WORKSPACE: $w_name"
        [ -n "$w_org" ] && [ "$w_org" != "-" ] && title+=" [GitHub Org: $w_org]"
        title+=" ($w_path)"
        _render_project_table "$title" "${curr_ws_dirs[@]}"
    done

    # 3. Orphan Projects from rp.list - BOTTOM
    declare -a orphan_dirs=()
    if [ -f "$list_file" ]; then
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            local l_path="${line%|*}"
            local l_ws=""
            [[ "$line" == *"|"* ]] && l_ws="${line#*|}"
            if [ -z "$l_ws" ] || [ "$l_ws" = "$line" ]; then
                [ -d "$l_path" ] && orphan_dirs+=("$l_path")
            fi
        done < "$list_file"
    fi
    _render_project_table "STANDALONE / ORPHAN PROJECTS (${list_file})" "${orphan_dirs[@]}"

    echo ""
}
