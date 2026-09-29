# Mac 4 - Akshat - Backend B (and second test client)

**Setup (once, idempotent):** `./macs/mac4-akshat/setup.sh`   |   **Start:** `./macs/mac4-akshat/start.sh` (or `./bin/start`)   |   **Stop:** `./macs/mac4-akshat/stop.sh`   |   **Status:** `./macs/mac4-akshat/status.sh` (or `./bin/status`)

**Software installed:** Python 3 (brew if missing); tunnel mode: cloudflared
**Ports:** 3002/tcp (0.0.0.0); tunnel: virtual IP 10.250.0.4 on lo0
**Logs:** `~/Library/Logs/cn-phase1/` (backend-b.log, cloudflared.log)
**Settings:** `~/.config/cn-phase1/project.env` (created by setup)

## Role in the request flow
Identical to Backend A with a different identity (`BACKEND_ID=B`). Also usable as a client: `scripts/configure-client-dns.sh`. Run: `./macs/mac4-akshat/setup.sh --credentials <file>` (tunnel mode).

## Common errors
Same as Mac 3 (port 3002).

## Explain in the viva
Same as Mac 3, plus: how being a DNS client (2nd resolver client) differs from being a server.
