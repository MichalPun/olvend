# Import produktů do skladu 1.3

Vstup: `Produkty-2026-04-24.xlsx`

## Co jsme z Excelu našli

- celkem položek: `141`
- všechny jsou vedené jako `Active`
- bez čárového kódu je `92` položek
- nejčastější typy:
  - `Teplé nápoje`
  - `Cukrovinky`
  - `Vody`
  - `Ingredient`
  - `Zrnková káva`
  - `Bageta`
- dost položek nemá smysluplnou sekci
- některé položky mají záporný stav `v automatech`

To znamená:

- Excel je dobrý jako základ pro master data produktů
- ale sloupce se zásobami musíme brát opatrně
- nejsou to ještě „čistá“ skladová data

## Jak to mapujeme do OLVENDu

### `products`

- `Kód` -> `sku` a zároveň pomocný externí kód
- `Název` -> `name`
- `Čárový kód` -> `ean`
- `Prodejní cena základní` -> `sale_price`
- `Typ` -> mapuje se do:
  - `product_category`
  - `usage_type`
  - `base_unit`

### Kategorie mapování

- `Teplé nápoje` -> `beverage_ready` / `direct_sale` / `ks`
- `Cukrovinky` -> `snack_ready` / `direct_sale` / `ks`
- `Vody` -> `beverage_ready` / `direct_sale` / `ks`
- `Bageta` -> `food_ready` / `direct_sale` / `ks`
- `Ingredient` -> `ingredient` / `recipe_consumption` / `g`
- `Zrnková káva` -> `ingredient` / `recipe_consumption` / `g`
- vše ostatní zatím konzervativně -> `consumable` / `internal_consumption` / `ks`

## Co zatím neimportovat natvrdo

Z Excelu zatím slepě nepřenášet jako pravdu:

- `Ve skladu`
- `V nákladních vozech`
- `V automatech`
- `Celkové zásoby`

Důvod:

- potřebujeme je nejdřív ověřit
- některé položky mají i záporný stav v automatech
- to je spíš signál k narovnání než k přímému importu

## Doporučený postup

### Etapa 1

- naimportovat `products`
- doplnit `ean`, `sale_price`, typy a jednotky

### Etapa 2

- zkontrolovat produkty bez EAN
- ručně rozhodnout, které jsou:
  - hotový produkt
  - ingredience
  - servisní / interní materiál

### Etapa 3

- teprve potom řešit počáteční stavy:
  - sklad
  - vozidlo
  - automat

### Etapa 4

- přepnout pohyby na:
  - `warehouse -> vehicle`
  - `vehicle -> machine`
  - později `sale` přes DEX

## Připravený pomocný skript

Soubor:

- `scripts/import_products_from_xlsx.py`
- `scripts/generate_products_import_sql.py`
- `database/products_import_v13.sql`

Co dělá:

- přečte `.xlsx` bez externích knihoven
- vytvoří CSV preview pro import
- vypíše shrnutí kategorií, chybějících EAN a problémových stavů
- z CSV preview vygeneruje opakovatelný `upsert` import do `public.products`

Použití:

```bash
python3 scripts/import_products_from_xlsx.py "/Users/michalpuncochar/Downloads/Produkty-2026-04-24.xlsx"
```

Volitelně vlastní výstup:

```bash
python3 scripts/import_products_from_xlsx.py "/Users/michalpuncochar/Downloads/Produkty-2026-04-24.xlsx" "tmp/products-import-preview.csv"
```

Vygenerování SQL importu:

```bash
python3 scripts/generate_products_import_sql.py "tmp/products-import-preview.csv" "database/products_import_v13.sql"
```

Samotný import do Supabase:

```bash
pbcopy < "/Users/michalpuncochar/Documents/New project/database/products_import_v13.sql"
```

Pak v Supabase:

1. `New query`
2. `Cmd + V`
3. `Run`

Import je připravený jako `upsert by sku`, takže je bezpečný i pro opakované spuštění.
