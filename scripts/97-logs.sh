#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 97-logs.sh — tail the kagent controller, the demo agent, and n8n logs.
#
# Usage: 97-logs.sh [kagent|agent|n8n]   (default: all, non-following snapshot)
#        97-logs.sh -f [target]          (-f follows; pick a single target)
# ---------------------------------------------------------------------------
set -euo pipefail
. "$(dirname "$0")/lib.sh"
ensure_env_file
load_env

CLUSTER="${KIND_CLUSTER_NAME:-kagent-n8n}"
CTX="kind-${CLUSTER}"
K="kubectl --context ${CTX}"
NS="${KAGENT_NAMESPACE:-kagent}"
AGENT="${AGENT_NAME:-a2a-demo-agent}"
COMPOSE_FILE="$REPO_ROOT/n8n/docker-compose.yaml"

FOLLOW=""
if [ "${1:-}" = "-f" ]; then FOLLOW="-f"; shift; fi
TARGET="${1:-all}"
TAIL="${TAIL:-100}"

show_kagent() {
  log "== kagent controller =="
  $K -n "$NS" logs ${FOLLOW} --tail="$TAIL" -l app.kubernetes.io/component=controller 2>/dev/null || warn "controller logs unavailable"
}
show_agent() {
  log "== agent ${AGENT} =="
  $K -n "$NS" logs ${FOLLOW} --tail="$TAIL" -l "kagent.dev/agent=${AGENT}" 2>/dev/null \
    || $K -n "$NS" logs ${FOLLOW} --tail="$TAIL" "deploy/${AGENT}" 2>/dev/null \
    || warn "agent logs unavailable"
}
show_n8n() {
  log "== n8n =="
  [ -f "$COMPOSE_FILE" ] && docker compose -f "$COMPOSE_FILE" logs ${FOLLOW} --tail="$TAIL" n8n 2>/dev/null || warn "n8n logs unavailable"
}

case "$TARGET" in
  kagent) show_kagent ;;
  agent)  show_agent ;;
  n8n)    show_n8n ;;
  all)
    [ -n "$FOLLOW" ] && die "use a single target with -f (kagent|agent|n8n)"
    show_kagent; show_agent; show_n8n ;;
  *) die "unknown target '${TARGET}' (kagent|agent|n8n|all)" ;;
esac
