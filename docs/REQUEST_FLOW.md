# Request flow: `curl https://app.team1.test:8443/api/status`

1. **DNS.** macOS sees the `.test` zone has a scoped resolver (`/etc/resolver/team1.test`) and sends a UDP query to Suryansh's dnsmasq, `dst port 53`, `src port` = ephemeral (e.g. 54321). Answer: `A <Pranjal IP>`, TTL 300. DNS only tells the client *which IP*; nothing is connected yet.
2. **IP.** The client picks the route (same subnet -> ARP for Pranjal's MAC -> Ethernet/Wi-Fi frame).
3. **TCP.** SYN -> SYN-ACK -> ACK to `<Pranjal IP>:8443`. The socket pair is (client IP, ephemeral port, server IP, 8443). The *port* selects the nginx process; the IP alone would not.
4. **TLS.** ClientHello (with SNI `app.team1.test`) -> ServerHello + Certificate + Finished -> client Finished. The client validates that the certificate chains to our CA (installed in the System keychain) and that a SAN matches the name. From here on the payload is encrypted - which is why Wireshark shows "Application Data" and not HTTP.
5. **HTTP.** Inside TLS: `GET /api/status` with `Host: app.team1.test` (HTTP/2 if negotiated).
6. **Reverse proxy.** nginx terminates TLS, then opens a *new* plain-HTTP connection to an upstream. The client never learns backend addresses.
7. **Load balancing.** Round robin picks A (`:3001`) or B (`:3002`); on error/timeout it retries the other.
8. **Backend.** Python returns JSON and `X-Backend: A|B`.
9. **Response path.** Backend -> nginx (HTTP) -> re-encrypted by TLS -> client. nginx logs `upstream=... backend=A`.

## Where tunnel mode differs
Steps 1-5 are identical (local LAN). At step 6 nginx's upstream IP is `10.250.0.3` / `10.250.0.4`. Those packets enter the **Cloudflare WARP** client on Pranjal's Mac, cross Cloudflare's network, and exit through an **outbound-only** `cloudflared` connection that Ajeesh/Sarvajeet opened. On their Macs the virtual IP is a `/32` alias on `lo0`, so `cloudflared` delivers the TCP connection to the local Python process. Steps 7-9 are the same in reverse. So the client-facing DNS/TCP/TLS story is unchanged; only "edge -> backend" is an overlay instead of a LAN hop.

## Caching (Task F)
`/api/cacheable` returns `Cache-Control: max-age=60` + `ETag`.
* **Fresh cache hit** - within 60 s a browser reuses its copy without contacting the server.
* **Conditional request** - after expiry the client sends `If-None-Match: <etag>`; server answers `304 Not Modified` (no body).
* **Full new request** - no cached copy, or the ETag changed -> `200` with body.
