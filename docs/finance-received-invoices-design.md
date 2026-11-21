# Finance OLVEND: přijaté faktury, platby a portál účetní

## Cíl

OLVEND má být manažerská evidence závazků, nákladů, výsledku a hotovosti, nikoli druhé účetnictví. Doklad se v OLVENDU přijme, vytěží, věcně zařadí, schválí, zaplatí a předá účetní. Účty, předkontace, definitivní zaúčtování a legislativní výstupy zůstávají v Money S3.

Tím vzniknou tři oddělené vrstvy:

1. **Skladové příjmy** evidují fyzický příjem zboží a skladovou cenu.
2. **Přijaté faktury** evidují závazek, splatnost, DPH, nákladové členění a úhradu.
3. **Účetní deník** je stínový pohled na data importovaná z Money S3.

Jedna faktura může být propojena se skladovým příjmem, ale nesmí s ním být zaměněna.

## Průchod dokladu

1. Faktura přijde na stávající pracovní e-mailovou adresu. Allbend už má serverové Webnode IMAP napojení, které umí načíst zprávu i přílohy.
2. Dokumentový robot pravidelně vybere nové PDF, ISDOC a fotografie. ISDOC/XML zpracuje deterministicky; PDF nebo obrázek předá serverovému OCR/AI vytěžení.
3. Originální soubor se uloží do privátního úložiště beze změny. Uloží se SHA-256 otisk, velikost, MIME typ, čas a zdroj.
4. OLVEND přidělí interní číslo `PFYY-NNNNN`. Číslo dodavatele zůstává samostatně a nikdy se nepřepisuje.
5. Automatické kontroly ověří duplicitu, součty základu a DPH, splatnost, dodavatele, bankovní účet, VS, měnu a čitelnost přílohy.
6. Odpovědná osoba provede věcnou kontrolu a doplní kategorii, středisko nebo projekt. Doklad lze rozdělit na více nákladových řádků.
7. Finance ověří manažerskou kategorii, středisko, splatnost a platební údaje. Po schválení může doklad vstoupit do platební dávky.
8. OLVEND připraví hromadný platební příkaz. V Raiffeisenbank vždy čeká na autorizaci oprávněnou osobou.
9. Bankovní pohyb se spáruje s fakturou a změní stav úhrady. Automatické potvrzení je povoleno jen pro jednoznačnou shodu.
10. Kompletní doklad vstoupí do balíčku pro účetní. Účetní jej přijme, případně vrátí s konkrétním důvodem.

## Stavy faktury

- `new`: nově vytěžená, čeká na kontrolu;
- `approval`: probíhá věcná nebo finanční kontrola;
- `rejected`: vrácená k doplnění;
- `ready_for_payment`: schválená a úplná;
- `in_payment_batch`: vložená do platební dávky;
- `handoff_ready`: úplná manažerská evidence a originál připravený účetní;
- `exported`: převzatá účetní;
- `cancelled`: zrušená bez fyzického smazání.

Stav úhrady (`unpaid`, `ordered`, `partially_paid`, `paid`, `overpaid`) je veden samostatně. Doklad tak může být například předán účetní ještě před splatností, aniž by se tvářil jako zaplacený.

## Platební dávky a Raiffeisenbank

Nejde o „trvalý příkaz“, ale o **hromadný platební příkaz**. Trvalý příkaz je opakovaná bankovní platba s pevnou periodou a pro proměnlivé faktury není vhodný.

Postup nasazení:

- první fáze: export dávky v podporovaném formátu a ruční import do internetového bankovnictví;
- druhá fáze: Raiffeisenbank Premium API, certifikát uložený pouze v serverovém trezoru;
- každá dávka zůstává v bance ve stavu k autorizaci;
- OLVEND neuchovává podpisový klíč uživatele a nesmí autorizaci obcházet.

Raiffeisenbank aktuálně podporuje hromadné importy a datové výpisy. Premium API umožňuje načítat výpisy a nahrávat dávky, které se následně autorizují v bankovnictví. Před implementací se ověří konkrétní firemní tarif, oprávnění, formát CZK plateb a přístup k Developer portálu.

## Automatické párování banky

Pravidla se vyhodnocují v pořadí:

1. ID položky platební dávky nebo reference vrácená bankou;
2. přesná shoda VS + částka + měna;
3. účet protistrany + částka + datum v toleranci;
4. návrh podle názvu dodavatele a textu platby;
5. ruční párování.

Pravidla 1 a 2 mohou potvrdit úhradu automaticky jen při jediné možné shodě. Ostatní vytvoří návrh. Částečné platby, souhrnné platby, dobropisy, bankovní poplatky a kurzové rozdíly zůstávají ke kontrole.

## Balíček pro účetní

Externí účetní má samostatnou portálovou roli. Není zaměstnancem OLVENDU a nemá přístup k trasám, zaměstnancům, skladu ani obchodním reportům.

Balíček ZIP obsahuje:

- `manifest.csv`: interní číslo, číslo dodavatele, dodavatel, IČ/DIČ, data, měna, částky, VS a stav;
- `originaly/`: původní PDF, ISDOC nebo obrazové soubory;
- `evidence.csv`: kategorie, středisko, projekt, částky, termíny a manažerské poznámky;
- `uhrady.csv`: datum, částka, bankovní reference a způsob spárování;
- `audit.pdf`: schválení, změny, vrácení a kontrolní součty;
- `checksums.sha256`: otisky všech souborů.

Balíček je verzovaný a po uzavření se nemění. Oprava vytvoří doplňkový nebo nový balíček. Stažení se zaznamená, ale teprve tlačítko **Potvrdit převzetí** změní stav dokladů.

## Bezpečnost

- originály jsou v neveřejném bucketu a otevírají se krátkodobým podepsaným odkazem;
- přístup účetní poskytují jen funkce určené pro portál, ne běžné tabulky aplikace;
- přístup ke schránce, případné OCR/AI klíče a bankovní certifikát jsou pouze na serveru;
- každá změna stavu a rozhodnutí má uživatele, čas a poznámku;
- doklady se nemažou, pouze stornují nebo nahrazují novou verzí;
- automatické vytěžení je návrh a musí projít kontrolami.

## Doporučené etapy

### 1. Evidence a portál účetní

Nasadit databázové jádro, privátní přílohy, interní čísla, kontroly, schvalování a ZIP balíček. Faktury lze zpočátku synchronizovat ručně nebo denní dávkou.

### 2. Dokumentový robot nad pracovní poštou

Rozšířit existující `backend/mail-service` o bezpečný serverový worker. Příjem musí být idempotentní podle účtu, složky, UID zprávy, indexu přílohy a SHA-256 otisku. Robot zpracuje podporované přílohy, ignoruje loga a podpisové obrázky, uloží originál do privátního úložiště a výsledek zapíše do fronty ke kontrole.

### 3. Platební dávky

Nejprve export/import do bankovnictví, po ověření procesů Premium API. Vždy s dvoustupňovým schválením a autorizací v bance.

### 4. Bankovní výpisy a párování

Importovat pohyby alespoň denně, automaticky potvrzovat pouze jednoznačné shody a sledovat výjimky.

### 5. Money S3

Po schválení účetní doplnit standardizovaný importní formát nebo Money XML. Do té doby zůstává univerzální ZIP/CSV a originály.

## Údaje nutné před ostrým napojením

- potvrdit přesnou pracovní e-mailovou adresu a zda se mají sledovat všechny zprávy, nebo jen samostatná složka „Faktury“;
- rozhodnout, zda robot zpracuje jen přílohy od povolených dodavatelů, nebo všechny podporované přílohy;
- dodat několik typických PDF, ISDOC a fotografií pro nastavení kontrol a měření přesnosti;
- potvrdit účty u Raiffeisenbank, firemní produkt a práva k hromadným platbám a výpisům;
- od účetní potvrdit minimální obsah předávacího balíčku a importní formát, pokud ho bude chtít používat;
- určit schvalovací limity a zastupování odpovědných osob.
