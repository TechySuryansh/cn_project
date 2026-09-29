#!/usr/bin/env bash
# Usage: wait-for-port.sh <host> <port> [timeout-seconds]
set -euo pipefail
host="${1:?host}"; port="${2:?port}"; timeout="${3:-15}"
end=$((SECONDS + timeout))
while [ $SECONDS -lt $end ]; do
  if nc -z -G 1 "$host" "$port" >/dev/null 2>&1; then exit 0; fi
  sleep 0.5
done
echo "timeout waiting for $host:$port" >&2
exit 1
