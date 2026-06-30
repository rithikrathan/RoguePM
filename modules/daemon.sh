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

            local hostnames=() uids=() ipv4s=() statuses=()
            while IFS=$'\t' read -r hostname uid ipv4 status; do
                hostnames+=("$hostname")
                uids+=("$uid")
                ipv4s+=("$ipv4")
                statuses+=("$status")
            done < <(echo "$response" | jq -r '
                .[]
                | [.hostname, (.uid | tostring), .ipv4, .status]
                | @tsv
            ')
            local count=${#hostnames[@]}

            _center() { local t="$1" w="$2"; local l=${#t}; if [ "$l" -ge "$w" ]; then printf "%s" "$t"; else local p=$(( (w - l) / 2 )); printf "%*s%s%*s" "$p" "" "$t" "$((w - l - p))" ""; fi; }

            local col_headers=("Hostname" "UID" "IPv4" "Status")
            local col_count=4
            local widths=()
            for ((c = 0; c < col_count; c++)); do
                widths[$c]=${#col_headers[$c]}
            done
            for ((idx = 0; idx < count; idx++)); do
                [ ${#hostnames[$idx]} -gt ${widths[0]} ] && widths[0]=${#hostnames[$idx]}
                [ ${#uids[$idx]} -gt ${widths[1]} ] && widths[1]=${#uids[$idx]}
                [ ${#ipv4s[$idx]} -gt ${widths[2]} ] && widths[2]=${#ipv4s[$idx]}
                [ ${#statuses[$idx]} -gt ${widths[3]} ] && widths[3]=${#statuses[$idx]}
            done

            local row_fmt="  "
            for ((c = 0; c < col_count; c++)); do
                [ $c -gt 0 ] && row_fmt+=" | "
                row_fmt+="%b"
            done
            row_fmt+="\n"

            local cells=()
            cells+=("$(printf "%-*s" "${widths[0]}" "${col_headers[0]}")")
            for ((c = 1; c < col_count; c++)); do
                cells+=("$(_center "${col_headers[$c]}" "${widths[$c]}")")
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

            for ((idx = 0; idx < count; idx++)); do
                cells=()
                cells+=("$(printf "%-*s" "${widths[0]}" "${hostnames[$idx]}")")
                cells+=("$(_center "${uids[$idx]}" "${widths[1]}")")
                cells+=("$(_center "${ipv4s[$idx]}" "${widths[2]}")")
                cells+=("$(_center "${statuses[$idx]}" "${widths[3]}")")
                printf "$row_fmt" "${cells[@]}"
            done
            echo ""
            unset -f _center
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

            local device_ids=() hostnames=() ips=()
            while IFS=$'\t' read -r device_id hostname ip; do
                device_ids+=("$device_id")
                hostnames+=("$hostname")
                ips+=("$ip")
            done < <(echo "$response" | jq -r '
                .res[]
                | [.device_id, .hostname, .ip]
                | @tsv
            ')
            local count=${#device_ids[@]}

            local col_headers=("Device ID" "Hostname" "IP")
            local col_align=("l" "l" "l")
            local col_count=3
            local widths=()
            for ((c = 0; c < col_count; c++)); do
                widths[$c]=${#col_headers[$c]}
            done
            for ((idx = 0; idx < count; idx++)); do
                [ ${#device_ids[$idx]} -gt ${widths[0]} ] && widths[0]=${#device_ids[$idx]}
                [ ${#hostnames[$idx]} -gt ${widths[1]} ] && widths[1]=${#hostnames[$idx]}
                [ ${#ips[$idx]} -gt ${widths[2]} ] && widths[2]=${#ips[$idx]}
            done

            local row_fmt="  "
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
            printf "  ─"
            for ((i = 0; i < total; i++)); do printf "─"; done
            echo ""

            for ((idx = 0; idx < count; idx++)); do
                cells=()
                for ((c = 0; c < col_count; c++)); do
                    case $c in
                        0) cells+=("$(printf "%-*s" "${widths[0]}" "${device_ids[$idx]}")") ;;
                        1) cells+=("$(printf "%-*s" "${widths[1]}" "${hostnames[$idx]}")") ;;
                        2) cells+=("$(printf "%-*s" "${widths[2]}" "${ips[$idx]}")") ;;
                    esac
                done
                printf "$row_fmt" "${cells[@]}"
            done
            echo ""
            ;;

        *)
            rogued_log_error "Unknown daemon command: $sub"
            echo -e "  Run ${BOLD}rogue daemon --help${RESET} for usage."
            return 1
            ;;
    esac
}
