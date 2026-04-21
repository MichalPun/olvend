# OLVEND 1.2 Backlog

## Must Have

### Stroje / Automaty
- samostatny modul `machines.html`
- seznam stroju
- detail stroje
- typ stroje
- znacka / model
- seriove cislo
- stav
- aktivni / neaktivni
- poznamka
- servisni historie

### Vazba stroj -> lokalita
- jedna lokalita muze mit vice stroju
- detail lokality ukaze vsechny stroje na miste
- detail stroje ukaze, kde stoji
- stroj musi byt dohledatelny z lokality i opacne

### Servisni pozadavky 2. vrstva
- pozadavek na konkretni stroj nebo obecne na lokalitu
- stavy: `new`, `assigned`, `on_site`, `in_progress`, `done`, `return_with_part`
- automaticky cas zasahu pres prijezd / odjezd

### QR workflow stroje
- kazdy stroj ma unikatni `qr_token`
- po naskenovani se otevre prace s konkretnim strojem
- akce podle kontextu: servis, doplneni, kontrola, nahlasit problem

### Mobilni Moje smena - novy koncept
- 4 hlavni dlazdice: Pokyny dne, Vozidlo, Smena, Pozadavky
- minimum textu
- velke pismo
- velke dlazdice
- stavy dlazdic: aktivni, zamcena, hotovo
- Vozidlo oddelene od Smeny
- ulozit km bez ukonceni smeny
- moznost pouzit behem dne 2 auta

### Lokality 2. vrstva
- lepsi detail lokality
- mapa lokalit
- servisni historie lokality
- seznam stroju na lokalite
- aktivni lokality jako vychozi filtr
- neaktivni jen pres filtr

### Financni pravidla
- financni model neni jen najem
- podporovane modely: fixni castka, castka za kus, provize, dotace, opacny smer penez
- scope: lokalita, stroj, produktova skupina, pripadne produkt

## Should Have

### Financni vrstva v detailu lokality
- prehled smluvniho vztahu
- typ financniho modelu
- castky
- periodicita
- platnost od-do
- poznamka

### Servisni historie stroje
- predchozi pozadavky
- zasahy
- vysledky
- poznamky techniku

### Lepsi prace s mapou lokalit
- presnejsi geokodovani
- lepsi filtrovani
- jednodussi prace se souradnicemi

### Dalsi stabilizace 1.1
- opravy chyb z ostreho provozu
- lepsi UX
- mene zbytecneho textu
- jistejsi formulare a modaly

## Later
- chytre planovani tras
- optimalizace tras
- telemetrie
- T-Mobile Chytre auto integrace
- ziva poloha vozidel
- plne skladove hospodarstvi

## Databaze 1.2
- `machines`
- `machine_service_rules`
- rozsireni `service_requests` o `machine_id`
- `location_financial_rules`
- `machine_financial_rules`

## Doporucene poradi
1. Stroje / Automaty
2. vazba stroje -> lokality
3. servisni pozadavky na stroj
4. detail lokality se stroji
5. QR workflow
6. financni pravidla
7. prubezne opravy 1.1
