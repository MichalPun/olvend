# OLVEND Inventory / Replenishment Model

## Cil

Navrhnout dalsi vrstvu nad `inventory.sql`, aby OLVEND umel:

- produkty a jejich kategorie
- baleni vs. kusy
- pohyb `sklad -> vozidlo -> automat`
- expirace a batch tracking
- navrhy vychystani na vozidlo po smene
- navrhy objednavek na centralni sklad
- pozdeji i receptury napoju a doklady

SQL navrh je v `database/inventory_replenishment_v13.sql`.

## Princip

Pravda o zasobach se ma vest v zakladni jednotce.

Priklad:

- Cola: zakladni jednotka `ks`
- karton: `24 ks`

Clovek muze pri pohybu zadat:

- `2 kartony`
- nebo `7 ks`

Systém vzdy ulozi prepoctenou zakladni jednotku.

## Vrstvy modelu

### 1. Produkty

Tabulka `products`.

Pouziti:

- prodejni zbozi
- suroviny pro napoje
- obalovy material
- servisni material
- nahradni dily

Klicove sloupce:

- `product_category`
- `usage_type`
- `base_unit`
- `vat_rate`
- `purchase_price`
- `sale_price`
- `expiry_tracking_mode`
- `requires_batch_tracking`

### 2. Baleni

Tabulka `product_packages`.

Umoznuje drzet:

- karton = 24 ks
- balik = 100 ks
- pytel = 1 kg

Baleni je vstupni pohodli pro cloveka. Ukladani a vyhodnoceni jede v zakladni jednotce.

### 3. Skladova mista

Tabulka `stock_locations`.

Typy:

- `warehouse`
- `vehicle`
- `employee`
- `machine`
- `machine_slot`

To umozni:

- centralni sklad
- mobilni sklad ve vozidle
- zasobu u technika
- stav automatu
- stav konkretniho slotu

### 4. Batch / expirace

Tabulka `inventory_batches`.

Pouziti:

- bagety
- fresh food
- zbozi s minimalni trvanlivosti
- suroviny s konkretni srazi

Pravidlo:

- batch tracking ma byt povinny hlavne u fresh sortimentu
- system ma podporovat `best_before` i `use_by`
- sklad a vozidlo maji pracovat podle FEFO

FEFO:

- `first expired, first out`

### 5. Pohyby

Tabulka `stock_movements_v13`.

Smysl:

- prijem od dodavatele
- prevod mezi sklady
- nalozeni do vozidla
- doplneni do automatu
- prodej
- spotreba podle receptury
- vratka
- odpis
- inventurni korekce

Narozdil od `inventory.sql` drzi model odkud a kam pohyb jde:

- `from_stock_location_id`
- `to_stock_location_id`

### 6. Zustatky

Tabulka `stock_location_balances`.

Slouzi jako rychla operativni vrstva:

- kolik mam kde
- kolik je rezervovano
- kolik je v jakem batchi

### 7. Replenishment profily

Tabulka `replenishment_profiles`.

Drzi pravidla pro cilove doplnovani:

- minimum
- cilovy stav
- baleni, po kterem se ma objednavat
- jestli jen po celych balenich
- jestli zohlednovat expirace

Pouziti:

- pro vozidlo
- pro centralni sklad
- pozdeji i pro konkretni trasu nebo stroj

### 8. Navrhy vychystani

Tabulky:

- `pick_list_drafts`
- `pick_list_draft_items`

Flow:

1. operator ukonci smenu
2. system prepocita stav vozidla
3. system vytvori navrh vychystani
4. skladnik navrh upravi
5. skladnik potvrdi vyskladneni na vozidlo

System ma navrhovat, ne bezhlave odesilat.

Klicove reason kody:

- `below_min`
- `target_restock`
- `route_need`
- `sales_trend`
- `expiry_risk`
- `expired_stock`
- `warehouse_shortage`

Skladnik musi vzdy videt:

- aktualni stav
- min
- cil
- navrhovane mnozstvi
- proc to system navrhuje

### 9. Receptury

Tabulky:

- `recipes`
- `recipe_items`

Pouziti hlavne pro kavove automaty.

Priklad cappuccino:

- 7 g kavy
- 10 g mleka
- 1 kelimek
- 1 michatko

Tohle je nutne pro budouci telemetrii a spravny odpis surovin.

### 10. Doklady

Tabulky:

- `sales_documents`
- `sales_document_items`

Smysl:

- vazba produktu na fakturu nebo doklad
- oddeleni obchodni vrstvy od skladu

Sklad nema resit vsechny ucetni detaily. Ale model musi byt pripraveny, aby se na nej dalo navazat.

## Prakticke scenare

### Sklad -> vozidlo

Skladnik dostane navrh:

- 2 kartony Coly
- 1 balik kelimku
- 8 ks baget

Po potvrzeni vznikne pohyb:

- `warehouse -> vehicle`

### Vozidlo -> automat

Technik doplni:

- 12 ks Coly do slotu 5
- 6 ks baget do slotu 8

Vznikne pohyb:

- `vehicle -> machine_slot`

### Prodej

Snack automat:

- prodej odecte `1 ks` ze slotu

Kavovar:

- prodej pres recepturu odecte suroviny

### Expirace

Bagety na vozidle:

- 10 ks skladem ve vozidle
- 7 ks expiruje zitra

System ma navrhnout:

- nenechavat stary batch na aute
- neplanovat dalsi nalozku nad pouzitelnou zasobu

### Navrh objednavky na sklad

Stejny princip jako u vozidla, jen o uroven vys:

- centralni sklad padne pod minimum
- system vytvori navrh objednavky dodavateli

## Doporucene poradi implementace

### Etapa 1

- `products`
- `product_packages`
- `stock_locations`
- `inventory_batches`
- `stock_movements_v13`

### Etapa 2

- `stock_location_balances`
- `replenishment_profiles`
- `pick_list_drafts`
- `pick_list_draft_items`

### Etapa 3

- `recipes`
- `recipe_items`
- navrhy doplneni podle spotreby
- expiracni alerty na dashboard

### Etapa 4

- `sales_documents`
- `sales_document_items`
- napojeni na obchodni / ucetni vrstvu

## Co to prinese

- operator nebude delat rucni objednavku na auto
- skladnik dostane navrh vychystani
- system zohledni expirace a batch tracking
- podpori kusy i baleni
- pripravi OLVEND na telemetrii a budoucí ekonomiku

## Poznamka k UI

Na obrazovkach bych to stavel takto:

- `Produkty`
- `Balení`
- `Skladová místa`
- `Návrhy vychystání`
- `Expirace`
- `Pohyby`

Pro operatora ma byt UI jednoduche:

- co mam na aute
- co mi chybi
- co mi bude prochazet

Pro skladnika:

- co mam vychystat
- po jakych balenich
- co musim upravit

Pro vedeni:

- co chybi na sklade
- co expiruje
- co se odepisuje
