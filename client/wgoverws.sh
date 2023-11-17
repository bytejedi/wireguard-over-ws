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

    nohup "$cmd" \
      client -L "udp://127.0.0.1:${lport}:127.0.0.1:${rport}?timeout_sec=0" "wss://${remote_ip}:${wsport}" \
      --tls-verify-certificate \
      --tls-sni-override "${remote_host}" \
      --http-upgrade-path-prefix "${prefix}" \
      --http-headers "Host: ${remote_host}" \
      --websocket-ping-frequency-sec "${wsping}" > /dev/null 2>&1 &
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
    # Start wstunnel in the background
    wstunnel_pid=$(launch_wstunnel)

    # save state
    echo "${wstunnel_pid}" > "$HOME/.wstunnel/${server_tag}.wstunnel.pid"
}

post_up () {
    local tun="$1"
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
}
