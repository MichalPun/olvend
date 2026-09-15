# Revize náhrad produktů — 15. 9. 2026

Rozsah: 2 081 aktivních evidovaných plánogramových pozic, katalog 204 produktů, pravidla nakládky v inventáři a výběr/doplnění v mobilu. Počty zahrnují i evidované stroje mimo lokality. Kontrola katalogu a pravidel byla provedena nad úplnými stránkovanými daty, nikoli první stránkou API.

## Zjištěné a opravené chyby

1. Mobil při nulové zásobě originálu nejprve vypočítal nulový příděl pro trasu. Podmínka pak vůbec nepustila hledání náhrady. Nyní vychází hledání náhrady z potřeby pozice a dostupného přídělu alternativy.
2. Rozdělení zásob mezi zbývající zastávky znalo jen původní a plánované SKU. Nyní načítá pravidla náhrad a počítá i pozice, které mohou danou příchuť přijmout. Test: šest kusů náhradního Bonga pro dvě stejné prázdné pozice se rozdělí 3 + 3.
3. Nakládka považovala každou změnu sortimentu za požadavek na jedinou příchuť. Nyní dovoluje povolenou rodinu i při změně sortimentu; schválený seznam musí pokrývat celou skupinu, jinak se automatické seskupení nepovolí. Pravidlo „Konkrétní produkt“ seskupení potravin nepovoluje.
4. Při kompletní výměně návrh přepisoval ručně zvolenou povolenou příchuť hlavním produktem. Nyní ji zachová, pokud patří do cílové rodiny.
5. Mobil rozšiřoval produktové rodiny i přes nastavení „Konkrétní produkt“. Nyní respektuje pravidlo pozice; explicitní plánovaná změna produktu zůstává dostupná.

## Pravidla a data

- 67 pozic s aktuálním SOCO produktem a pravidlem stejné rodiny prošlo kontrolou všech aktivních příchutí. Bongo, RawBar, Extasy a Proteinový suk zůstávají samostatnými rodinami.
- Všech 72 schválených seznamů odkazuje na existující SKU a jejich členové se v novém výběru nabízejí.
- 1 858 pozic s pravidlem „Konkrétní produkt“ nabízí pouze aktuální produkt nebo explicitní plánovanou změnu.
- Provozovatel potvrdil vzájemnou zastupitelnost baget ATM. Sjednoceno 84 pozic ve 22 automatech na rodinu ATM a stejné povolené varianty. Původně mělo 80 pozic označených rodinou ATM pravidlo exact; další tři byly identifikovány podle názvu produktu.
- Změna databáze chráněna transakcí a porovnáním všech polí kromě pravidel náhrad a času aktualizace. Zásoby, ceny, expirace a rozpracované změny sortimentu nebyly změněny.

## Ověření

Behaviorální testy: originál vyprodaný/dostupný, náhrada nedostupná, oddělené rodiny, sdílení zásob na trase, ruční volba při kompletní výměně, přesný produkt a schválený seznam, příchutě při změně sortimentu. Dále regrese mobilní trasy, nakládky, volných kusů a potvrzování cen. Dvě staré textové kontroly v regresi mobilu byly aktualizovány na již existující zaokrouhlení celých balení dolů a společnou funkci potvrzení ceny.

Následná kontrola resolveru nad všemi 2 081 živými pozicemi prošla. Oprava upravuje nové výpočty; již uložené nakládky a dokončené návštěvy se zpětně nepřepisují. Nejde o potvrzení fyzických zásob ani o plošné povolení libovolných produktů mezi různými rodinami.
