# Troubleshooting - diagnose in layer order

Run `./bin/doctor` first. Manual order: **DNS -> TCP -> TLS -> application.**

| Symptom | Likely layer | Check / fix |
|---|---|---|
| `Could not resolve host` | DNS | `cat /etc/resolver/team1.test`; `dig -p 53 @<DNS_IP> app.team1.test`; `scripts/configure-client-dns.sh`; flush: `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder` |
| dig works, curl can't | client resolver vs dig | `dig` ignores `/etc/resolver`; use `dscacheutil -q host -a name app.team1.test` |
| `Connection refused` / timeout | TCP | `nc -vz <EDGE_IP> 8443`; nginx running? Firewall prompt? Wrong `EDGE_IP` after DHCP change? |
| `SSL certificate problem` (curl 60) | TLS | `git pull` for `pki/ca.crt`; `scripts/install-ca.sh`; check SAN: `openssl x509 -in pki/ca.crt -noout -subject` and server cert SAN |
| `502 Bad Gateway` | backend | `./bin/status`; `nc -vz <backend> port`; backend owner runs `status.sh` |
| dnsmasq "address in use" | DNS | another resolver on :53: `sudo lsof -nP -iUDP:53`; brew's own dnsmasq service? `sudo brew services stop dnsmasq` |
| Tunnel mode: A/B unreachable | Cloudflare | WARP connected? split tunnel includes `10.250.0.0/24`? owner's `cloudflared.log`? |
| Works alone, not across Macs | LAN | client isolation on Wi-Fi/hotspot; macOS firewall; backend bound to 127.0.0.1 (ours binds 0.0.0.0) |

Logs: `~/Library/Logs/cn-phase1/`. Restore anything we changed: `./bin/teardown`, backups listed in `~/.config/cn-phase1/backups/INDEX`.
