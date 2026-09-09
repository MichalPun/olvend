# Hromadné předání rajónů

V Trasy → Oblasti operátorů → Předat rajón zvolte datum, původního a nového operátora. Vyfiltrujte město nebo zaškrtněte lokality, přidejte je do návrhu. Další skupiny mohou mít jiné příjemce. Zkontrolujte návrh, počty lokalit a automatů, doplňte důvod a uložte.

Změny se ukládají atomicky přes `transfer_operator_territories_v51`. Při souběžné úpravě nebo neplatné lokalitě se odmítne celé předání. Zachová se rozsah vybraných automatů a náhradník, pokud není současně novým hlavním operátorem. Datum nelze nastavit do minulosti. Konflikt s pozdější naplánovanou změnou vyžaduje kontrolu data. Změna data ve formuláři vymaže rozpracovaný návrh a načte nové podklady.

`get_operator_territories_v51` vybírá poslední účinnou verzi z přiřazení a historie. Trigger zachová předchozí hodnoty před přepsáním přiřazení. Oba plánovače, přehled rajónů a mobilní osobní zóna používají tento výběr podle data. Již založené trasy, vozidla, zásoby ani zaměstnanecké účty se nepřeřazují.

Nasadit nejprve `database/operator_territory_transfers_v51.sql`, potom frontend. Migrace nepředává žádné skutečné lokality.

Ověření: `PGLITE_MODULE=/path/to/@electric-sql/pglite/dist/index.js node scripts/test_territory_transfers.mjs`. Pokrývá datumové předání, historii, částečný rozsah, kolizi náhradníka, souběžné změny, oprávnění, duplicity a rollback celé dávky. Formulář ověřen přes prohlížeč na odděleném mocku, včetně kontrolního kroku a RPC payloadu.
