# Registr DPH a zveřejněné účty

Frontend na stránce `purchases.html` volá Supabase Edge Function:

```text
check-vat-accounts
```

Funkce je v repozitáři:

```text
backend/supabase/functions/check-vat-accounts/index.ts
```

## Nasazení

Ze stanice, kde je Supabase CLI a přihlášení k projektu:

```bash
supabase functions deploy check-vat-accounts --project-ref rerjlkrhiytgscjerqgs
```

Po nasazení má endpoint odpovídat na:

```text
https://rerjlkrhiytgscjerqgs.supabase.co/functions/v1/check-vat-accounts
```

## Proč je potřeba Edge Function

Oficiální registr DPH/ADIS je SOAP služba na `mojedane.gov.cz`. Z browseru ji nelze spolehlivě volat přímo kvůli CORS, proto ji volá serverová Edge Function a frontend dostane čisté JSON:

```json
{
  "dic": "CZ27074358",
  "payerFound": true,
  "unreliable": false,
  "accounts": [
    {
      "type": "standard",
      "accountNumber": "802660000",
      "bankCode": "2700",
      "iban": "",
      "publishedAt": "2013-04-19"
    }
  ]
}
```
