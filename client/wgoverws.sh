#!/bin/bash

launch_wstunnel () {
    local remote_host=${REMOTE_HOST:-""}
    local remote_ip=${REMOTE_IP:-${REMOTE_HOST}}
    local rport=${REMOTE_PORT:-51820}
    local wsport=${WS_PORT:-443}
    local lport=${LOCAL_PORT:-${rport}}
    local prefix=${WS_PREFIX:-"wstunnel"}
    local cmd=${WSTUNNEL_CMD:-"wstunnel"}
    local wsping=${WS_PING:-30}
#    local log_file="/dev/null"
    local log_file="$HOME/.wstunnel/$1.log"

    env WSTUNNEL_HTTP_UPGRADE_PATH_PREFIX="${prefix}" nohup "$cmd" \
      client -L "udp://127.0.0.1:${lport}:127.0.0.1:${rport}?timeout_sec=0" "wss://${remote_ip}:${wsport}" \
      --tls-verify-certificate \
      --tls-sni-override "${remote_host}" \
      --http-headers "Host: ${remote_host}" \
      --websocket-ping-frequency-sec "${wsping}" > "${log_file}" 2>&1 &
    echo "$!"
}

pre_up () {
    local server_tag=$1
    local cfg="$HOME/.wstunnel/${server_tag}.wstunnel"

    if [[ -f "${cfg}" ]]; then
        # shellcheck disable=SC1090
        source "${cfg}"
    else
        echo "[#] Missing config file: ${cfg}"
        exit 1
    fi

    local remote_ip=${REMOTE_IP:-${REMOTE_HOST}}
    local gw wstunnel_pid

    # Find out current route to ${remote_ip} and make it explicit
    gw=$(route -n get "${remote_ip}" | grep -Eo "gateway:.+$" | awk '{print $2}')
    route -n add -net "${remote_ip}" "${gw}" > /dev/null 2>&1 || true
    # Route add on pre-up
    route_add_on_pre_up "${server_tag}" "${gw}"
    # Start wstunnel in the background
    wstunnel_pid=$(launch_wstunnel "${server_tag}")

    # save state
    echo "${wstunnel_pid}" > "$HOME/.wstunnel/${server_tag}.wstunnel.pid"
}

post_up () {
    local tun=$1
    # Add IPv4 routes
    route add -net 0.0.0.0/1 -interface "${tun}" > /dev/null 2>&1
    route add -net 128.0.0.0/1 -interface "${tun}" > /dev/null 2>&1

    # Add IPv6 routes
    route add -inet6 -net ::0/1 -interface "${tun}" > /dev/null 2>&1
    route add -inet6 -net 8000::/1 -interface "${tun}" > /dev/null 2>&1
}

post_down () {
    local server_tag=$1
    local cfg="$HOME/.wstunnel/${server_tag}.wstunnel"

    if [[ -f "${cfg}" ]]; then
        # shellcheck disable=SC1090
        source "${cfg}"
    else
        echo "[#] Missing config file: ${cfg}"
        exit 1
    fi

    local pid_file="$HOME/.wstunnel/${server_tag}.wstunnel.pid"
    local wstunnel_pid
    local remote_ip=${REMOTE_IP:-${REMOTE_HOST}}

    if [[ -f "${pid_file}" ]]; then
        read -r wstunnel_pid < "${pid_file}"
        rm "${pid_file}"
        kill -TERM "${wstunnel_pid}" > /dev/null 2>&1 || true
    else
        killall wstunnel > /dev/null 2>&1 || true
    fi

    if [[ -n "${remote_ip}" ]]; then
        route -n delete "${remote_ip}" > /dev/null 2>&1 || true
    fi
    # Route delete on post-down
    route_delete_on_post_down "${server_tag}"
    sleep 0.1
    # Set DNS back
    echo "[#] networksetup -setdnsservers Wi-Fi 223.5.5.5 119.29.29.29"
    networksetup -setdnsservers Wi-Fi 223.5.5.5 119.29.29.29 > /dev/null 2>&1 || true
}

route_add_on_pre_up () {
    local server_tag=$1
    local gw=$2
    local route_file="$HOME/.wstunnel/${server_tag}.route"

    # Check if the file exists
    if [ -f "$route_file" ]; then
        # Read the file line by line
        while IFS= read -r line; do
            # Route add
            echo "[#] route -n add -net ${line} ${gw}"
            route -n add -net "${line}" "${gw}" > /dev/null 2>&1 || true
        done < "$route_file"
    fi
}

route_delete_on_post_down () {
    local server_tag=$1
    local route_file="$HOME/.wstunnel/${server_tag}.route"

    # Check if the file exists
    if [ -f "$route_file" ]; then
        # Read the file line by line
        while IFS= read -r line; do
            # Route delete
            echo "[#] route -n delete ${line}"
            route -n delete "${line}" > /dev/null 2>&1 || true
        done < "$route_file"
    fi
}
