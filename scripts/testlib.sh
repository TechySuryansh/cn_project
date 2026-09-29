#!/usr/bin/env bash
# Tiny PASS/FAIL framework for tests/*.sh. Each test file sources this,
# calls t_pass / t_fail / t_warn, then `t_finish`.
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"
. "$(dirname "${BASH_SOURCE[0]}")/checks.sh"
load_config
T_FAILS=0
t_pass() { printf '  %sPASS%s  %s\n' "$C_GRN" "$C_RST" "$*"; }
t_fail() { printf '  %sFAIL%s  %s\n' "$C_RED" "$C_RST" "$1"; [ -n "${2:-}" ] && printf '        why: %s\n' "$2"; T_FAILS=$((T_FAILS+1)); }
t_warn() { printf '  %sWARN%s  %s\n' "$C_YEL" "$C_RST" "$*"; }
t_info() { printf '        %s\n' "$*"; }
t_check() {  # t_check "description" "why-it-matters" cmd...
  local d="$1" why="$2"; shift 2
  if "$@" >/dev/null 2>&1; then t_pass "$d"; else t_fail "$d" "$why"; fi
}
t_finish() { [ "$T_FAILS" -eq 0 ]; }
