# ==========================================
# MODULE: RESOLVE (Fuzzy Name Resolution)
# ==========================================

# Universal candidate resolver with fuzzy/substring matching and prompt
resolve_candidate() {
    local q="$1"
    local type_label="$2"
    local assume_yes="${3:-false}"
    shift 3
    local -a candidates=("$@")

    [ -z "$q" ] && return 1

    # 1. Exact match (case-sensitive)
    for cand in "${candidates[@]}"; do
        if [ "$cand" = "$q" ]; then
            echo "$cand"
            return 0
        fi
    done

    # 2. Use rogue-core match if available
    local -a matches=()
    local core_bin=""
    if command -v rogue-core &>/dev/null; then core_bin="rogue-core";
    elif [ -x "$HOME/.local/bin/rogue-core" ]; then core_bin="$HOME/.local/bin/rogue-core";
    elif [ -n "$ROGUE_DIR" ] && [ -x "$ROGUE_DIR/bin/rogue-core" ]; then core_bin="$ROGUE_DIR/bin/rogue-core"; fi

    if [ -n "$core_bin" ]; then
        mapfile -t matches < <("$core_bin" match "$q" "${candidates[@]}" 2>/dev/null)
    fi

    if [ ${#matches[@]} -eq 0 ]; then
        # Case-insensitive exact, substring, and subsequence matching (Bash fallback)
        local q_lower="${q,,}"
        local -a ci_exact=() substring=() subsequence=()

        local regex=".*"
        for (( i=0; i<${#q_lower}; i++ )); do
            local char="${q_lower:$i:1}"
            case "$char" in
                "["|"]"|"("|")"|"."|"*"|"+"|"?"|"^"|"$"|"\\") char="\\$char" ;;
            esac
            regex+="${char}.*"
        done

        for cand in "${candidates[@]}"; do
            [ -z "$cand" ] && continue
            local cand_lower="${cand,,}"
            if [ "$cand_lower" = "$q_lower" ]; then
                ci_exact+=("$cand")
            elif [[ "$cand_lower" == *"$q_lower"* ]]; then
                substring+=("$cand")
            elif [[ "$cand_lower" =~ $regex ]]; then
                subsequence+=("$cand")
            fi
        done

        if [ ${#ci_exact[@]} -gt 0 ]; then
            matches=("${ci_exact[@]}")
        elif [ ${#substring[@]} -gt 0 ]; then
            matches=("${substring[@]}")
        elif [ ${#subsequence[@]} -gt 0 ]; then
            matches=("${subsequence[@]}")
        fi
    fi

    if [ ${#matches[@]} -eq 0 ]; then
        echo -e "\e[1;3;31m[Rogue]\e[0m \e[33mError:\e[0m No $type_label found matching '$q'." >&2
        return 1
    fi

    if [ ${#matches[@]} -eq 1 ]; then
        local matched="${matches[0]}"
        if [ "$assume_yes" != "true" ]; then
            local yn=""
            local prompt_text="\e[1;3;31m[Rogue]\e[0m Matched $type_label '${BOLD}$matched${RESET}' (from '$q'). Proceed? [Y/n] "
            if [ -t 0 ] || [ -e /dev/tty ]; then
                read -r -p "$(echo -e "$prompt_text")" yn < /dev/tty 2>/dev/null || yn=""
            fi
            if [[ "$yn" =~ ^[Nn]$ ]]; then
                echo -e "\e[1;3;31m[Rogue]\e[0m Operation cancelled." >&2
                return 1
            fi
        fi
        echo "$matched"
        return 0
    else
        if [ "$assume_yes" == "true" ]; then
            echo "${matches[0]}"
            return 0
        fi
        echo -e "\n\e[1;3;31m[Rogue]\e[0m Multiple ${type_label}s matched '${BOLD}$q${RESET}':" >&2
        for i in "${!matches[@]}"; do
            echo -e "  $((i+1))) ${matches[$i]}" >&2
        done
        local choice=""
        local prompt_text="\e[1;3;31m[Rogue]\e[0m Select [1-${#matches[@]}] (or 'q' to cancel): "
        if [ -t 0 ] || [ -e /dev/tty ]; then
            read -r -p "$(echo -e "$prompt_text")" choice < /dev/tty 2>/dev/null || choice=""
        fi
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#matches[@]}" ]; then
            echo "${matches[$((choice-1))]}"
            return 0
        else
            echo -e "\e[1;3;31m[Rogue]\e[0m Operation cancelled." >&2
            return 1
        fi
    fi
}

resolve_workspace_name() {
    local q="$1"
    local assume_yes="${2:-false}"
    [ -z "$q" ] && return 1

    local json_file="${ROGUE_CONFIG:-$HOME/.config/rogue/rogueConf.json}"
    local -a ws_list=()

    if [ -f "$json_file" ] && command -v jq &>/dev/null; then
        while IFS= read -r name; do
            [ -n "$name" ] && [ "$name" != "null" ] && ws_list+=("$name")
        done < <(jq -r '.workspaces[]?.name // empty' "$json_file" 2>/dev/null)
    fi

    if [ -d "$PROJECTS_DIR/$q" ]; then
        local already=0
        for w in "${ws_list[@]}"; do [ "$w" = "$q" ] && already=1 && break; done
        [ $already -eq 0 ] && ws_list+=("$q")
    fi

    resolve_candidate "$q" "workspace" "$assume_yes" "${ws_list[@]}"
}

resolve_template_name() {
    local q="$1"
    local assume_yes="${2:-false}"
    [ -z "$q" ] && return 1

    local tpl_dir="${TEMPLATES_DIR:-$HOME/.config/rogue/templates}"
    [ ! -d "$tpl_dir" ] && [ -n "$ROGUE_DIR" ] && [ -d "$ROGUE_DIR/RogueTemplates" ] && tpl_dir="$ROGUE_DIR/RogueTemplates"
    local -a tpl_list=()

    if [ -d "$tpl_dir" ]; then
        for t in "$tpl_dir"/*; do
            if [ -d "$t" ]; then
                local bname="$(basename "$t")"
                tpl_list+=("$bname")
            fi
        done
    fi

    resolve_candidate "$q" "template" "$assume_yes" "${tpl_list[@]}"
}

resolve_project_name() {
    local q="$1"
    local source_ws="${2:-}"
    local assume_yes="${3:-false}"
    [ -z "$q" ] && return 1

    local json_file="${ROGUE_CONFIG:-$HOME/.config/rogue/rogueConf.json}"
    local list_file="${LOCAL_PROJECTS_LIST:-$HOME/.config/rogue/rp.list}"
    local -a proj_list=()

    if [ -n "$source_ws" ]; then
        local ws_path=""
        if [ -f "$json_file" ] && command -v jq &>/dev/null; then
            ws_path=$(jq -r --arg name "$source_ws" '.workspaces[]? | select(.name == $name) | .path // empty' "$json_file" 2>/dev/null)
        fi
        [ -z "$ws_path" ] && [ -d "$PROJECTS_DIR/$source_ws" ] && ws_path="$PROJECTS_DIR/$source_ws"
        ws_path="${ws_path/#\~/$HOME}"
        if [ -d "$ws_path" ]; then
            for p in "$ws_path"/*; do
                [ -d "$p" ] && proj_list+=("$(basename "$p")")
            done
        fi
    else
        if [ -d "$PROJECTS_DIR" ]; then
            for p in "$PROJECTS_DIR"/*; do
                if [ -d "$p" ]; then
                    local bname="$(basename "$p")"
                    local is_ws=0
                    if [ -f "$json_file" ] && command -v jq &>/dev/null; then
                        is_ws=$(jq -r --arg name "$bname" '[.workspaces[]? | select(.name == $name)] | length' "$json_file" 2>/dev/null)
                    fi
                    [ "$is_ws" = "0" ] || [ -z "$is_ws" ] && proj_list+=("$bname")
                fi
            done
        fi

        if [ -f "$json_file" ] && command -v jq &>/dev/null; then
            while IFS= read -r wpath; do
                wpath="${wpath/#\~/$HOME}"
                if [ -d "$wpath" ]; then
                    for p in "$wpath"/*; do
                        [ -d "$p" ] && proj_list+=("$(basename "$p")")
                    done
                fi
            done < <(jq -r '.workspaces[]?.path // empty' "$json_file" 2>/dev/null)
        fi

        if [ -f "$list_file" ]; then
            while IFS= read -r line; do
                [ -z "$line" ] && continue
                local l_path="${line%|*}"
                [ -d "$l_path" ] && proj_list+=("$(basename "$l_path")")
            done < "$list_file"
        fi
    fi

    declare -A seen_projs
    local -a unique_projs=()
    for p in "${proj_list[@]}"; do
        if [ -z "${seen_projs[$p]:-}" ]; then
            seen_projs["$p"]=1
            unique_projs+=("$p")
        fi
    done

    resolve_candidate "$q" "project" "$assume_yes" "${unique_projs[@]}"
}

resolve_archived_project() {
    local q="$1"
    local assume_yes="${2:-false}"
    [ -z "$q" ] && return 1

    local json_file="${ROGUE_CONFIG:-$HOME/.config/rogue/rogueConf.json}"
    local arch_dir=""
    if [ -f "$json_file" ] && command -v jq &>/dev/null; then
        arch_dir=$(jq -r '.workspaces[]? | select(.name == "Archived") | .path // empty' "$json_file" 2>/dev/null)
    fi
    [ -z "$arch_dir" ] && arch_dir="$PROJECTS_DIR/Archived"
    arch_dir="${arch_dir/#\~/$HOME}"

    local -a arch_list=()
    if [ -d "$arch_dir" ]; then
        for p in "$arch_dir"/*; do
            [ -d "$p" ] && arch_list+=("$(basename "$p")")
        done
    fi

    resolve_candidate "$q" "archived project" "$assume_yes" "${arch_list[@]}"
}
