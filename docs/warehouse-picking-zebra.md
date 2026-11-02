# OLVEND Sklad na Zebra PDA

## Co je připravené

- samostatná instalovatelná PWA `warehouse-picking.html`
- přihlášení přes stávající účet OLVEND
- načtení nakládek vytvořených z tras
- doporučené pořadí Suroviny → Vody → Cukrovinky
- fotografie produktu, skladová pozice a přepínač balení/kusy
- ruční přepsání množství a velká tlačítka `−` / `+`
- stav skladu, stav vozidla, rezervace dalších nakládek a zůstatek po požadavcích
- možnost položku nevychystat s povinným důvodem
- finální stav `Připraveno k převzetí` bez skladového pohybu
- po prvním online načtení funguje vychystávání i bez signálu a změny se bezpečně řadí do fronty
- po návratu internetu se fronta synchronizuje ve stejném pořadí; horní lišta ukazuje počet čekajících změn
- jednou načtené fotografie uchovává service worker, jinak se offline zobrazí iniciály produktu

Skutečný převod sklad → vozidlo dál vzniká až potvrzením převzetí v mobilní aplikaci operátorky.

## Instalace na Zebru

1. Nasaď aktuální projekt na stejnou adresu jako OLVEND.
2. Na Zebře otevři v Chrome adresu `https://ADRESA-OLVEND/warehouse-picking.html`.
3. Přihlas se běžným účtem OLVEND.
4. V aplikaci klepni na `Instalovat`, případně v nabídce Chrome vyber `Přidat na plochu` / `Nainstalovat aplikaci`.
5. Spouštěj ikonu `Sklad` z plochy zařízení.
6. Před prvním odchodem mimo Wi‑Fi aplikaci jednou otevři online a nech načíst seznam požadavků.

## Doporučené nastavení zařízení

- ponechat Chrome/WebView aktuální
- povolit Wi‑Fi ve skladu
- vypnout automatické uspávání během směny nebo nastavit delší interval
- uzamknout orientaci na výšku
- při výpadku Wi‑Fi lze pokračovat; synchronizace proběhne automaticky po návratu připojení

## Důležité chování

- otevření požadavku změní stav `Čeká na vychystání` na `Vychystává se`
- potvrzení položky ukládá skutečně připravené množství a skladníka
- `Nevychystat` uloží nulové připravené množství a důvod
- závěrečné potvrzení nastaví pouze `ready`, `prepared_at` a `prepared_by`
- stránka nevytváří záznam ve `stock_movements_v13` a nemění `stock_location_balances`
