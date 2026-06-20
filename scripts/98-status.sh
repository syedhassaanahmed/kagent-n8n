#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 98-status.sh — one-glance status of every moving part of the demo.
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
NODEPORT="${KAGENT_A2A_NODEPORT:-30883}"
N8N_PORT="${N8N_PORT:-5678}"
COMPOSE_FILE="$REPO_ROOT/n8n/docker-compose.yaml"

hr() { printf '%s\n' "----------------------------------------------------------------"; }

hr; log "Host"
printf '  OS/arch     : %s/%s\n' "$(detect_os)" "$(detect_arch)"
printf '  LLM         : provider=%s model=%s endpoint=%s\n' \
  "${LLM_PROVIDER:-?}" "${LLM_MODEL:-?}" "${LLM_ENDPOINT:-?}"

hr; log "Ollama (${LLM_PROVIDER:-?})"
if [ "${LLM_PROVIDER:-ollama}" = ollama ]; then
  if curl -fsS --max-time 3 "http://127.0.0.1:${OLLAMA_PORT:-11434}/api/tags" >/dev/null 2>&1; then
    printf '  host server : up on :%s\n' "${OLLAMA_PORT:-11434}"
  else
    printf '  host server : DOWN\n'
  fi
else
  printf '  hosted provider — no local Ollama\n'
fi

hr; log "Kind cluster '${CLUSTER}'"
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  $K get nodes 2>/dev/null | sed 's/^/  /' || true
else
  printf '  not present\n'
fi

hr; log "kagent (namespace ${NS})"
if $K get ns "$NS" >/dev/null 2>&1; then
  $K -n "$NS" get agent "$AGENT" 2>/dev/null | sed 's/^/  /' || printf '  agent %s not found\n' "$AGENT"
  $K -n "$NS" get modelconfig a2a-demo-modelconfig 2>/dev/null | sed 's/^/  /' || true
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://localhost:${NODEPORT}/api/a2a/${NS}/${AGENT}/.well-known/agent-card.json" 2>/dev/null || echo 000)"
  printf '  A2A card    : http://localhost:%s/api/a2a/%s/%s/.well-known/agent-card.json (HTTP %s)\n' "$NODEPORT" "$NS" "$AGENT" "$code"
else
  printf '  not installed\n'
fi

hr; log "n8n (Docker Compose)"
if [ -f "$COMPOSE_FILE" ] && docker compose -f "$COMPOSE_FILE" ps 2>/dev/null | grep -q n8n; then
  docker compose -f "$COMPOSE_FILE" ps 2>/dev/null | sed 's/^/  /'
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://localhost:${N8N_PORT}/" 2>/dev/null || echo 000)"
  printf '  editor      : http://localhost:%s/ (HTTP %s)\n' "$N8N_PORT" "$code"
else
  printf '  not running\n'
fi
hr
