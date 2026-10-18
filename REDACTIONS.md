# Redactions / Sanitization notes

## Intentionally omitted
- Full `/proc/*/environ` dumps (may contain gateway tokens, bearer tokens, AWS keys, cookies)
- Contents of `/run/agent-store-fuse/pod-grant` or any grant/credential files
- SSH private keys, cookies, browser profile secrets
- Full Chrome user-data-dir contents

## Included but noted
- `machine-id` — local VM identifier only
- Process command lines from `ps` — reviewed; Chrome `--password-store=basic` is a flag name, not a password; `env -u SAND_GATEWAY_TOKEN -u SAND_EGRESS_TUNNEL_BEARER` unsets tokens rather than printing them
- Network: private RFC1918 addresses (172.30.0.0/24) — sandbox-local, not credentials
- `cursor-agent-store-fuse` argv includes store IDs and public API endpoint `api2.cursor.sh` — identifiers, not auth secrets

## Tools used
- Read-only collection only; no packages installed for this snapshot beyond what was already present
