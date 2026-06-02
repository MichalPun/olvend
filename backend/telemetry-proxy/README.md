# OLVEND Telemetry Proxy

Small HTTPS-friendly proxy for Global Payments / VendSoft-compatible DEX uploads.

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
