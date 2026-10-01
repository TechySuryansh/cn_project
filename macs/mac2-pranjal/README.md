# Mac 2 - Pranjal - nginx edge: TLS, reverse proxy, load balancer

**Setup (once, idempotent):** `./macs/mac2-pranjal/setup.sh`   |   **Start:** `./macs/mac2-pranjal/start.sh` (or `./bin/start`)   |   **Stop:** `./macs/mac2-pranjal/stop.sh`   |   **Status:** `./macs/mac2-pranjal/status.sh` (or `./bin/status`)

**Software installed:** Homebrew, nginx, local CA + server certificate (private keys stay in `~/.config/cn-phase1/tls`); tunnel mode: Cloudflare WARP
**Ports:** 8443/tcp (TLS)
**Logs:** `~/Library/Logs/cn-phase1/` (nginx-access.log (shows chosen backend), nginx-error.log)
**Settings:** `~/.config/cn-phase1/project.env` (created by setup)

## Role in the request flow
Terminates TLS, then proxies round-robin to Backend A/B with passive failover; returns 502 if both fail. After first setup, push `pki/ca.crt` (public) so clients can trust it.

## Common errors
* `nginx: [emerg] bind() failed` -> port in use.
* Backends 'NOT reachable' -> owners not running yet / wrong IPs / (tunnel) WARP or split tunnel.
* macOS firewall prompt for nginx -> Allow.
* Config check: `nginx -t` is run automatically; generated file at `~/.config/cn-phase1/generated/nginx.conf`.

## Explain in the viva
TCP/TLS handshake, certificate/CA/SAN, TLS termination, reverse proxy vs forward proxy, upstream block, round robin, `max_fails`/`fail_timeout`/`proxy_next_upstream`, why clients never see backend IPs, 502 meaning, single point of failure.
