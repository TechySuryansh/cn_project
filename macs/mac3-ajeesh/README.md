# Mac 3 - Ajeesh - Backend A

**Setup (once, idempotent):** `./macs/mac3-ajeesh/setup.sh`   |   **Start:** `./macs/mac3-ajeesh/start.sh` (or `./bin/start`)   |   **Stop:** `./macs/mac3-ajeesh/stop.sh`   |   **Status:** `./macs/mac3-ajeesh/status.sh` (or `./bin/status`)

**Software installed:** Python 3 (brew if missing); tunnel mode: cloudflared
**Ports:** 3001/tcp (0.0.0.0); tunnel: virtual IP 10.250.0.3 on lo0
**Logs:** `~/Library/Logs/cn-phase1/` (backend-a.log, cloudflared.log)
**Settings:** `~/.config/cn-phase1/project.env` (created by setup)

## Role in the request flow
Final hop. Receives plain HTTP from nginx, answers with JSON and `X-Backend: A`. In tunnel mode `cloudflared` makes an outbound connection to Cloudflare and delivers traffic for 10.250.0.3 to this process. Run: `./macs/mac3-ajeesh/setup.sh --credentials <file>` (tunnel mode).

## Common errors
* Port 3001 in use -> other process.
* Tunnel: missing credential file -> ask Suryansh; `cloudflared.log` for auth errors.
* Backend only on 127.0.0.1? Ours binds 0.0.0.0.
* Firewall prompt for python3 -> Allow.

## Explain in the viva
Bind 127.0.0.1 vs 0.0.0.0, ports, X-Backend, Cache-Control/ETag/304, what happens when this Mac stops (failover), tunnel = outbound-only overlay.
