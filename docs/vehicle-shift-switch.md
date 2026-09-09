# Výměna auta během směny

Ve Vozovém parku otevři **Akce vozidla → Vyměnit auto ve směně**. Funkce je dostupná administrátorům a manažerům u otevřeného výjezdu. Zadej konečný tachometr, nebo použij km jediné dokončené trasy. Pak vyber nové auto a jeho počáteční tachometr.

Jedna databázová transakce uzavře původní výjezd, založí nový, aktualizuje tachometry a aktuální auto směny a přidá auditní událost. Čas směny, pauzy, dokončené trasy, kmenový řidič vozidla a zásoby se nemění. Zaměstnanec si po změně obnoví mobilní aplikaci. Inventuru je nadále potřeba přiřadit zaměstnanci samostatně.

## Nasazení

1. V databázi OLVEND spusť `database/switch_shift_vehicle_v48.sql`. Funkce používá práva volajícího a existující RLS; její tělo ověřuje aktivního zaměstnance s rolí admin/manager.
2. Nasaď `vehicles.html`, `vehicle-shift-switch.js`, `mobile.html` a `sw.js` obvyklým postupem GitHub → Render. Soubor `routes-detail.html` tato změna neupravuje.
3. Obnov správci i operátorovi aplikaci, aby oba používali novou verzi.
4. U původního auta otevři výměnu, zkontroluj km a cílové auto a ulož. Ověř, že starý výjezd je uzavřený a nový je otevřený ve stejné směně.

## David, 9. 9. 2026

Při čtení produkce: Renault Kangoo 2TX7928 (ID 1), David Boudný, trasa 96, počáteční stav 115 020 km, plán 124,6 km, očekávaný celočíselný konec 115 145 km. Opel Vivaro 3BJ1780 (ID 2) mělo stav 152 009 km. Před skutečným uložením načti aktuální záznamy znovu. Zápis podle plánu se označuje jako odhad, nikoli jako odečet tachometru.

## Ověření

- `PGLITE_MODULE=/cesta/k/pglite/dist/index.js node scripts/test_vehicle_shift_switch.mjs` – PostgreSQL v izolované paměti: historie km, pokračování směny, audit, odmítnutí dvojího uložení, role, obsazené/neaktivní auto, zpětný tachometr, změněný či cizí plán, více jízd a rollback při selhání posledního zápisu.
- `node --experimental-vm-modules scripts/test_vehicle_shift_switch_mobile.mjs` – syntaxe obou HTML modulů, starý mobilní stav a porovnání km správného auta.
- Formulář byl ověřen v prohlížeči s testovacími daty a mock RPC, bez zápisu do produkce.
- Existující `test_mobile_food_route_regressions.mjs` selhává na očekávání `Math.ceil(missing / packageQuantity)` i na původním HEAD; nesouvisí s touto změnou.

Nová RPC serializuje souběžné výměny. Stávající zahajování směny v jiném klientovi nepoužívá tuto RPC; souběžné zahájení nové směny během výměny není pokryto globálním databázovým omezením. Obnovení mobilních klientů načte ochranu starého formuláře, samo toto globální omezení nenahrazuje.
