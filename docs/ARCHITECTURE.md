# Architecture

## Roles and address inventory (fill in during Task A)

| Mac | Person | Role | IP (LAN) | Interface | MAC | Service / port |
|---|---|---|---|---|---|---|
| 1 | Mitul | DNS + client + controller | _fill_ | _en0_ | _fill_ | dnsmasq 53/udp,tcp |
| 2 | Vaibhav | nginx edge | _fill_ | _en0_ | _fill_ | 8443/tcp (TLS) |
| 3 | Hardik | Backend A | _fill_ | _en0_ | _fill_ | 3001/tcp |
| 4 | Akshat | Backend B | _fill_ | _en0_ | _fill_ | 3002/tcp |

Each Mac prints its row with `scripts/macos-network-info.sh`. Tunnel mode adds virtual IPs 10.250.0.3 (A) and 10.250.0.4 (B).

## Cloud equivalents

| Component | Cloud analogue |
|---|---|
| dnsmasq (Mac 1) | Route 53 private hosted zone |
| nginx (Mac 2) | ALB / CDN edge node (TLS termination + LB) |
| Backends (Mac 3/4) | Two instances in a target group |
| Cloudflare tunnel (tunnel mode only) | VPN / private-link overlay between VPCs |

## OSI / TCP-IP mapping

| Layer | Item in this project |
|---|---|
| Application | DNS, HTTP/1.1 and HTTP/2, REST JSON, Cache-Control/ETag |
| Session/Presentation | TLS 1.2/1.3 (terminated at nginx) |
| Transport | UDP 53 (DNS), TCP 8443 (client-edge), TCP 3001/3002 (edge-backend) |
| Network | IPv4 addressing; in tunnel mode a virtual IP overlay |
| Link | Wi-Fi / Ethernet frames, MAC addresses |

## Design decisions

* **One config source** - `config/project.example.env` -> `~/.config/cn-phase1/project.env`. Templates use `@@VAR@@` placeholders rendered by `render_template`.
* **Nothing global is modified** - dnsmasq/nginx run with our own generated config files and prefix dirs (not brew services). DNS on clients uses the scoped `/etc/resolver/<zone>` file, so unrelated DNS settings are untouched.
* **TLS ends at nginx.** Nginx -> backend is plain HTTP inside the trusted segment; in tunnel mode Cloudflare only carries that hop and never sees client-facing TLS.
* **Same ETag on both backends** - `/api/cacheable` body is identical on A and B so a conditional request works whichever backend is picked.
* **Health probes** - nginx exposes `/__probe/a`, `/__probe/b`, `/__edge/health` so a client that cannot reach the backends directly (tunnel mode) can still prove each layer individually.
* **Failover** - `max_fails=1 fail_timeout=5s`, `proxy_next_upstream error timeout http_502/503/504`, connect timeout 2s. If both fail, nginx returns a clear `502`.

## Single points of failure
The edge (Mac 2) and DNS (Mac 1) are single points of failure in Phase 1. Phase 2 addresses these (backup resolver, standby edge with DNS cutover).
