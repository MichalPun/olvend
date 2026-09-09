# Oprava návštěvy na PC

V detailu trasy → Zastávky → Akce → **Opravit návštěvu**. Přístup mají aktivní admin a manager. Návštěva musí být dokončená nebo přeskočená; trasa může dále probíhat.

Formulář umožňuje:
- opravit množství, doplnit chybějící doplnění potravin, vybrat skutečný produkt a jeho existující šarži/trvanlivost;
- opravit stav před doplněním, kapacitu a poznámku; stav po doplnění se odvodí;
- opravit množství kávové suroviny s převodem g/kg nebo ml/l;
- upravit cenu zaznamenanou u doplnění, u jednoznačné pozice také aktuální cenu;
- upravit počet a důvod evidovaného odpisu před předáním skladu;
- opravit výběr a přepočet hotovosti, sáček, poznámku, časy a dokončení/přeskočení návštěvy.

Každá oprava vyžaduje důvod a ukládá neměnnou historii před/po v `route_visit_corrections`. Skladové pohyby, návštěva, položky, pozice a audit se mění v jedné transakci. Původní pohyby nejsou mazány. `correction_sources` zachovává aktuální rozpis opraveného doplnění pro opakované opravy.

## Hranice opravy

Skladové opravy se zastaví při novější návštěvě stejného automatu, pozdější uzavřené inventuře dotčeného produktu nebo nedostatku evidované zásoby. Směs při přechodu sortimentu, záměna produktu po dalším prodeji a nejednoznačné historické pohyby vyžadují individuální fyzickou kontrolu. Změna produktu není dostupná u kávové suroviny. Formulář nepřidává novou pozici ani dosud neevidovaný odpis a neotvírá uzavřený skladový doklad.

Oprava výchozího fyzického počtu může vytvořit přírůstek s nepřiřazenou šarží; nevymýšlí datum trvanlivosti. Oprava trvanlivosti doplnění vybírá existující šarži a nemění datum globálně pro jiná skladová místa.

Dokončenou návštěvu s doplněním, odpisem nebo výběrem peněz nelze označit za přeskočenou bez opravy těchto zápisů. Návštěva se nevrací do rozpracovaného mobilního režimu. Starý mobilní zápis po manažerské opravě blokují triggery nad návštěvou, položkami, doplněními, hotovostí, kontrolami a původními skladovými referencemi; mobil navíc kontroluje revizi před ukládáním položek.

## Instalace a ověření

Nejdřív `database/route_visit_corrections_v50.sql`, poté frontend a service worker v164. Databázové funkce běží se zvýšenými právy, ale veřejná RPC kontroluje aktivního zaměstnance přes `auth.uid()` a role admin/manager. Pomocná funkce nemá veřejné právo spuštění. Audit je klientům dostupný pouze ke čtení pro vedení.

`PGLITE_MODULE=/path/to/pglite/dist/index.js node scripts/test_route_visit_corrections.mjs`

Testy ověřují zachování zásob, opakovanou opravu, změnu produktu, doplnění chybějícího zápisu, zpětné vrácení transakce, ochranu inventury a revize, neoprávněného uživatele, hotovost, odpis a převod g/kg. Formulář byl ručně vyzkoušen v prohlížeči na lokálních náhradních datech včetně změny 10 → 6 kusů. Při instalaci nebyla opravována žádná živá návštěva.
