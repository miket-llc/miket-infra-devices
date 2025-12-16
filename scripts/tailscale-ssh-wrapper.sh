#!/bin/bash
# Wrapper script to make Ansible work with Tailscale SSH
# Translates Ansible's ssh command into tailscale ssh

# Parse arguments - Ansible passes: ssh [options] user@host command
# We need to extract host and pass the rest to tailscale ssh

args=()
user=""
host=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -o)
            # Skip SSH options that don't apply to tailscale ssh
            shift 2
            ;;
        -C|-T|-q)
            # Skip single-char options
            shift
            ;;
        -l)
            user="$2"
            shift 2
            ;;
        *@*)
            # user@host format
            user="${1%@*}"
            host="${1#*@}"
            shift
            ;;
        -*)
            # Skip other options
            shift
            ;;
        *)
            # Assume this is the host or command
            if [[ -z "$host" ]]; then
                host="$1"
            else
                args+=("$1")
            fi
            shift
            ;;
    esac
done

# Build tailscale ssh command
if [[ -n "$user" ]]; then
    target="${user}@${host}"
else
    target="$host"
fi

exec tailscale ssh "$target" "${args[@]}"
