# Servis a doplňovací trasa v technickém mobilu

Technik zůstává na `technician-mobile.html`. Dnes ukazuje přiřazenou doplňovací trasu vedle technických úkolů; záložka Trasa otevře zavedený postup z `mobile.html` uvnitř stejného mobilního prostředí. Postup pro kávu, potraviny, sklad, hotovost a kilometry se neduplikuje.

Vložená trasa má skrytou vlastní hlavní navigaci a ovládání směny předává technickému mobilu. Komunikace kontroluje původ i konkrétní okno. Dokument trasy zůstává při návštěvě servisu připojený, takže rozpracovaný formulář nezmizí. Při návratu ze trasy se načte skutečný stav směny a výjezdu; při jejím opětovném otevření se obnoví vazba na auto bez resetování formulářů.

Před ukončením směny se znovu načtou dnešní trasy přihlášeného technika. Přiřazená či probíhající trasa ukončení blokuje, stejně jako chyba ověření. Dokončené, zrušené a konceptové trasy neblokují ukončení. Servisní kontrola rozpracovaných úkolů zůstává zachovaná.

Bez migrace databáze. K nasazení patří `technician-mobile.html`, `mobile.html` a `sw.js`.

Ověření: `node --experimental-vm-modules scripts/test_technician_route_workspace.mjs`, `scripts/test_technician_open_services.mjs`, `scripts/test_mobile_food_route_regressions.mjs` a `scripts/test_vehicle_shift_switch_mobile.mjs`. V prohlížeči s izolovanými testovacími daty ověřen přehled trasy, otevření stávajícího doplňovacího rozhraní a návrat mezi trasou a servisními úkoly. Širší `test_technician_mobile.mjs` má existující nesouvisející selhání očekávání odkazu `service-requests.html?action=new` v nezměněném `technical-jobs.html`.
