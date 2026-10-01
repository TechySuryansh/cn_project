#!/usr/bin/env bash
# start for role: ajeesh  (implementation: scripts/role.sh)
set -euo pipefail
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/role.sh" ajeesh start "$@"
