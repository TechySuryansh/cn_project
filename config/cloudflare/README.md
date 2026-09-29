# Cloudflare configuration notes

No credentials live in this repo. Real files go to `~/.config/cn-phase1/secrets/` (chmod 600):
* `tunnel-credentials.json` - from `admin/bootstrap-cloudflare.sh`, one per backend owner, or
* `tunnel-token` - if the tunnel was created in the Zero Trust dashboard.

The private routes are `10.250.0.3/32 -> cn-backend-a` and `10.250.0.4/32 -> cn-backend-b`
(names/IPs are set in `config/project.example.env`). See `docs/CLOUDFLARE_MODE.md`.
