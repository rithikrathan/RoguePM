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

print_daemon_help() {
    echo -e "\n${ROGUE_RED_ITALIC}[Rogue]${RESET} ${BOLD}DAEMON COMMAND USAGE${RESET}"
    echo -e "source rogue daemon [action]\n"
    echo -e "  ${BOLD}ping${RESET}           Check if daemon is running"
    echo -e "  ${BOLD}discover${RESET}       List mDNS-discovered peers"
    echo -e "  ${BOLD}pair <host>${RESET}    Initiate pairing with a peer"
    echo -e "  ${BOLD}accept <host>${RESET}  Accept a pending pairing request"
    echo -e "  ${BOLD}reject <host>${RESET}  Reject a pending pairing request"
    echo -e "  ${BOLD}forget <host>${RESET}  Remove a paired peer"
    echo -e "  ${BOLD}pending${RESET}        List pending pairing requests"
}

print_daemon_table() {
    local col_headers=("$@")
    local col_count=${#col_headers[@]}
    local col_align=()
    local data=()

    local reading_data=false
    local data_start=0
    for ((i = 0; i < col_count; i++)); do
        col_align[$i]="l"
    done

    shift $col_count
    local rows=("$@")
    local row_count=${#rows[@]}

    local widths=()
    for ((c = 0; c < col_count; c++)); do
        widths[$c]=${#col_headers[$c]}
    done

    for ((idx = 0; idx < row_count; idx++)); do
        IFS=$'\t' read -ra vals <<< "${rows[$idx]}"
        for ((c = 0; c < col_count; c++)); do
            [ ${#vals[$c]} -gt ${widths[$c]} ] && widths[$c]=${#vals[$c]}
        done
    done

    local row_fmt="  "
    for ((c = 0; c < col_count; c++)); do
        [ $c -gt 0 ] && row_fmt+=" | "
        row_fmt+="%b"
    done
    row_fmt+="\n"

    local cells=()
    for ((c = 0; c < col_count; c++)); do
        cells+=("$(printf "%-*s" "${widths[$c]}" "${col_headers[$c]}")")
    done
    printf "$row_fmt" "${cells[@]}"

    local total=0
    for ((c = 0; c < col_count; c++)); do
        total=$((total + widths[c]))
    done
    total=$((total + (col_count - 1) * 3))
    printf "  ─"
    for ((i = 0; i < total; i++)); do printf "─"; done
    echo ""

    for ((idx = 0; idx < row_count; idx++)); do
        cells=()
        IFS=$'\t' read -ra vals <<< "${rows[$idx]}"
        for ((c = 0; c < col_count; c++)); do
            cells+=("$(printf "%-*s" "${widths[$c]}" "${vals[$c]}")")
        done
        printf "$row_fmt" "${cells[@]}"
    done
}

cmd_daemon() {
    local sub="$1"; shift

    case "$sub" in
        --help|-h)
            print_daemon_help
            ;;

        "")
            print_daemon_help
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
            local rows=()
            while IFS=$'\t' read -r hostname ip; do
                rows+=("$hostname"$'\t'"$ip")
            done < <(echo "$response" | jq -r '
                to_entries[]
                | [ (.key | split(".")[0]), .value ]
                | @tsv
            ')
            print_daemon_table "Peer" "IP" "${rows[@]}"
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
            local rows=()
            while IFS=$'\t' read -r device_id hostname ip; do
                rows+=("$device_id"$'\t'"$hostname"$'\t'"$ip")
            done < <(echo "$response" | jq -r '
                .res[]
                | [.device_id, .hostname, .ip]
                | @tsv
            ')
            print_daemon_table "Device ID" "Hostname" "IP" "${rows[@]}"
            echo ""
            ;;

        *)
            rogued_log_error "Unknown daemon command: $sub"
            echo -e "  Run ${BOLD}rogue daemon --help${RESET} for usage."
            return 1
            ;;
    esac
}
