# OLVEND Mail Service

Server-side IMAP/SMTP bridge for private Webnode mailboxes in OLVEND.

Required environment variables:

```text
SUPABASE_URL=https://rerjlkrhiytgscjerqgs.supabase.co
SUPABASE_SERVICE_ROLE_KEY=...
MAIL_CREDENTIAL_ENCRYPTION_KEY=<64 hex characters>
MAIL_ALLOWED_ORIGIN=https://olvend.onrender.com
```

Render service settings:

```text
Root Directory: backend/mail-service
Build Command: npm install --omit=dev
Start Command: npm start
```

The encryption key can be generated with `openssl rand -hex 32`.
