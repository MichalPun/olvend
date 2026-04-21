# Google Routes Setup pro OLVEND

## Co zapnout v Google Cloud

V projektu pro OLVEND zapni:

- `Routes API`
- billing pro Google Maps Platform

To je pro pilot zaklad.

## Co vytvorit

Vytvor `API key` pro server-side pouziti.

Doporuceni:

- omezit key na `Routes API`
- nepouzivat ho ve frontendu
- ulozit ho jen do Supabase Edge Functions secrets

## Kam key ulozit

Do Supabase jako secret:

- `GOOGLE_MAPS_API_KEY`

Soucasna edge function pro pilot:

- `backend/supabase/functions/google-route-plan/index.ts`

## Co funkce dela

- vezme start a seznam zastavek
- posle request na `https://routes.googleapis.com/directions/v2:computeRoutes`
- zapne `optimizeWaypointOrder = true`
- pouzije `routingPreference = TRAFFIC_AWARE`
- vrati poradi zastavek, vzdalenost, duration a polyline

## Proc neni pouzito TRAFFIC_AWARE_OPTIMAL

Google dokumentace k `Optimize the order of stops on your route` uvadi, ze:

- `optimizeWaypointOrder` neni kompatibilni s `TRAFFIC_AWARE_OPTIMAL`

Proto je pilot postaven takto:

- poradi zastavek pres `optimizeWaypointOrder`
- traffic-aware rezim pres `TRAFFIC_AWARE`

To je pro pilot rozumnejsi nez blokovat optimalizaci uplne.

## Co pak udelat v Supabase

1. nasadit edge function `google-route-plan`
2. ulozit secret `GOOGLE_MAPS_API_KEY`
3. otestovat `routes.html`

## Co modul udela po nasazeni

`routes.html` se chova takto:

- nejdriv zkusi Google Routes edge function
- kdyz neni dostupna, spadne do lokalni heuristiky
- uzivatel tedy vzdy dostane vysledek

## Dalsi krok po pilotu

Az bude fungovat jeden technik a jeden okruh stabilne, dalsi vrstva je:

- `Google Route Optimization API`

To je vhodne pro:

- vice aut
- vice techniku
- rozdelovani zastavek mezi posadky
- casova omezeni a kapacity
