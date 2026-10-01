#!/usr/bin/env bash
# stop for role: sarvajeet  (implementation: scripts/role.sh)
set -euo pipefail
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/role.sh" sarvajeet stop "$@"
