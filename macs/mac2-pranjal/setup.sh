#!/usr/bin/env bash
# setup for role: pranjal  (implementation: scripts/role.sh)
set -euo pipefail
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/role.sh" pranjal setup "$@"
