# Phase 1 checklist (maps brief Tasks A-G to this repo)

| Task | What to show | How |
|---|---|---|
| A LAN | IP/prefix/gateway/iface/MAC per Mac; pairwise ping; topology | `scripts/macos-network-info.sh` on each Mac; `ping` matrix; diagrams in `docs/diagrams.md` (LAN mode) |
| B DNS | records for app/api -> Mac 2; >=2 clients use Mac 1; name access | `dig app.team1.test`, `nslookup`; `scripts/configure-client-dns.sh`; `tests/test_dns.sh` |
| C Backends | `/`, `/api/status`, `X-Backend`; LAN-reachable ports 3001/3002 | `backends/server.py` binds 0.0.0.0; `tests/test_backends.sh` |
| D Edge + LB | round robin A/B via one name | `config/nginx/nginx.conf.template`; `tests/test_load_balancing.sh` |
| E TLS | local CA, SAN cert, trust on clients, no `-k` | `scripts/create-local-ca.sh`, `scripts/install-ca.sh`; `tests/test_tls.sh` |
| F Caching | Cache-Control, ETag, 304 | `curl -I .../api/cacheable`; `tests/test_cache.sh` |
| G Packets | DNS, TCP handshake, TLS handshake, ports | `scripts/capture-packets.sh 60` + Wireshark filters below; `bin/collect-evidence` |

Wireshark filters: `dns`, `tcp.flags.syn==1`, `tls.handshake.type==1` (ClientHello), `tls.handshake`, `tcp.port==8443`.
Ports to point out: DNS `ephemeral -> 53/UDP`; HTTPS `ephemeral -> 8443/TCP`; edge -> backend `ephemeral -> 3001|3002/TCP`.

Failure demonstrations: [FAILURE_DEMOS.md](FAILURE_DEMOS.md). Demo order (Section 8 of the brief): topology -> ping -> `dig` -> HTTPS by name -> repeated curl (A/B) -> Wireshark -> `curl -I` + 304 -> stop Backend A -> Phase 2 items -> fault diagnosis (`./bin/doctor`) -> viva.
Phase 2 hooks already present: `DNS_TTL` (Extension B), `proxy_next_upstream` failover (D), standby edge = run Pranjal's setup on another Mac and change the DNS record (E).
