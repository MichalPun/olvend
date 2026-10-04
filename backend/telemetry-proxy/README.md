# OLVEND Telemetry Proxy

Small HTTPS-friendly proxy for Global Payments / VendSoft-compatible DEX uploads. It can also run the temporary IMA A5 transaction synchronizer for the three Hanák terminals.

The service accepts the same XML payload GP already sends to VendSoft and forwards it to the Supabase Edge Function with the internal `TELEMETRY_INGEST_TOKEN`.

## Endpoint

```text
POST /gp-vendsoft-telemetry
Content-Type: application/xml; charset=utf-8
```

Optional proxy protection:

```text
POST /gp-vendsoft-telemetry?proxy_token=...
```

or header:

```text
x-olvend-proxy-token: ...
```

## Render Web Service

Create a new Render **Web Service** from this repository.

```text
Root Directory: backend/telemetry-proxy
Runtime: Node
Build Command: npm install --omit=dev
Start Command: npm start
```

Environment variables:

```text
TELEMETRY_INGEST_TOKEN=<same token used by Supabase gp-vendsoft-telemetry>
SUPABASE_TELEMETRY_URL=https://rerjlkrhiytgscjerqgs.supabase.co/functions/v1/gp-vendsoft-telemetry
TELEMETRY_PROXY_TOKEN=<optional public proxy token for GP URL>
TELEMETRY_PROXY_PATH=/gp-vendsoft-telemetry
```

### IMA A5 synchronizer

The IMA job uses a headless Chromium session on the server, reads only the safe transaction columns and posts them to the protected `ima-a5-ingest` Edge Function. It never reads or stores card numbers or personal identifiers.

```text
IMA_A5_SYNC_ENABLED=true
IMA_A5_USERNAME=<stored only as a Render secret>
IMA_A5_PASSWORD=<stored only as a Render secret>
IMA_A5_SYNC_INTERVAL_MS=300000
IMA_A5_DEVICE_UIDS=635456,635457,635458
IMA_A5_INGEST_URL=https://rerjlkrhiytgscjerqgs.supabase.co/functions/v1/ima-a5-ingest
CHROMIUM_PATH=/usr/bin/chromium-browser # optional; packaged Chromium is used when this path does not exist
```

The existing `TELEMETRY_INGEST_TOKEN` protects both telemetry endpoints. Status is available at `GET /ima-a5-sync/status` and a protected manual run at `POST /ima-a5-sync`.

If `TELEMETRY_PROXY_TOKEN` is set, GP must include it in the URL as `?proxy_token=...`.
If it is not set, the proxy accepts any POST and relies only on the hidden Supabase token when forwarding.

## Expected GP URL

Without proxy token:

```text
https://<render-service>.onrender.com/gp-vendsoft-telemetry
```

With proxy token:

```text
https://<render-service>.onrender.com/gp-vendsoft-telemetry?proxy_token=...
```

The XML body remains unchanged.

## Let's Encrypt VPS deployment

If a GP terminal does not trust Render/Supabase certificates issued by Google Trust Services, deploy the same proxy behind Caddy on a VPS. Caddy automatically issues a Let's Encrypt certificate.

Files:

```text
Dockerfile
Caddyfile
docker-compose.letsencrypt.yml
.env.letsencrypt.example
```

Detailed runbook:

```text
docs/telemetry-letsencrypt-proxy.md
```
