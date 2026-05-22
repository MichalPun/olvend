# Mobilni verze 1.5 - priprava pilotu

## Cil

Mobilni verze se bude spoustet nejdrive jako skryty pilot. Nebude napojena do prihlasovaciho presmerovani zamestnancu, dokud neoverime smeny, servisni zasahy a skladove pohyby na realnych datech.

## Co uz ma vlastni databazove napojeni

- Smeny: `attendance_days`, `attendance_events`
- Vozidla a kilometry: `vehicles`, `vehicle_operation_logs`
- Tankovani a poznamky k autu: `vehicle_operation_logs`
- Pokyny dne: `daily_instructions`, `instruction_acknowledgements`
- Servisni pozadavky: `service_requests`
- Dlouho otevrene servisni navraty: `mobile_service_followups`
- Mobilni skladove doklady: `mobile_stock_requests`, `mobile_stock_request_items`

## Skryta pilotni obrazovka

Pilotni obrazovka je `mobile-pilot.html`.

Zatim ji nikde nelinkujeme z menu a nemenime prihlasovaci logiku v `index.html`. To znamena, ze zamestnanci po prihlaseni porad konci na soucasne strance. Pilot lze otevrit rucne jen pro test.

## Skladovy tok

1. Operator vytvori `vehicle_order`.
2. Skladnik na PC uvidi pozadavek jako `requested`.
3. Po vychystani se stav zmeni na `ready`.
4. Operator potvrdi nakladku a doklad prejde na `confirmed`.
5. Pri potvrzeni se zalozi radky ve `stock_movements_v13` a upravi `stock_location_balances`.
6. Vykladka, prodej z vozidla a vratky pouzivaji stejnou hlavicku dokladu, ale jiny `request_type`.

Mapovani pohybu:

- `vehicle_order` / `vehicle_load`: sklad -> vozidlo, `movement_type = load_vehicle`
- `vehicle_unload`: vozidlo -> sklad, `movement_type = return`
- `vehicle_sale`: vozidlo -> prodej, `movement_type = sale`
- `vehicle_return` / `vehicle_writeoff`: vozidlo -> odpis, `movement_type = waste`

## Pravidla pred ostrym zapnutim

- Bez auta se nesmi vyzadovat kilometry.
- S autem musi byt potvrzen pocatecni stav km.
- Pokyny dne musi byt viditelne pred startem smeny.
- Dlouho otevrene servisy se ukazou po startu smeny, neblokujici pred startem.
- Servis ulozeny jako otevreny se sbali a pripomene podle eskalacniho intervalu.
- Mobilni sklad nesmi na uvodni obrazovce ukazovat dlouhe seznamy.
- Vykladka zacina prazdna a cele vozidlo se nacita jen na explicitni akci.

## Nasazeni

1. Spustit `database/mobile_workflows_v15.sql` v Supabase SQL editoru.
2. Spustit `database/mobile_runtime_v15.sql`, pokud jeste nejsou pripravene uctenky, stav km pri tankovani a servisni vysledky.
3. Otestovat `mobile-pilot.html` s jednim realnym zamestnancem.
4. Pripravit PC pohled pro skladnika na `mobile_stock_requests`.
5. Teprve potom zapnout presmerovani vybranym rolim nebo vybranym zamestnancum.
