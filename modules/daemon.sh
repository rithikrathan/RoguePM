# ==========================================
# MODULE: DAEMON
# ==========================================

socketPath="/tmp/rogued.sock"

rogued_log_info() {
    echo -e "${ROGUE_RED_ITALIC}[rogued]${RESET} $1"
}

rogued_log_success() {
    echo -e "${ROGUE_RED_ITALIC}[rogued]${RESET} ${GREEN}$1${RESET}"
}

rogued_log_error() {
    echo -e "${ROGUE_RED_ITALIC}[rogued]${RESET} ${YELLOW}Error:${RESET} $1" >&2
}

rogued_log_step() {
    echo -e "  ${ROGUE_RED_SOLID}◆${RESET} $1"
}

cmd_daemon() {
    local sub="$1"; shift

    case "$sub" in
        "")
            echo -e "Usage: rogue daemon {ping|discover|pair|accept|reject|forget|pending}"
            return 0
            ;;

        *)
            rogued_log_error "Unknown daemon command: $sub"
            echo -e "Usage: rogue daemon {ping|discover|pair|accept|reject|forget|pending}"
            return 1
            ;;
    esac
}
