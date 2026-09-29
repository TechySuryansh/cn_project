# Evidence folder

Store proof here so any item can be found in 30 seconds.

| Subfolder | Put here |
|---|---|
| `dns/` | `dig` / `nslookup` output, resolver config, Wireshark DNS screenshot |
| `tcp/` | SYN/SYN-ACK/ACK capture + ports table |
| `tls/` | `openssl s_client`, certificate details, ClientHello/ServerHello screenshots |
| `http/` | `curl -v`, `curl -I` (Cache-Control, ETag), 304 demo, browser DevTools |
| `load-balancing/` | repeated-request output showing A and B |
| `failures/` | one file per failure demo (break output, observation, rollback) |

`./bin/collect-evidence` creates `evidence/<timestamp>/` (git-ignored by default; add the good runs with `git add -f`).
`scripts/capture-packets.sh 60` writes a bounded `.pcap` for Wireshark (also ignored; commit deliberately if size is fine).
Never place keys, tokens or credentials here.
