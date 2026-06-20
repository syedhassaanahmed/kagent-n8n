#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 95-open-ui.sh — open the n8n editor on the imported A2A demo workflow so a
# live audience can click "Execute Workflow" and watch the A2A node run, and
# (best-effort) also expose + open the kagent UI via a background port-forward.
# Portable across Linux/WSL2/macOS.
# ---------------------------------------------------------------------------
set -euo pipefail
. "$(dirname "$0")/lib.sh"
ensure_env_file
load_env

N8N_PORT="${N8N_PORT:-5678}"
WORKFLOW_ID="${N8N_WORKFLOW_ID:-a2a-demo}"
EDITOR_URL="http://localhost:${N8N_PORT}/workflow/${WORKFLOW_ID}"

CLUSTER="${KIND_CLUSTER_NAME:-kagent-n8n}"
CTX="kind-${CLUSTER}"
KAGENT_NS="${KAGENT_NAMESPACE:-kagent}"
KAGENT_UI_PORT="${KAGENT_UI_PORT:-8080}"
KAGENT_UI_URL="http://localhost:${KAGENT_UI_PORT}"

# open_url <url> — best-effort browser open for the current OS.
open_url() {
  local url="$1"
  case "$(detect_os)" in
    macos) open "$url" >/dev/null 2>&1 && return 0 ;;
    wsl2)
      # Prefer the Windows browser from inside WSL.
      if have_cmd wslview; then wslview "$url" >/dev/null 2>&1 && return 0; fi
      if have_cmd powershell.exe; then powershell.exe -NoProfile Start-Process "$url" >/dev/null 2>&1 && return 0; fi
      if have_cmd xdg-open; then xdg-open "$url" >/dev/null 2>&1 && return 0; fi
      ;;
    *)
      if have_cmd xdg-open; then xdg-open "$url" >/dev/null 2>&1 && return 0; fi
      ;;
  esac
  return 1
}

ui_reachable() {
  [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$KAGENT_UI_URL/" 2>/dev/null || echo 000)" = "200" ]
}

# ensure_kagent_ui_forward — best-effort: make the in-cluster kagent UI reachable
# on localhost via a background `kubectl port-forward`. Non-fatal if it can't.
# Idempotent: reuses an existing forward when :${KAGENT_UI_PORT} already serves 200.
ensure_kagent_ui_forward() {
  if ui_reachable; then
    ok "kagent UI already reachable on :${KAGENT_UI_PORT}"
    return 0
  fi
  have_cmd kubectl || { warn "kubectl not found — skipping kagent UI (open it manually with port-forward)"; return 1; }
  kubectl --context "$CTX" -n "$KAGENT_NS" get svc kagent-ui >/dev/null 2>&1 || {
    warn "kagent UI service not found in context ${CTX} — is the cluster up? skipping"; return 1; }

  local logf="${TMPDIR:-/tmp}/kagent-ui-portforward.log"
  log "starting background port-forward for the kagent UI (svc/kagent-ui ${KAGENT_UI_PORT}:8080)..."
  setsid kubectl --context "$CTX" -n "$KAGENT_NS" \
    port-forward "svc/kagent-ui" "${KAGENT_UI_PORT}:8080" >"$logf" 2>&1 &
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    ui_reachable && { ok "kagent UI reachable on :${KAGENT_UI_PORT}"; return 0; }
    sleep 1
  done
  warn "kagent UI port-forward did not become ready (see ${logf}); continuing without it"
  return 1
}

# Make sure n8n is actually serving before we point a browser at it.
code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://localhost:${N8N_PORT}/" 2>/dev/null || echo 000)"
if [ "$code" != "200" ]; then
  warn "n8n editor not reachable on :${N8N_PORT} (HTTP ${code}). Run 'make n8n-up workflow' first."
fi

log "n8n editor (A2A demo workflow):"
printf '\n    %s\n\n' "$EDITOR_URL"
log "Log in with the demo owner account:"
printf '    email:    %s\n    password: %s\n\n' "${N8N_OWNER_EMAIL:-demo@example.com}" "${N8N_OWNER_PASSWORD:-DemoPassw0rd}"
log "In the editor, click 'Execute Workflow' and watch the A2A node turn green;"
log "the kagent agent's reply appears in the 'A2A Response' node output panel."

# Best-effort: also expose + open the kagent UI so you can watch the agent side.
kagent_ui_ok=0
if ensure_kagent_ui_forward; then
  kagent_ui_ok=1
  log "kagent UI:"
  printf '\n    %s\n\n' "$KAGENT_UI_URL"
fi

opened_any=0
if open_url "$EDITOR_URL"; then ok "Opened the n8n workflow in your browser."; opened_any=1
else warn "Could not auto-open the n8n editor — copy the URL above manually."; fi

if [ "$kagent_ui_ok" -eq 1 ]; then
  if open_url "$KAGENT_UI_URL"; then ok "Opened the kagent UI in your browser."; opened_any=1
  else warn "Could not auto-open the kagent UI — copy ${KAGENT_UI_URL} manually."; fi
  log "(the kagent UI stays up via a background port-forward; it ends when you stop it or tear down the cluster)"
fi

[ "$opened_any" -eq 1 ] || true
