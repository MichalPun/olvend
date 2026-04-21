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

### Preferovana varianta

`Google Route Optimization API`

Smysl:

- umi optimalizaci pro jedno i vice vozidel
- umi casova omezeni a pozdeji i kapacity
- hodi se pro budouci rozsireni o servis, sklad i planovane navstevy

### Prakticka fallback varianta

`TomTom Waypoint Optimization API`

Smysl:

- rychly pilot pro mensi pocet zastavek
- jednodussi use-case pro "v jakem poradi to objet"
- vhodne, kdyz chceme nejdriv jen poradi zastavek a live traffic

## Poznamka k implementaci

Frontend modulu uz je pripraveny tak, aby slo jen vymenit vypocetni cast:

- dnes `heuristic`
- pozdeji `google_route_optimization`
- pripadne `tomtom_waypoint_optimization`

Tedy:

- UI zustava
- tabulky zustavaji
- meni se jen zdroj poradi a odhadu casu
