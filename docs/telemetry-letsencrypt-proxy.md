# Telemetry proxy with Let's Encrypt

Use this deployment when GP terminals do not trust Google Trust Services certificates from Render/Supabase.

Public GP endpoint:

```text
https://telemetrie.olmika.cz/gp-vendsoft-telemetry
```

The proxy receives the VendSoft-compatible XML unchanged and forwards it to the existing Supabase Edge Function.

## Server requirements

- small Linux VPS
- public IPv4 address
- ports `80` and `443` open
- Docker + Docker Compose installed

## DNS

When the server IP is known, change DNS for `telemetrie.olmika.cz`:

```text
Type: A
Name: telemetrie
Value: <SERVER_PUBLIC_IP>
```

Remove the current CNAME to Render first:

```text
telemetrie.olmika.cz -> olvend-telemetry-proxy.onrender.com
```

Do not point GP to the domain until HTTPS is verified.

## Deploy

Copy `backend/telemetry-proxy` to the VPS, then on the server:

```bash
cd backend/telemetry-proxy
cp .env.letsencrypt.example .env
nano .env
docker compose --env-file .env -f docker-compose.letsencrypt.yml up -d --build
```

Caddy will request and renew a Let's Encrypt certificate automatically.

## Verify

From any machine:

```bash
curl -Iv https://telemetrie.olmika.cz/healthz
```

The certificate issuer must be Let's Encrypt, for example:

```text
issuer: C=US; O=Let's Encrypt; CN=...
```

Health check must return:

```json
{"ok":true,"service":"olvend-telemetry-proxy"}
```

The ingest path accepts only `POST`, so `HEAD` or browser opening can return `405`. That is fine.

## GP message after verification

```text
Prosím nastavte telemetry POST na:

https://telemetrie.olmika.cz/gp-vendsoft-telemetry

Endpoint má certifikát od Let's Encrypt a přijímá stejný XML payload jako VendSoft.
```
