# ==========================================
# MODULE: TEMPLATE
# ==========================================

cmd_template() {
    local subcommand="$1"
    shift 2>/dev/null || true

    case "$subcommand" in
        list|--list|-l|"")
            cmd_template_list
            ;;
        tree|--tree|-t)
            cmd_template_tree "$1"
            ;;
        --help|-h)
            echo -e "\n${ROGUE_RED_ITALIC}[Rogue]${RESET} ${BOLD}TEMPLATE COMMAND USAGE${RESET}"
            echo -e "source rogue template [action]\n"
            echo -e "  ${BOLD}list${RESET}        List all available templates"
            echo -e "  ${BOLD}tree <name>${RESET}  Show file tree for a template"
            return 0 ;;
        *)
            log_error "Unknown template action: $subcommand"
            echo -e "  Run ${BOLD}source rogue template --help${RESET} for usage."
            return 1 ;;
    esac
}

cmd_template_list() {
    echo -e "\n────────────────────────────────────────────"
    echo -e "${ROGUE_RED_ITALIC}[Rogue]${RESET} ${BOLD_ITALIC_UNDERLINE}Available Templates${RESET}\n"

    local templates_dir=""
    if [ -d "$ROGUE_DIR/RogueTemplates" ]; then
        templates_dir="$ROGUE_DIR/RogueTemplates"
    elif [ -d "$HOME/.config/rogue/templates" ]; then
        templates_dir="$HOME/.config/rogue/templates"
    else
        log_error "Templates directory not found."
        return 1
    fi

    local count=0
    for dir in "$templates_dir"/*/; do
        if [ -d "$dir" ] && [ -f "$dir/$(basename "$dir").sh" ]; then
            local name
            name=$(basename "$dir")
            local has_files="no"
            [ -d "$dir/files" ] && [ "$(ls -A "$dir/files" 2>/dev/null)" ] && has_files="yes"
            echo -e "  ${BOLD}$name${RESET}"
            count=$((count + 1))
        fi
    done

    echo ""
    log_step "$count templates available."
}

cmd_template_tree() {
    local template_name="$1"

    if [ -z "$template_name" ]; then
        log_error "Template name is required."
        echo -e "  Usage: ${BOLD}source rogue template tree <name>${RESET}"
        return 1
    fi

    local templates_dir=""
    if [ -d "$ROGUE_DIR/RogueTemplates" ]; then
        templates_dir="$ROGUE_DIR/RogueTemplates"
    elif [ -d "$HOME/.config/rogue/templates" ]; then
        templates_dir="$HOME/.config/rogue/templates"
    else
        log_error "Templates directory not found."
        return 1
    fi

    local template_path="$templates_dir/$template_name"
    if [ ! -d "$template_path" ]; then
        log_error "Template '$template_name' not found."
        echo -e "  Run ${BOLD}source rogue template list${RESET} to see available templates."
        return 1
    fi

    echo -e "\n────────────────────────────────────────────"
    echo -e "${ROGUE_RED_ITALIC}[Rogue]${RESET} ${BOLD_ITALIC_UNDERLINE}Template: $template_name${RESET}\n"

    echo -e "  ${template_name}.sh"
    if [ -d "$template_path/files" ] && [ "$(ls -A "$template_path/files" 2>/dev/null)" ]; then
        if command -v tree &> /dev/null; then
            tree "$template_path/files" --charset utf-8 --noreport | sed "s|$template_path/files/||" | sed "s|$template_path/files|  files/|"
        else
            echo "  files/"
            find "$template_path/files" -type f | while read -r f; do
                echo "    $(basename "$f")"
            done
        fi
    else
        echo "  (no additional files)"
    fi
}
