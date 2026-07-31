# OLVEND: provozní pravidla vychystávání

## Princip

Vychystávání nemá pevnou uzávěrku. Spouští se ve chvíli, kdy se sklad rozhodne zboží pro konkrétní trasu připravit.

Výpočet pro každý automat na trase používá:

1. aktuální stav slotu nebo zásobníku z telemetrie,
2. rozdíl do jeho kapacity — co chybí právě nyní,
3. telemetrické prodeje za posledních 28 dní,
4. očekávaný prodej od okamžiku výpočtu do předpokládaného příjezdu na danou zastávku,
5. aktuální použitelnou zásobu na přiřazeném vozidle,
6. provozní velikost balení.

Výsledná potřeba automatu je:

`min(kapacita, chybí nyní + očekávaný prodej do příjezdu)`

Potřeba k vychystání na vozidlo je:

`součet potřeb automatů na trase − použitelný stav vozidla`

## Pravidlo celého balení

Nové celé balení se doporučí naložit pouze tehdy, když se na trase očekává využití alespoň **75 % balení**.

- Potřeba 1 ks při balení 42 ks se zobrazí jako možná potřeba, ale systém doporučí nenakládat.
- Plná potřebná balení se naloží vždy.
- U posledního dalšího balení se samostatně posoudí jeho využití; pokud je pod 75 %, zůstane jen jako viditelné upozornění.
- Možná potřeba se nesmí skrýt, aby dispečer viděl riziko nedostatku a mohl rozhodnutí ručně změnit.

## Čas příjezdu

Při vytvoření trasy se zadává **předpokládaný čas odjezdu**. Předpokládaný příjezd se počítá podle data a času odjezdu, pořadí zastávky, odhadované doby jízdy a kumulované doby obsluhy předchozích zastávek. Každá zastávka proto může mít jiný prodejní horizont.

## Telemetrické prodeje

- U prodejního automatu se prodej páruje přímo přes SKU produktu.
- U kávového automatu se prodaná volba převádí přes recepturu na spotřebu kávy, mléka, kelímků a dalších surovin.
- Pokud chybí telemetrické spojení nebo produktové párování, systém nesmí potřebu nahradit historickým vyskladněním vozidla. Řádek označí jako neúplná telemetrická data.

## Rozpracovaná vychystání

Jiná otevřená nebo rozpracovaná vychystání se do výpočtu nezahrnují, neodečítají se a neslučují. Každé spuštění je samostatný snímek skutečnosti v okamžiku výpočtu.

## Provozní tok

`Vyberu trasu → načtu telemetrii → dopočítám prodej do příjezdu → odečtu stav auta → vychystám → operátorka potvrdí převzetí`

Trasa nemusí být připravená v konkrétní hodinu. Pro ostrý výpočet ale musí být známé její zastávky a vozidlo, protože bez nich nelze určit automaty, čas příjezdu ani zásobu, která už je na autě.

## Fresh sortiment

Bagety, stripsy a další produkty kategorie `food_ready` se nevychystávají skladníkem den předem a nejsou součástí desktopového vychystávacího dokladu.

V den trasy se operátorce v mobilní směně otevře **Ranní naložení z lednice**. Uvidí doporučení vypočtené z:

- aktuálního telemetrického stavu fresh slotů,
- očekávaného prodeje do příjezdu na každou dnešní zastávku.

Operátorka načte doporučení do ranní nakládky, upraví je podle skutečně převzatých kusů a potvrdí pohyb lednice/sklad → vozidlo.
