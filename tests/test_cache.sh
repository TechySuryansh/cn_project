#!/usr/bin/env bash
# Task F - Cache-Control, ETag, conditional 304.
. "$(dirname "$0")/../scripts/testlib.sh"
echo "[CACHE]"
detect_trust
h="$(cache_headers)"
grep -qi '^cache-control: max-age=60' <<<"$h" && t_pass "Cache-Control: max-age=60" || t_fail "Cache-Control header" "backend not sending freshness lifetime"
grep -qi '^etag:' <<<"$h" && t_pass "ETag present" || t_fail "ETag header" "no validator for conditional requests"
code="$(cache_status_with_etag || true)"
[ "$code" = 304 ] && t_pass "Conditional request (If-None-Match) -> 304 Not Modified" || t_fail "304 on matching ETag (got '${code:-none}')" "validators differ between backends or not forwarded"
t_finish
