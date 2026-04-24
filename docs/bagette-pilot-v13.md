# Bagety pilot pro OLVEND 1.3 / 1.4

## Cíl

Na bagetách si pilotně ověříme:

- příjem z dodacího listu do skladu
- výdej ze skladu do vozidla
- vrácení z vozidla
- odpis
- doporučení, zda doobjednat nebo naopak ubrat

Neřešíme zatím přesný stav po jednotlivých automatech. Tohle je schválně první jednoduchá vrstva, na které se naučíme tok `sklad -> vozidlo` a objednávací logiku.

## Co je k tomu připravené

### Schéma

Soubor:

- `database/purchases_pilot_v13.sql`

Vytvoří:

- `purchase_suppliers`
- `purchase_product_profiles`
- `purchase_orders`
- `purchase_order_items`
- view `purchase_product_recommendations_v13`

### UI

Soubor:

- `inventory.html`

Nový blok:

- `Bagety pilot`

Ukazuje:

- produkty v pilotu
- kolik je na skladě a ve vozech
- odhad spotřeby za posledních 14 dní
- další objednávkové / dodací dny
- doporučené množství k objednání

## Jak to funguje

### 1. Produkt

Produkt musí být v `products`.

### 2. Dodavatel

Každá bageta má dodavatele v `purchase_suppliers`.

### 3. Profil produktu

V `purchase_product_profiles` nastavíme:

- že jde o `pilot_scope = 'bagette'`
- objednávkové dny
- dodací dny
- běžné objednávané množství
- bezpečnostní rezervu
- cílový počet dnů krytí

### 4. Objednávka

Do `purchase_orders` + `purchase_order_items` se zapisuje, co je objednáno a kdy má dorazit.

### 5. Doporučení

View `purchase_product_recommendations_v13` počítá:

- dostupné kusy ve skladech a vozidlech
- příchozí objednávky
- odhad spotřeby z pohybů za posledních 14 dní
- doporučené množství k objednání

## Jaký pohyb použít

### Dodací list dorazil

- `stock_movements_v13.movement_type = 'receipt'`

### Naložení do vozidla

- `stock_movements_v13.movement_type = 'load_vehicle'`

### Vrácení z vozidla

- `stock_movements_v13.movement_type = 'return'`

### Zkažené / neprodejné kusy

- `stock_movements_v13.movement_type = 'waste'`

## Co algoritmus bere v pilotu jako spotřebu

Zatím orientačně:

- `load_vehicle`
- mínus `return`
- mínus `waste`

To není perfektní telemetrie, ale na pilot pro bagety to stačí.

## Co spustit

Nejdřív:

```bash
pbcopy < "/Users/michalpuncochar/Documents/New project/database/purchases_pilot_v13.sql"
```

Pak v Supabase:

1. `New query`
2. `Cmd + V`
3. `Run`

## Co bude další krok

Po nasazení schématu:

1. založit dodavatele baget
2. vybrat první bagety v `products`
3. doplnit jejich `purchase_product_profiles`
4. zapsat první objednávku
5. zkusit první příjem a naložení do vozidla

Tím se už bagetový pilot rozjede nad reálnými daty.
