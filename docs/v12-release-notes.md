# OLVEND 1.2 Release Notes

## Co je 1.2

Verze `1.2` je hlavne provozni a informacni upgrade celeho OLVENDu.
Neni to jen vizualni cleanup. Tahle verze pridava nove moduly, lepsi vazby mezi lokalitami, stroji a servisem, jednodussi mobilni tok `Moje smena` a pilotni pripravu na trasy, inventory a telemetrii.

Hlavni tema `1.2`:
- mene chaosu na obrazovkach
- rychlejsi orientace
- jasnejsi provozni tok
- lepsi priprava na dalsi etapu

## Spolecne novinky cele verze

- novy modul `Stroje / Automaty`
- vazba `stroj <-> lokalita`
- rozsireny `Servis` o stroje, stavy a cas zasahu
- lepsi detail `Lokality`
- nove `Financni pravidla`
- novy modul `Inventar / zasoby`
- `Planogram` a sloty stroju
- kopirovani planogramu mezi stroji
- pilotni modul `Trasy`
- nove mobilni `Moje smena`
- lepsi prehlednost napric hlavnimi moduly
- mene zbytecneho textu, vic task-first ovladani

## Co Je Nove Podle Roli

### Vedouci / Dispecer / Admin

- muze planovat trasy v modulu `Trasy`
- muze priradit trasu ke konkretnimu technikovi a vozidlu
- vidi ulozene trasy a jejich zakladni souhrn
- v `Provoz` vidi lepsi detail lokality, mapu a stroje na miste
- v `Servis` muze zakladat pozadavek na lokalitu nebo konkretni stroj
- v `Servis` ma nove stavy:
  - `Novy`
  - `Prirazeny`
  - `Na miste`
  - `V reseni`
  - `Hotovo`
  - `Vratit se s dilem`
- v `Servis` se umi pocitat cas zasahu z prijezdu a odjezdu
- v `Stroje / Automaty` vidi evidenci stroju, QR token, lokaci a servisni kontext
- v `Inventar / zasoby` vidi vazbu zasob na stroj a slot
- v `Dashboardu` vidi novejsi provozni prehled

### Technik / Servis

- v `Moje smena` ma novy mobilni tok pres 4 hlavni dlazdice:
  - `Pokyny dne`
  - `Vozidlo`
  - `Smena`
  - `Pozadavky`
- muze zahajit smenu jednoduseji a s mene textem
- `Vozidlo` je oddelene od `Smeny`
- muze behem dne:
  - ukladat km
  - zapsat tankovani
  - menit vozidlo
  - ukoncit smenu
- pokud ma prirazenou trasu, v `Moje smena` vidi:
  - dnesni trasu
  - dalsi zastavku
  - checklist zastavek
  - akce `Navigovat`, `Hotovo`, `Preskocit`
- pokud trasu prirazenou nema, muze normalne pracovat bez ni
- v `Servis` se mu po prirazeni ukazuji otevrene pozadavky a muze z mobilu:
  - zacit servis
  - oznacit opravu
  - vratit se s dilem

### Operator / Rozvoz / Obsluha Vozidla

- v `Moje smena` je jednodussi mobilni ovladani
- muze pracovat i bez prirazene trasy
- muze pouzit behem dne vice vozidel
- muze ulozit km i bez ukonceni smeny
- muze zapsat tankovani v prubehu dne
- muze poslat rychly interny pozadavek pres dlaždici `Pozadavky`

### Provoz / Lokalita / Management

- `Lokality` maji lepsi detail
- u lokality je ted videt:
  - stroje na miste
  - historie servisu
  - financni pravidla
- aktivni lokality jsou primarni vychozi pohled
- mapa lokalit je lepe zapojena do provozni orientace

## Nove Moduly A Vetsi Rozsireni

### Stroje / Automaty

- seznam stroju
- detail stroje
- typ stroje
- znacka / model
- seriove cislo
- stav a aktivita
- poznamka
- QR token
- servisni pravidla
- planogram / sloty
- kopirovani planogramu mezi stroji

### Servis

- pozadavek muze byt:
  - na lokalitu
  - na konkretni stroj
- lepsi editace a stabilnejsi ukladani
- lepsi defaultni pohled:
  - primarne jen nehotove veci
  - razeni od nejnovetsich po nejstarsi

### Inventar / Zasoby

- novy zakladni modul
- vazba polozky na sklad, stroj a slot
- pohyby zasob
- priprava na dalsi vrstvu:
  - produkty
  - baleni vs kusy
  - expirace
  - doplnovani stroju

### Trasy

- pilotni planovani tras
- vyber zastavek
- prirazeni technikovi
- prirazeni vozidlu
- ulozeni planu
- zobrazeni ulozenych tras
- priprava pro Google Routes API

## Co Ukazovat Komu

### Technik / Operator

Ukazat:
- novou `Moje smena`
- vozidlo a km
- tankovani
- prirazeny servis
- prirazenou trasu, pokud existuje

Neukazovat jako hlavni novinku:
- financni pravidla
- admin planogram editaci
- rozsirene planovani tras

### Dispecer / Vedouci

Ukazat:
- `Trasy`
- `Servis`
- `Stroje / Automaty`
- `Lokality`
- `Dashboard`

Nechat az pozdeji:
- hloubsou inventory logiku
- telemetrii
- forecast doplnovani

### Sklad / Budouci inventory role

Ukazat zatim jen:
- ze existuje novy zaklad `Inventar / zasoby`
- ze pribyla priprava na stroje, sloty a dalsi skladovou vrstvu

Neprodavat jeste jako final:
- plne skladove hospodarstvi
- expirace
- automaticke vychystani
- objednavky na vozidla

## Co Je V 1.2 Hotove A Co Je Pilot

### Hotove pro pouziti

- Stroje / Automaty
- vazba stroju na lokality
- Servis 2. vrstva
- lepsi Lokality
- Financni pravidla
- mobilni Moje smena
- planogram a sloty
- UX cleanup hlavních modulu

### Pilot / dalsi ladeni

- Trasy
- Google Routes API vrstva
- propojeni trasy do denniho vykonu v terenu
- inventory smerem ke skladu, vozidlum a expiracim

## Doporuceny Zpusob Predstaveni 1.2

### 1. Technikum a operatorum

Rict jen:
- nova `Moje smena`
- jednodussi prace s autem a km
- servis a trasa primo v mobilu

### 2. Vedoucim a dispecerum

Rict:
- nove `Trasy`
- nove `Stroje / Automaty`
- lepsi `Servis`
- lepsi `Lokality`

### 3. Interne jako roadmapa po release

Navazat na:
- inventory model
- expirace
- vychystani na vozidla
- telemetrii
- chytre doplnovani

## Jednoveta Pro Release

`OLVEND 1.2 prinasi nove moduly Stroje, Inventar a Trasy, jednodussi mobilni Moje smena, lepsi Servis a Lokality a celkove prehlednejsi provozni tok od planovani po vykon v terenu.`
