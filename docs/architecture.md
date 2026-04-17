# OLVEND Architecture

## Cile

OLVEND ma nahradit nebo doplnit VendSoft a dlouhodobe pokryt:

- evidenci automatu
- servisni zasahy
- planovani tras
- spravu operatoru
- sklad
- reporting

Navrh pocita s rustem na desitky automatu a dalsi moduly bez nutnosti prepisovat cele jadro.

## Navrzena struktura

### `frontend/`

Zodpovida za uzivatelske rozhrani.

Doporucene smerovani:

- kratkodobe: HTML/CSS/JS nebo lehky SPA frontend
- strednedobe: React
- pozdeji: oddelene views pro dispecink, servis, sklad a reporting

### `backend/`

Zodpovida za API, autentizaci a business logiku.

Navrzene oblasti:

- sprava automatu
- servisni tikety a historie zasahu
- planovani tras
- skladove pohyby
- reporty a exporty

### `database/`

Zodpovida za datovy model a migrace.

Doporuceny smer:

- PostgreSQL jako hlavni databaze
- oddelene tabulky pro automaty, lokace, operatory, servis, trasy a sklad
- auditni historie dulezitych zmen

## Moduly aplikace

### 1. Servis

Zakladni tok:

- nahlaseni problemu
- priorita zasahu
- prirazeni technika nebo operatora
- zapis diagnostiky a reseni
- uzavreni zasahu a historie podle automatu

Servis je prvni prioritni modul, protoze primo ovlivnuje dostupnost automatu a kvalitu provozu.

### 2. Automaty

Zakladni evidence:

- interni ID automatu
- lokalita
- typ automatu
- stav
- posledni servis
- odhad trzeb a vykonu

### 3. Trasy

Zakladni tok:

- operator
- seznam automatu pro dany den
- priorita navstev
- stav splneni

### 4. Operatori

Evidence:

- jmeno
- region
- vozidlo
- smena
- role

### 5. Sklad

Evidence:

- surovina
- jednotka
- aktualni stav
- minimalni zasoba
- spotreba podle doplneni

## Doporucene poradi vyvoje

### Faze 1

- servisni dashboard
- seznam a detail servisnich zasahu
- vazba servis -> automat
- zakladni frontend kostra

### Faze 2

- evidence automatu
- operatori
- jednoduche trasy

### Faze 3

- sklad
- reporty
- optimalizace tras

## Datovy zaklad

Minimalni entity pro prvni verzi:

- service_tickets
- service_ticket_updates
- machines
- locations
- operators
- routes
- route_stops
- stock_items
- stock_movements

## Dulezita technicka rozhodnuti

- Zachovat modulovou strukturu od zacatku.
- Nevazat frontend primo na konkretni hosting.
- API a databazi navrhnout tak, aby slo jednoduse pridat mobilni nebo tabletove rozhrani.
- Drzet root `index.html` jako docasny staticky vstup, dokud nebude frontend nasazovan samostatne.

## Dalsi konkretni krok

Nejrozumnejsi pokracovani je postavit prvni informacni architekturu frontend aplikace:

- servisni dashboard
- seznam servisnich ticketu
- detail servisniho zasahu
- navazany detail automatu
- trasy
- sklad

To uz umozni navazat komponenty, data a pozdeji API bez velkeho prekopani.
