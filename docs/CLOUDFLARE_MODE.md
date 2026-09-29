# Tunnel mode (`NETWORK_MODE=tunnel`)

Purpose: Hardik and Akshat are remote. Mitul and Vaibhav stay on one LAN. **Only nginx -> backend travels over Cloudflare.**
Cloudflare does *not* handle client-facing DNS or TLS: the client still resolves via dnsmasq and validates a certificate issued by our own CA at nginx.

Not equivalent to the original brief (no shared LAN, uses a cloud service). Ask faculty before submitting in this mode; keep `lan` working.

## Address plan
| Backend | Owner | Virtual IP | Port | Tunnel |
|---|---|---|---|---|
| A | Hardik | 10.250.0.3 | 3001 | `cn-backend-a` |
| B | Akshat | 10.250.0.4 | 3002 | `cn-backend-b` |

nginx upstreams are ordinary `IP:port`. On each backend Mac the setup adds `sudo ifconfig lo0 alias <virtual-ip> 255.255.255.255` because `cloudflared` delivers private-network traffic to the destination IP as-is, so the Mac must own it. (The alias disappears on reboot; `./bin/start` re-adds it.) No router port-forwarding is needed - `cloudflared` only makes outbound connections.

## One-time admin steps (Mitul)
Automated by `admin/bootstrap-cloudflare.sh` (use `--dry-run` first): `cloudflared tunnel login`, create the two tunnels, `cloudflared tunnel route ip add 10.250.0.3/32 cn-backend-a` (and .4 -> b), save one credentials file per tunnel in `~/.config/cn-phase1/admin-out/` (chmod 600).

**Manual (cannot be scripted safely):**
1. Create a free Cloudflare Zero Trust organisation (dash.cloudflare.com -> Zero Trust).
2. Zero Trust -> Settings -> WARP Client -> Device settings -> **Split Tunnels**: ensure `10.250.0.0/24` is *not excluded*. In default *Exclude* mode `10.0.0.0/8` is excluded, so traffic would never enter the tunnel.
3. Zero Trust -> Settings -> WARP Client -> Device enrollment permissions: allow Vaibhav's identity.
4. Send each owner **only their own** credentials file (AirDrop / password manager). Never git, never a shared channel that keeps history.

## Per-Mac
* Hardik: `NETWORK_MODE=tunnel ./macs/mac3-hardik/setup.sh --credentials <file>`
* Akshat: `NETWORK_MODE=tunnel ./macs/mac4-akshat/setup.sh --credentials <file>`
* Vaibhav: install/sign in to Cloudflare WARP (setup installs the cask), then `NETWORK_MODE=tunnel ./macs/mac2-vaibhav/setup.sh`. It warns with this checklist if `10.250.0.x` is unreachable.
* Mitul: `NETWORK_MODE=tunnel ./macs/mac1-mitul/setup.sh` (only needs DNS + client; no Cloudflare software).

Credentials are stored at `~/.config/cn-phase1/secrets/` (`tunnel-credentials.json` or `tunnel-token`, chmod 600). A dashboard-created remotely managed tunnel (token) also works - add the private network route to it in the dashboard.

## Verifying
`./bin/status` (Backend A/B via edge, tunnel A/B inferred), `./bin/doctor` (CLOUDFLARE layer), and on a backend Mac `./macs/mac3-hardik/status.sh` (shows `Cloudflare tunnel CONNECTED`). Logs: `~/Library/Logs/cn-phase1/cloudflared.log`.
