# OLVEND 1.7

## Hlavní změna

Verze 1.7 mění skladové hospodářství z ručního objednávání nakládek na systémový návrh nakládky. Skladník si vybere den, sklad, vozidlo a typ jízdy; systém spočítá doporučené celé balení podle historie konkrétního vozidla, aktuálního stavu na autě a velikosti balení v kartě zásoby.

## Automatická nakládka

- Návrh počítá odhad spotřeby pro další jízdu z historických převodek vozidlo -> automaty.
- Výpočet zohledňuje aktuální stav na autě, aby se nenakládalo zboží, které už tam je.
- Položka se doporučí jen tehdy, když nové celé balení dává provozně smysl a využije se alespoň podle nastaveného minima.
- Pokud se položka nenaloží kvůli nízkému využití balení, systém si odloženou potřebu uloží a přičte ji do dalšího návrhu.
- Při dlouho nehýbaném zůstatku na vozidle systém označí riziko cílené inventury.

## Balení a jednotky

- Karta zásoby obsahuje balení a přepočty.
- Skladová evidence dál běží v základní jednotce položky, například ks, g nebo ml.
- Převodky umí pracovat s balením, kg a l, ale do skladu se zapisuje přepočtené základní množství.

## Doporučení pro bagety

Bagety by zatím neměly být úplně bez lidské kontroly. Systém je může navrhovat stejně jako ostatní sortiment, ale kvůli čerstvosti, počasí, znalosti konkrétní trasy a lokálním výkyvům doporučujeme režim:

- systém připraví výchozí návrh podle historie a stavu auta,
- operátorka nebo skladník může bagety před nakládkou ručně upravit,
- ruční úpravy se zpětně projeví v historii, takže se model postupně učí realitě,
- u baget je vhodné ponechat přísnější kontrolu starých zůstatků na autě.

Prakticky: operátorka už nemusí tvořit celou objednávku od nuly, ale u baget má mít možnost potvrdit nebo upravit systémový návrh.
