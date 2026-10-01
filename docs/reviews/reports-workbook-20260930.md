# Prodejní reporty – tabulkový přehled

Rozsah: Reporty → Prodeje, rozcestník reportů a popisek/navigace v hlavním menu. Existující adresy sestav zůstávají funkční. Docházkové a účetní reporty se v této změně nepřepisují. Bez migrace databáze a bez změny oprávnění nebo telemetrického importu.

## Výsledné chování

- Hlavní pohledy: automaty (samostatný sloupec EV), lokality, produkty, jednotlivé prodeje a doplnění. Ostatní sestavy jsou ve výběru Další přehledy. Grafy lze rozbalit pod tabulkou.
- Ruční období a rychlé volby; srovnání s předchozím stejně dlouhým obdobím, stejnými dny minulého měsíce, minulým měsícem, předchozím rokem nebo vlastním intervalem. Hranice dnů v Europe/Prague včetně změn času.
- Řazení záhlavím, filtry v každém sloupci (číselné operátory), výběr sloupců. Výběr buněk, Shift/šipky, součet/průměr a kopírování tabulátory. Dvojklik z automatu/lokality/produktu otevře jednotlivé prodeje; viditelné tlačítko vrátí původní sestavu.
- Obrazovka vykresluje po 200 řádcích. Součty a exporty používají celý filtrovaný výsledek. XLSX obsahuje číselné hodnoty, ukotvené záhlaví a první sloupec, autofilter a samostatný Souhrn s kritérii a součty. Řádky dat neobsahují duplicitní mezisoučty. Text podobný vzorci se neprovádí.
- KPI nahoře respektují horní filtry, součtový řádek tabulky navíc filtry jednotlivých sloupců; rozlišení je vysvětlené přímo v rozhraní.

## Opravy výpočtů

Srovnání sjednocuje klíče obou období, aby nezmizel pokles na nulu. Nulový základ nemá vymyšlený procentní růst. Podíl je vůči součtu tržeb, nikoli vůči nejsilnějšímu řádku. Denní srovnání zarovnává pořadí dnů obou období a uvádí srovnávaný den; týdenní řezy jsou sedmidenní úseky vybraného období.

Hrubý zisk/marže jsou odhady ze současných katalogových nákupních cen. U chybějící nákupní ceny, neznámé DPH, celkových čítačů bez produktů nebo neoceněných výdejů zůstávají neurčené. Částky partnerům doúčtované mimo telemetrii se tímto automaticky nepřičítají. Kontrola úplnosti příjmu DEX je nadále samostatná; report neprokazuje, že dorazily všechny prodeje.

Při změně období nebo chybě načítání se starý výstup vyprázdní. Starší souběžný požadavek nemůže přepsat novější. Při nedostupné historii přesunů se report zastaví místo tichého připsání historických prodejů do aktuální lokality.

## Ověření

- `node scripts/test_report_workbook.mjs`: data/DST, rozsahy, nulové prodeje, filtry, exportní texty a skutečné agregátory stránky.
- `node scripts/test_report_workbook_browser.cjs`: Playwright, izolovaná data, síť mimo localhost zakázána; načtení, srovnání, filtrování, součet výběru, sloupce, podíly, 205 řádků/paginace/export všech řádků, detail a návrat, vlastní/neplatné období, chyba historie přesunů, mobilní šířka.
  Instalovaný Playwright lze zadat proměnnou `PLAYWRIGHT_MODULE`; pro vlastní Chromium použít `BROWSER_EXECUTABLE`.
- XLSX ověřen nezávislým načtením openpyxl: typy, český text, listy, skutečný počet 206 řádků včetně záhlaví, ukotvení, styl záhlaví a doslovný text začínající `=`.
- Stávající `test_security_boundary.mjs`, `check_anonymous_boundary.mjs --self-test` a `--live`; živá kontrola potvrdila odmítnutí anonymních požadavků na všech 12 interních endpointech bez stažení řádků.
- Vizuální kontrola nativní stránky na ověřeném produkčním souhrnu. Soukromá data ani snímek nejsou součástí repozitáře; lokální snímek je označen datem načtení a není vydáván za živě připojený náhled.

PDF používá stávající jsPDF a fonty; nově exportuje stejné viditelné sloupce a filtr jako tabulka. Při asynchronním vytváření drží snímek původního výběru. V izolovaném testu se externí PDF knihovny nestahují, skutečné otevření PDF proto není touto kontrolou pokryto.
