#!/usr/bin/env bash
# Task D - round robin across both backends.
. "$(dirname "$0")/../scripts/testlib.sh"
echo "[LOAD BALANCING]"
detect_trust
seq_out="$(sample_backends)"
t_info "responses: $seq_out"
a=$(grep -o 'A' <<<"$seq_out" | wc -l | tr -d ' '); b=$(grep -o 'B' <<<"$seq_out" | wc -l | tr -d ' ')
[ "$a" -gt 0 ] && t_pass "Backend A served $a request(s)" || t_fail "Backend A never served" "A is down, or nginx is not balancing to it"
[ "$b" -gt 0 ] && t_pass "Backend B served $b request(s)" || t_fail "Backend B never served" "B is down, or nginx is not balancing to it"
t_finish
