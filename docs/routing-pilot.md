# OLVEND Routing Pilot

## Cil

Pilotne zapnout modul `Trasy`, ktery umi:

- vzit aktivni lokality se souradnicemi
- zohlednit otevrene servisni pozadavky
- zohlednit servisni okna a prioritu lokality
- navrhnout poradi zastavek
- ulozit plan trasy

## Co umi ted

- klientsky vypocet poradi zastavek
- heuristika nad vzdalenosti, prioritou a otevrenym servisem
- start z aktualni polohy, skladu nebo prvni zastavky
- odhad km a casu
- ulozeni planu do `route_plans` a `route_plan_stops`
- fallback do local storage, kdyz route tabulky jeste nejsou nasazene

## Co to zatim neni

- neni to plnohodnotny traffic-aware routing engine
- odhad km a casu je pilotni aproximace
- poradi zastavek je smysluplne, ale ne finalni "matematicke optimum"

## Aktualni smer

Primarni provider pro OLVEND je ted:

`Google Routes API`

Konkretne:

- `computeRoutes`
- `optimizeWaypointOrder = true`
- `routingPreference = TRAFFIC_AWARE`

Duvod:

- umi rovnou vratit poradi zastavek
- umi ETA a vzdalenost
- umi traffic-aware rezim
- jde rychleji nasadit pro jeden servisni okruh nez plny fleet optimizer

Pozor:

- Google dokumentace uvadi, ze `optimizeWaypointOrder` neni kompatibilni s `TRAFFIC_AWARE_OPTIMAL`
- proto je v pilotu zvoleno `TRAFFIC_AWARE`
- to je porad live traffic rezim, jen ne ten nejexhaustivnejsi

## Doporuceny dalsi krok

### Faze A

- spustit `database/routes_pilot.sql`
- doplnit souradnice skladu do `warehouses`
- pilotne pouzivat `routes.html`

### Faze B

- zridit server-side provider pro live traffic
- prepocet tahat pres edge function
- ulozit odpoved providera do `route_payload`

### Faze C

- navazat trasu primo na servisni pozadavky
- pridat potvrzeni prujezdu zastavkou
- doplnit prepojeni na sklad a navrh vychystani podle trasy

## Doporuceni pro produkcni provider

### Primarni produkcni varianta

`Google Routes API`

Pouziti v pilotu:

- jedno vozidlo
- jeden servisni okruh
- poradi zastavek
- ETA
- traffic-aware route

### Pozdejsi vyssi vrstva

`Google Route Optimization API`

Smysl:

- vice vozidel
- rozdeleni prace mezi techniky
- casova omezeni
- kapacity
- robustnejsi dispatch

## Poznamka k implementaci

Frontend modulu je pripraveny tak, aby slo menit vypocetni cast:

- primarne `google_routes`
- fallback `heuristic`
- pozdeji pripadne `google_route_optimization`

Tedy:

- UI zustava
- tabulky zustavaji
- meni se jen zdroj poradi a odhadu casu
