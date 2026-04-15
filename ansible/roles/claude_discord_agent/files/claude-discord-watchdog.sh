#!/usr/bin/env bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# claude-discord-watchdog.sh
#
# Detects silent Discord-gateway failures in the claude-discord-agent and
# restarts the service when the bot has gone deaf. The outer claude process
# and systemd unit stay "active" when the in-process Discord WebSocket dies
# without reconnecting, so we probe the actual network path instead.
#
# Two independent probes must both fail CONSECUTIVE_FAILURES times in a row
# before we restart:
#   1. REST probe       - GET /users/@me with the bot token. Proves the token
#                         still works and Discord's API is reachable.
#   2. Gateway TCP probe - look for an ESTABLISHED socket from the bun MCP
#                         server to Discord's gateway range (162.159.0.0/16).
#
# State is tracked in $STATE_FILE so a single transient blip does not bounce
# the agent.
#
# Exits 0 on success (healthy or intentionally skipped). Non-zero only on
# unexpected failures (e.g., token file missing) — in which case the systemd
# unit will surface the error.

set -euo pipefail

# ============================================================================
# Config (overridable via environment — set in the .service unit)
# ============================================================================
SERVICE_NAME="${SERVICE_NAME:-claude-discord-agent}"
TOKEN_FILE="${TOKEN_FILE:-$HOME/.claude/channels/discord/.env}"
STATE_FILE="${STATE_FILE:-$HOME/.local/state/claude-discord-watchdog.state}"
CONSECUTIVE_FAILURES="${CONSECUTIVE_FAILURES:-3}"
REST_TIMEOUT="${REST_TIMEOUT:-10}"
# Discord's gateway and API both sit behind Cloudflare. 162.159.0.0/16 is
# Cloudflare's range used by gateway.discord.gg.
GATEWAY_CIDR_PREFIX="${GATEWAY_CIDR_PREFIX:-162.159.}"

mkdir -p "$(dirname "$STATE_FILE")"

log() { printf '[%s] %s\n' "$(date -Iseconds)" "$*"; }

# ============================================================================
# Preconditions
# ============================================================================
if ! systemctl --user is-active --quiet "$SERVICE_NAME"; then
    log "service $SERVICE_NAME is not active — nothing to watchdog"
    : > "$STATE_FILE" 2>/dev/null || true
    exit 0
fi

if [[ ! -r "$TOKEN_FILE" ]]; then
    log "ERROR: token file $TOKEN_FILE not readable"
    exit 2
fi

# shellcheck disable=SC1090
source "$TOKEN_FILE"
if [[ -z "${DISCORD_BOT_TOKEN:-}" ]]; then
    log "ERROR: DISCORD_BOT_TOKEN not set in $TOKEN_FILE"
    exit 2
fi

# ============================================================================
# Probes
# ============================================================================
probe_rest() {
    # Hit /users/@me; expect HTTP 200. Anything else (or timeout) = fail.
    local code
    code=$(curl -sS -o /dev/null -w '%{http_code}' \
        --max-time "$REST_TIMEOUT" \
        -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
        -H 'User-Agent: miket-phc-watchdog/1.0' \
        'https://discord.com/api/v10/users/@me' 2>/dev/null || echo "000")
    [[ "$code" == "200" ]]
}

probe_gateway_tcp() {
    # Look for any ESTABLISHED TCP socket from the bun MCP server (or any
    # child of the claude-discord-agent cgroup) to Discord's Cloudflare range.
    # ss output column 5 is peer address:port.
    ss -tnp 2>/dev/null \
        | awk -v prefix="$GATEWAY_CIDR_PREFIX" '
            /ESTAB/ && $5 ~ ":443$" && index($5, prefix) == 1 { found=1 }
            END { exit found ? 0 : 1 }
        '
}

# ============================================================================
# Evaluate and act
# ============================================================================
rest_ok=0; gateway_ok=0
probe_rest && rest_ok=1 || true
probe_gateway_tcp && gateway_ok=1 || true

prev_fails=0
if [[ -s "$STATE_FILE" ]]; then
    prev_fails=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
    [[ "$prev_fails" =~ ^[0-9]+$ ]] || prev_fails=0
fi

if (( rest_ok && gateway_ok )); then
    if (( prev_fails > 0 )); then
        log "healthy (rest=ok gateway=ok) — clearing $prev_fails prior failures"
    fi
    : > "$STATE_FILE"
    exit 0
fi

fails=$(( prev_fails + 1 ))
echo "$fails" > "$STATE_FILE"
log "unhealthy (rest=$rest_ok gateway=$gateway_ok) — consecutive failures: $fails/$CONSECUTIVE_FAILURES"

if (( fails < CONSECUTIVE_FAILURES )); then
    exit 0
fi

log "restarting $SERVICE_NAME after $fails consecutive unhealthy checks"
systemctl --user restart "$SERVICE_NAME"
: > "$STATE_FILE"
log "restart issued; state cleared"
