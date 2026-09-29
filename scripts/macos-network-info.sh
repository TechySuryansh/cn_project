#!/usr/bin/env bash
# Task A helper: prints IPv4, prefix, gateway, interface and MAC of the active
# network interface, in human form (default) or KEY=VALUE form (--env).
set -euo pipefail

gateway="$(route -n get default 2>/dev/null | awk '/gateway:/{print $2}')"
iface="$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')"
[ -n "${iface:-}" ] || { echo "No default route/interface found. Are you on Wi-Fi/LAN?" >&2; exit 1; }
ip="$(ipconfig getifaddr "$iface" 2>/dev/null || true)"
mask_hex="$(ifconfig "$iface" | awk '/inet /{print $4; exit}')"
mac="$(ifconfig "$iface" | awk '/ether/{print $2; exit}')"

prefix=""
if [[ "${mask_hex:-}" =~ ^0x([0-9a-fA-F]{8})$ ]]; then
  n=$((16#${BASH_REMATCH[1]})); prefix=0
  while [ "$n" -gt 0 ]; do prefix=$((prefix + (n & 1))); n=$((n >> 1)); done
  mask="$(printf '%d.%d.%d.%d' $((16#${mask_hex:2:2})) $((16#${mask_hex:4:2})) $((16#${mask_hex:6:2})) $((16#${mask_hex:8:2})))"
fi

if [ "${1:-}" = "--env" ]; then
  printf 'NET_IFACE=%s\nNET_IP=%s\nNET_PREFIX=%s\nNET_MASK=%s\nNET_GATEWAY=%s\nNET_MAC=%s\n' \
    "$iface" "${ip:-}" "${prefix:-}" "${mask:-}" "${gateway:-}" "${mac:-}"
else
  printf 'Interface : %s\nIPv4      : %s\nPrefix    : /%s (mask %s)\nGateway   : %s\nMAC       : %s\n' \
    "$iface" "${ip:-?}" "${prefix:-?}" "${mask:-?}" "${gateway:-?}" "${mac:-?}"
fi
