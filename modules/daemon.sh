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

        ping)
            local response
            response=$(echo '{"request_type":"ping"}' | socat - UNIX-CONNECT:"$socketPath" 2>&1) || {
                rogued_log_error "Daemon not reachable at $socketPath"
                return 1
            }
            local message
            message=$(echo "$response" | jq -r '.res // empty')
            if [ -n "$message" ]; then
                rogued_log_info "$message"
            else
                rogued_log_error "Unexpected response: $response"
            fi
            ;;

        discover)
            local response
            response=$(echo '{"request_type":"discoverHost"}' | socat - UNIX-CONNECT:"$socketPath" 2>&1) || {
                rogued_log_error "Daemon not reachable at $socketPath"
                return 1
            }
            local peer_count
            peer_count=$(echo "$response" | jq 'length // 0')
            if [ -z "$peer_count" ] || [ "$peer_count" -eq 0 ]; then
                rogued_log_info "No peers discovered."
                return 0
            fi
            echo ""
            rogued_log_info "Discovered Peers"
            echo ""
            echo -e "  ${BOLD}Peer${RESET}                     ${BOLD}IP${RESET}"
            echo "  ─────────────────────────────────────"
            echo "$response" | jq -r '
                to_entries[]
                | [ (.key | split(".")[0]), .value ]
                | @tsv
            ' | while IFS=$'\t' read -r hostname ip; do
                printf "  %-25s %s\n" "$hostname" "$ip"
            done
            echo ""
            ;;

        pair)
            local hostname="$1"
            if [ -z "$hostname" ]; then
                rogued_log_error "Usage: rogue daemon pair <hostname>"
                return 1
            fi
            local response
            response=$(echo '{"request_type":"pair","hostname":"'"$hostname"'"}' | socat - UNIX-CONNECT:"$socketPath" 2>&1) || {
                rogued_log_error "Daemon not reachable at $socketPath"
                return 1
            }
            local message
            message=$(echo "$response" | jq -r '.res // empty')
            if [ -n "$message" ]; then
                rogued_log_info "$message"
            else
                rogued_log_error "Unexpected response: $response"
            fi
            ;;

        accept)
            local hostname="$1"
            if [ -z "$hostname" ]; then
                rogued_log_error "Usage: rogue daemon accept <hostname>"
                return 1
            fi
            local response
            response=$(echo '{"request_type":"accept","hostname":"'"$hostname"'"}' | socat - UNIX-CONNECT:"$socketPath" 2>&1) || {
                rogued_log_error "Daemon not reachable at $socketPath"
                return 1
            }
            local message
            message=$(echo "$response" | jq -r '.res // empty')
            if [ -n "$message" ]; then
                rogued_log_info "$message"
            else
                rogued_log_error "Unexpected response: $response"
            fi
            ;;

        reject)
            local hostname="$1"
            if [ -z "$hostname" ]; then
                rogued_log_error "Usage: rogue daemon reject <hostname>"
                return 1
            fi
            local response
            response=$(echo '{"request_type":"reject","hostname":"'"$hostname"'"}' | socat - UNIX-CONNECT:"$socketPath" 2>&1) || {
                rogued_log_error "Daemon not reachable at $socketPath"
                return 1
            }
            local message
            message=$(echo "$response" | jq -r '.res // empty')
            if [ -n "$message" ]; then
                rogued_log_info "$message"
            else
                rogued_log_error "Unexpected response: $response"
            fi
            ;;

        forget)
            local hostname="$1"
            if [ -z "$hostname" ]; then
                rogued_log_error "Usage: rogue daemon forget <hostname>"
                return 1
            fi
            local response
            response=$(echo '{"request_type":"forget","hostname":"'"$hostname"'"}' | socat - UNIX-CONNECT:"$socketPath" 2>&1) || {
                rogued_log_error "Daemon not reachable at $socketPath"
                return 1
            }
            local message
            message=$(echo "$response" | jq -r '.res // empty')
            if [ -n "$message" ]; then
                rogued_log_info "$message"
            else
                rogued_log_error "Unexpected response: $response"
            fi
            ;;

        pending)
            local response
            response=$(echo '{"request_type":"pending"}' | socat - UNIX-CONNECT:"$socketPath" 2>&1) || {
                rogued_log_error "Daemon not reachable at $socketPath"
                return 1
            }
            local count
            count=$(echo "$response" | jq '.res | length // 0')
            if [ -z "$count" ] || [ "$count" -eq 0 ]; then
                rogued_log_info "No pending pairings."
                return 0
            fi
            echo ""
            rogued_log_info "Pending Pairings"
            echo ""
            echo -e "  ${BOLD}Device ID${RESET}        ${BOLD}Hostname${RESET}           ${BOLD}IP${RESET}"
            echo "  ─────────────────────────────────────────────────────"
            echo "$response" | jq -r '
                .res[]
                | [.device_id, .hostname, .ip]
                | @tsv
            ' | while IFS=$'\t' read -r device_id hostname ip; do
                printf "  %-20s %-20s %s\n" "$device_id" "$hostname" "$ip"
            done
            echo ""
            ;;

        *)
            rogued_log_error "Unknown daemon command: $sub"
            echo -e "Usage: rogue daemon {ping|discover|pair|accept|reject|forget|pending}"
            return 1
            ;;
    esac
}
