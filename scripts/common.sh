#!/usr/bin/env bash
# Shared helpers. Source this file; do not execute it.
# shellcheck disable=SC2034  # many variables are consumed by sourcing scripts

if [ -n "${CN_COMMON_LOADED:-}" ]; then return 0; fi
CN_COMMON_LOADED=1

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CN_CONFIG_DIR="${CN_CONFIG_DIR:-$HOME/.config/cn-phase1}"
CN_USER_ENV="$CN_CONFIG_DIR/project.env"
CN_SECRETS_DIR="$CN_CONFIG_DIR/secrets"
CN_GEN_DIR="$CN_CONFIG_DIR/generated"
CN_RUN_DIR="$CN_CONFIG_DIR/run"
CN_TLS_DIR="$CN_CONFIG_DIR/tls"
CN_BACKUP_DIR="$CN_CONFIG_DIR/backups"
CN_LOG_DIR="${CN_LOG_DIR:-$HOME/Library/Logs/cn-phase1}"
CN_CA_CERT_REPO="$REPO_ROOT/pki/ca.crt"   # PUBLIC certificate only

# ---------------------------------------------------------------- output ----
if [ -t 1 ]; then
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'; C_BLU=$'\033[34m'
  C_BLD=$'\033[1m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_BLD=""; C_RST=""
fi
info()  { printf '%s\n' "${C_BLU}==>${C_RST} $*"; }
ok()    { printf '%s\n' "${C_GRN}✓${C_RST} $*"; }
warn()  { printf '%s\n' "${C_YEL}!${C_RST} $*" >&2; }
fail()  { printf '%s\n' "${C_RED}✗${C_RST} $*" >&2; }
die()   { fail "$*"; exit 1; }
banner() {
  local line; line="$(printf '=%.0s' {1..60})"
  printf '%s\n%s\n%s\n' "$line" "  $*" "$line"
}

# ------------------------------------------------------------ filesystem ----
ensure_dirs() {
  mkdir -p "$CN_CONFIG_DIR" "$CN_GEN_DIR" "$CN_RUN_DIR" "$CN_TLS_DIR" \
           "$CN_BACKUP_DIR" "$CN_LOG_DIR"
  mkdir -p "$CN_SECRETS_DIR"
  chmod 700 "$CN_CONFIG_DIR" "$CN_SECRETS_DIR" "$CN_TLS_DIR"
}

# backup_file <path>: copies to the backup dir once per distinct content and
# records the location in backups/INDEX so teardown can restore it.
backup_file() {
  local src="$1" dst
  [ -e "$src" ] || return 0
  dst="$CN_BACKUP_DIR/$(echo "$src" | tr '/' '_').$(date +%Y%m%d-%H%M%S)"
  if ls "$CN_BACKUP_DIR"/"$(echo "$src" | tr '/' '_')".* >/dev/null 2>&1; then
    # already backed up before we ever touched it; keep the ORIGINAL only
    return 0
  fi
  cp -p "$src" "$dst"
  echo "$src|$dst" >> "$CN_BACKUP_DIR/INDEX"
  info "Backed up $src -> $dst"
}

write_secret() {  # write_secret <path>  (reads stdin)
  local p="$1"; umask 077; cat > "$p"; chmod 600 "$p"
}

# ---------------------------------------------------------------- config ----
# Parse KEY=VALUE files WITHOUT eval; environment wins over files.
_load_env_file() {
  local f="$1" line k v
  [ -f "$f" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]] || continue
    k="${BASH_REMATCH[1]}"; v="${BASH_REMATCH[2]}"
    v="${v%"${v##*[![:space:]]}"}"          # rtrim
    v="${v#\"}"; v="${v%\"}"
    if [ -z "${!k+x}" ]; then export "$k=$v"; fi
  done < "$f"
}

load_config() {
  _load_env_file "$CN_USER_ENV"
  _load_env_file "$REPO_ROOT/config/project.example.env"
  APP_DOMAIN="app.${TEAM}.test"
  API_DOMAIN="api.${TEAM}.test"
  TEST_ZONE="${TEAM}.test"
  if [ "$NETWORK_MODE" = "tunnel" ]; then
    BACKEND_A_HOST="$TUNNEL_A_IP"; BACKEND_B_HOST="$TUNNEL_B_IP"
  else
    BACKEND_A_HOST="$HARDIK_LAN_IP"; BACKEND_B_HOST="$AKSHAT_LAN_IP"
  fi
  APP_URL="https://${APP_DOMAIN}:${EDGE_PORT}"
  CURL="${CURL:-/usr/bin/curl}"; [ -x "$CURL" ] || CURL="$(command -v curl || true)"
  export APP_DOMAIN API_DOMAIN TEST_ZONE BACKEND_A_HOST BACKEND_B_HOST APP_URL
}

save_config_var() {  # save_config_var KEY VALUE
  local k="$1" v="$2" tmp
  ensure_dirs
  touch "$CN_USER_ENV"; chmod 600 "$CN_USER_ENV"
  tmp="$(mktemp)"
  grep -v "^${k}=" "$CN_USER_ENV" > "$tmp" || true
  printf '%s=%s\n' "$k" "$v" >> "$tmp"
  cat "$tmp" > "$CN_USER_ENV"; rm -f "$tmp"
  export "$k=$v"
}

# prompt_var VAR "question" [default]  -- ask once, remember forever.
prompt_var() {
  local var="$1" q="$2" def="${3:-}" cur ans
  cur="${!var:-}"
  if [ -n "$cur" ] && [ "${CN_RECONFIGURE:-0}" != "1" ]; then
    save_config_var "$var" "$cur"; return 0
  fi
  def="${cur:-$def}"
  if [ -n "${CN_NONINTERACTIVE:-}" ] || [ ! -t 0 ]; then
    [ -n "$def" ] || die "Missing required setting $var (set it in the environment or $CN_USER_ENV)"
    save_config_var "$var" "$def"; return 0
  fi
  read -r -p "$q${def:+ [$def]}: " ans
  ans="${ans:-$def}"
  [ -n "$ans" ] || die "$var is required"
  save_config_var "$var" "$ans"
}

require_role() {  # require_role <role>
  save_config_var ROLE "$1"
}

# ---------------------------------------------------------------- system ----
need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }

require_macos() {
  [ "$(uname -s)" = "Darwin" ] || die "This project targets macOS (found $(uname -s))."
  ok "macOS $(sw_vers -productVersion 2>/dev/null || echo '?') ($(uname -m))"
}

find_brew() {
  local b
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew "$(command -v brew 2>/dev/null || true)"; do
    if [ -n "$b" ] && [ -x "$b" ]; then BREW_BIN="$b"; return 0; fi
  done
  return 1
}

ensure_brew() {
  if ! find_brew; then
    fail "Homebrew is not installed."
    echo "  Install it from https://brew.sh (review the installer, then run it yourself),"
    echo "  then re-run this script."
    exit 1
  fi
  eval "$("$BREW_BIN" shellenv)"
  BREW_PREFIX="$("$BREW_BIN" --prefix)"
  export BREW_PREFIX
}

ensure_formula() {  # ensure_formula <formula> [binary-to-check]
  local f="$1" bin="${2:-$1}"
  ensure_brew
  if have_cmd "$bin" || [ -x "$BREW_PREFIX/bin/$bin" ] || [ -x "$BREW_PREFIX/sbin/$bin" ]; then
    ok "$f already installed"
  else
    info "Installing $f via Homebrew"
    "$BREW_BIN" install "$f"
  fi
}

# Resolve a Homebrew-installed binary path (dnsmasq lives in sbin).
brew_bin() {
  ensure_brew
  local n="$1" p
  for p in "$BREW_PREFIX/bin/$n" "$BREW_PREFIX/sbin/$n"; do [ -x "$p" ] && { echo "$p"; return; }; done
  command -v "$n" || true
}

sudo_run() {  # sudo with a friendly heads-up
  if [ "$(id -u)" -eq 0 ]; then "$@"; return; fi
  sudo -n true 2>/dev/null || info "Administrator password needed for: $*"
  sudo "$@"
}

# ------------------------------------------------------------- templates ----
# render_template <template> <dest> VAR1 VAR2 ...   (replaces @@VAR@@)
render_template() {
  local tpl="$1" dst="$2"; shift 2
  local content v val
  content="$(cat "$tpl")"
  for v in "$@"; do
    val="${!v-}"
    content="${content//@@${v}@@/$val}"
  done
  if grep -q '@@[A-Z_]*@@' <<<"$content"; then
    die "Unresolved placeholder in $tpl: $(grep -o '@@[A-Z_]*@@' <<<"$content" | sort -u | tr '\n' ' ')"
  fi
  printf '%s\n' "$content" > "$dst"
}

# ----------------------------------------------------------------- probes ---
port_open() {  # port_open host port [timeout]
  nc -z -G "${3:-2}" "$1" "$2" >/dev/null 2>&1
}

wait_for_port() { "$REPO_ROOT/scripts/wait-for-port.sh" "$@"; }

pid_alive() { [ -f "$1" ] && kill -0 "$(cat "$1" 2>/dev/null)" 2>/dev/null; }

stop_pidfile() {  # stop_pidfile <pidfile> [sudo]
  local pf="$1" pid
  [ -f "$pf" ] || return 0
  pid="$(cat "$pf" 2>/dev/null || true)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    if [ "${2:-}" = "sudo" ]; then sudo_run kill "$pid" || true; else kill "$pid" 2>/dev/null || true; fi
    for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 "$pid" 2>/dev/null || break; sleep 0.3; done
  fi
  rm -f "$pf" 2>/dev/null || sudo_run rm -f "$pf"
}

# curl wrapper: normal certificate validation first (never -k). If the system
# does not yet trust our CA, retry with --cacert and warn loudly.
CN_TRUST_MODE="system"
app_curl() {
  local args=("$@") out rc
  local resolve=()
  if [ "${TEST_USE_SYSTEM_RESOLVER:-1}" = "0" ]; then
    resolve=(--resolve "${APP_DOMAIN}:${EDGE_PORT}:${EDGE_IP}")
  fi
  if [ "$CN_TRUST_MODE" = "system" ]; then
    out="$("$CURL" -sS --max-time 8 ${resolve[@]+"${resolve[@]}"} "${args[@]}" 2>&1)"; rc=$?
    if [ $rc -eq 0 ]; then printf '%s\n' "$out"; return 0; fi
    if [ $rc -eq 60 ] || [ $rc -eq 35 ] || [ $rc -eq 77 ]; then
      if [ -f "$CN_CA_CERT_REPO" ]; then CN_TRUST_MODE="cacert"; else printf '%s\n' "$out"; return $rc; fi
    else
      printf '%s\n' "$out"; return $rc
    fi
  fi
  "$CURL" -sS --max-time 8 --cacert "$CN_CA_CERT_REPO" ${resolve[@]+"${resolve[@]}"} "${args[@]}"
}

# ------------------------------------------------------- log dir helpers ----
log_paths_hint() { echo "Logs: $CN_LOG_DIR"; }
