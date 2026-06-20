#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# scripts/lib.sh — shared helpers + OS-detection layer for the kagent-n8n demo.
#
# Source this from every script:
#     . "$(dirname "$0")/lib.sh"
#
# Design goals: idempotent helpers, POSIX-portable bash, and a uname-based OS
# layer so the same scripts run on Linux, WSL2 and macOS without edits.
# ---------------------------------------------------------------------------

# Resolve repo root from this file's location (scripts/ -> repo root).
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

# --- logging -------------------------------------------------------------
_c() { [ -t 2 ] && printf '%s' "$1" || printf ''; }
log()  { printf '%s[%s]%s %s\n' "$(_c $'\033[1;34m')" "$(date +%H:%M:%S)" "$(_c $'\033[0m')" "$*" >&2; }
ok()   { printf '%s[ ok ]%s %s\n' "$(_c $'\033[1;32m')" "$(_c $'\033[0m')" "$*" >&2; }
warn() { printf '%s[warn]%s %s\n' "$(_c $'\033[1;33m')" "$(_c $'\033[0m')" "$*" >&2; }
die()  { printf '%s[fail]%s %s\n' "$(_c $'\033[1;31m')" "$(_c $'\033[0m')" "$*" >&2; exit 1; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

# --- OS / arch detection -------------------------------------------------
# detect_os -> linux | wsl2 | macos | unknown
detect_os() {
  case "$(uname -s)" in
    Linux)
      if grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; then
        echo wsl2
      else
        echo linux
      fi ;;
    Darwin) echo macos ;;
    *) echo unknown ;;
  esac
}

# detect_arch -> amd64 | arm64 | <raw>
detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64)  echo amd64 ;;
    arm64|aarch64) echo arm64 ;;
    *) uname -m ;;
  esac
}

# --- portable sed -i -----------------------------------------------------
# Usage: sed_inplace 's/old/new/' file
sed_inplace() {
  local expr="$1" file="$2"
  if sed --version >/dev/null 2>&1; then
    sed -i "$expr" "$file"        # GNU sed (Linux/WSL2)
  else
    sed -i '' "$expr" "$file"     # BSD sed (macOS)
  fi
}

# --- .env handling -------------------------------------------------------
# load_env [path] — export all KEY=VALUE pairs from .env into the environment.
load_env() {
  local f="${1:-$REPO_ROOT/.env}"
  if [ -f "$f" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$f"
    set +a
  fi
}

# upsert_env KEY VALUE [path] — write or update a KEY=VALUE line in .env.
upsert_env() {
  local key="$1" val="$2" f="${3:-$REPO_ROOT/.env}"
  touch "$f"
  if grep -qE "^${key}=" "$f"; then
    sed_inplace "s|^${key}=.*|${key}=${val}|" "$f"
  else
    printf '%s=%s\n' "$key" "$val" >> "$f"
  fi
  ok "set ${key}=${val}"
}

# ensure_env_file — create .env from .env.example on first run.
ensure_env_file() {
  if [ ! -f "$REPO_ROOT/.env" ]; then
    cp "$REPO_ROOT/.env.example" "$REPO_ROOT/.env"
    warn "created .env from .env.example — review it before continuing"
  fi
}

# --- retry / wait --------------------------------------------------------
# wait_for "description" timeout_seconds cmd [args...]
# Retries cmd until it exits 0 or the timeout elapses.
wait_for() {
  local desc="$1" timeout="$2"; shift 2
  local start now
  start=$(date +%s)
  until "$@" >/dev/null 2>&1; do
    now=$(date +%s)
    if [ $(( now - start )) -ge "$timeout" ]; then
      die "timed out after ${timeout}s waiting for: ${desc}"
    fi
    sleep 3
  done
  ok "ready: ${desc}"
}

# --- misc ----------------------------------------------------------------
# require_cmd cmd [hint] — die with a helpful message if a command is missing.
require_cmd() {
  have_cmd "$1" || die "required command not found: $1${2:+ ($2)}"
}
