# Failure demonstrations (brief Section 6.3)

Driven by `bin/failure-demo <scenario> <break|rollback|explain>`. Each is reversible; **always run rollback**, then `./bin/test-all`.

| # | Scenario | Break | Expect | Why | Prove | Rollback |
|---|---|---|---|---|---|---|
| 1 | Wrong DNS server on a client | `bin/failure-demo wrong-resolver break` | `dig`/curl: cannot resolve; `ping <edge IP>` still works | DNS and IP connectivity are independent | `ping`, `dscacheutil -q host -a name app.team1.test`, `cat /etc/resolver/team1.test` | `... wrong-resolver rollback` |
| 2 | Record points to wrong IP (Mitul) | `bin/failure-demo wrong-dns-record break` | `dig` succeeds with 192.0.2.99; curl cannot connect | DNS is a directory, not a connection | `dig +short`, `nc -vz 192.0.2.99 8443` | `... wrong-dns-record rollback` |
| 3 | Backend A stopped | Hardik: `./macs/mac3-hardik/stop.sh` | requests succeed, all `B` (first may take 2 s) | passive failover (`max_fails`, `proxy_next_upstream`) | `./bin/test-all`, `./bin/doctor`, nginx access log | `./macs/mac3-hardik/start.sh` |
| 4 | Both stopped | both owners stop | DNS, TCP, TLS pass; `502 Bad Gateway` | edge alive, no upstream | `curl -i`, `./bin/doctor` | both start |
| 5 | Wrong port | `bin/failure-demo wrong-port break` (runs `curl :9999`) | resolves, then connection refused | ports separate from IPs | `nc -vz edge 9999` vs `8443` | none |

`bin/failure-demo <scenario> explain` prints the same details with your real names/IPs. Scenarios `backend-a`, `backend-b`, `both-backends` act on the local Mac if it owns that backend, else tell you whom to ask.
For Extension B, set `DNS_TTL=30` in `~/.config/cn-phase1/project.env` and re-run `bin/start` on Mitul.
