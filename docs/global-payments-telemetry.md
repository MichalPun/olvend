# Global Payments Telemetrie

## Co jim rict hned na zacatku

- chceme co nejpodobnejsi integracni model, jaky dnes pouzivaji pro VendSoft
- nechceme po nich novy specialni format, pokud umi posilat stejna nebo skoro stejna data i nam
- u nas bude telemetrie vazana na konkretni automat, ne jen obecne na lokaci
- v prvni fazi nam staci stejny zaklad jako ma VendSoft: identita stroje, online stav, alarmy, prodeje a zasoby

## Co od nich potrebujeme zjistit

## Aktualni smer podle prvni informace

- podle prvniho inputu od Global Payments dnes generuji `DEX` soubor a ten periodicky posilaji do VendSoftu
- pravdepodobny prvni integracni model pro OLVEND tedy neni realtime API, ale prijem a zpracovani pravidelneho `DEX` exportu
- to je v poradku pro prvni fazi telemetrie, jen musime presne vedet, jak casto soubor chodi, jak se predava a co v nem realne je
- podle ukazky Kotlin klienta se DEX posila pres HTTP POST jako XML obalka `VDITransaction` s elementem `RawDEX`
- interni prijimaci endpoint v OLVENDu je Supabase Edge Function `gp-vendsoft-telemetry`
- kvuli TLS duvere nekterych GP terminalu preferujeme pro dodavatele verejnou proxy URL mimo Supabase: `https://<render-service>.onrender.com/gp-vendsoft-telemetry`
- proxy prijme stejny XML payload a serverove ho preposle do Supabase Edge Function s internim tokenem
- pokud prijde XML obalka, `DeviceID` bereme jako hlavni identifikator pro mapovani automatu; idealne tam GP nastavi nase stavajici `ID telemetrie` typu `604315`
- pro aktualni VendSoft kompatibilni wrapper z Android/Kotlin klienta bude `ProviderID="IMA"` a `DeviceID` musi byt nase `Telemetry ID`; napriklad automat 100 `ARIA L EVO` ma `DeviceID="582176"`
- `RawDEX` doporucujeme posilat v `<![CDATA[...]]>`, aby XML nerozbilo pripadne `&`, `<` nebo jine znaky v DEX radcich
- technicke cislo terminalu z raw DEX (`CA1` / `ID7`, napr. `ICT230800022143`) ukladame do payloadu, ale bez mapovaci tabulky ho nelze automaticky spojit s nasim `ID telemetrie`
- endpoint umi prijmout i cisty raw DEX bez XML obalky, pokud soubor zacina zaznamem `DXS*`

## Poznatky z realneho sample DEX 2026-05-20

- sample je cisty raw DEX text s CRLF radky, ne XML obalka
- stabilni cislo terminalu je v `CA1` a `ID7`, ve vzorku `ICT230800022143`
- cislo automatu je v `ID1`, ve vzorku `0126`
- nase stavajici `ID telemetrie` typu `604315`, `604314`, `602229` se v tomto raw vzorku nevyskytuje
- pokud GP umi v konfiguraci zvolit `DeviceID`, nastavime tam nase `ID telemetrie`; pokud ne, budeme potrebovat mapu `ICT... -> ID telemetrie`
- datum cteni je v `ID5`, cas parsujeme jako lokalni cas Praha vcetne letniho/zimniho casu
- produktove popisky jsou v `PP1`, ve vzorku je 8 zakladnich popisku
- produktove countery jsou v blocich `PA1` az `PA7`; ve vzorku je 58 raw skupin, po agregaci duplicit 29 unikatnich skupin
- pro prvni fazi ukladame `dex_upload`, `dex_snapshot` a jednotlive `dex_product_counter` eventy do `telemetry_raw_events`
- presny vyznam vsech poli `PA2`, `PA3`, `TA*` a `LA*` jeste nechavame v raw payloadu, dokud ho nepotvrdime proti dokumentaci nebo dalsimu vzorku

### 1. Zpusob predani dat
- posilaji data pres API, webhook, SFTP nebo export souboru
- je integrace push nebo pull
- jak casto data tecou
- jak rychle po udalosti jsou dostupna
- jestli umi stejny feed jako pro VendSoft posilat i dalsimu prijemci
- jestli umi posilat data paralelne do VendSoft i do OLVEND
- pokud je to `DEX`, tak jak presne soubor predavaji: `SFTP`, email, sdilene uloziste, nebo jina cesta
- jestli umi posilat kazdy stroj zvlast, nebo jeden agregovany soubor
- jak se jmenuji soubory a podle ceho poznat, ze uz byly zpracovane

### 2. Autentizace a pristup
- jaky typ autentizace podporuji
- IP allowlist nebo VPN
- testovaci prostredi / sandbox
- dokumentace k API nebo exportum
- kontakt na technickeho cloveka

### 3. Identifikatory stroju
- jak se v jejich systemu identifikuje stroj
- jestli existuje stabilni `external_machine_id`
- jestli umi dodat i `external_location_id`
- jestli umi vratit seriove cislo, interni kod stroje nebo jiny mapovaci klic
- jak poznat, ze je to stejny stroj po reinstalaci nebo vymene modemu
- jestli jejich identifikator odpovida poli `ID telemetrie`, ktere uz mame ve stavajicim exportu automatu

### 4. Co presne umi posilat
- heartbeat / online-offline
- alarmy a chyby
- prodeje
- audit countery
- bezhotovostni transakce
- stavy zasob / surovin / slotu
- hotovostni stav
- otevreni dveri / servisni vstup
- firmware nebo konfiguracni metadata
- planogram, sloupce nebo sloty, pokud neco takoveho drzi
- stav naplneni stroje nebo aspon signal, ze je potreba doplneni

### 5. Datovy format
- ukazkove payloady pro kazdy typ udalosti
- casove razitko a timezone
- jednotky mnozstvi
- menove castky a mena
- typy produktu nebo sloupcu
- ciselnik stavu a chybovych kodu
- pokud je to `DEX`, tak potrebujeme realny ukazkovy soubor a popis poli, ne jen obecny popis
- jestli jejich `DEX` obsahuje jen audit/prodeje, nebo i zasoby, alarmy a stav stroje

### 6. Historie a replay
- umi vratit historicka data
- jak daleko do historie
- umi replay pro konkretni obdobi nebo stroj
- jak resi duplicitni eventy
- umi poslat pocatecni snapshot stavu stroju pri prvnim napojeni

### 7. SLA a provoz
- limity API
- retry chovani
- incident kontakt
- planovane odstavy
- verze API a changelog

## Minimalni technicke otazky na call

1. Jaky je doporuceny integracni kanal pro treti stranu mimo VendSoft?
2. Spravne chapeme, ze do VendSoftu dnes posilate periodicky `DEX` soubor?
3. Muzeme stejny `DEX` feed dostavat i my do OLVEND?
4. Jak casto `DEX` generujete a s jakym zpozdenim proti realnemu stavu?
5. Jakym kanalem umi `DEX` predavat treti strane?
6. Jaky identifikator stroje je v `DEX` stabilni a odpovida nasemu `ID telemetrie`?
7. Obsahuje vas `DEX` jen prodeje a countery, nebo i zasoby, alarmy a stav stroje?
8. Poslete nam jeden realny anonymizovany `DEX` soubor a popis poli?
9. Jak se resi historie, replay a deduplikace?
10. Jaky je provozni a technicky kontakt pro implementaci?

## Kratka verze do mailu nebo na call

Dobry den, pripravujeme vlastni napojeni telemetrie do OLVEND a chceme zachovat co nejpodobnejsi model, jaky dnes pouzivate pro VendSoft, aby to na vasi strane znamenalo co nejmensi zmenu. Podle prvni informace dnes do VendSoftu posilate periodicky `DEX` soubor, tak bychom radi overili, jestli muzeme stejny feed dostavat i my. Potrebujeme potvrdit, jak casto `DEX` generujete, jakym kanalem ho umi predat treti strane, jaky stabilni identifikator stroje obsahuje a zda odpovida nasemu `ID telemetrie`. Zaroven prosime o jeden ukazkovy `DEX` soubor, popis poli a kontakt na technickeho cloveka pro implementaci.

## Minimum pro prvni implementaci

- stabilni `external_machine_id`
- dokumentovany zpusob predani `DEX` souboru
- jeden realny sample `DEX` soubor
- popis poli v `DEX`
- potvrzeni, jak casto soubor chodi
- potvrzeni, jak ziskat historii nebo prvni snapshot

## Jak to implementujeme v OLVEND

### Faze 1 - mapovani a ingest
- tabulka `machine_external_links`
- tabulka `telemetry_dex_ingests` pro ulozeni celeho prijateho VDI/XML a suroveho DEX bez ztraty dat
- tabulka `telemetry_raw_events`
- tabulka `machine_telemetry_state`
- mapovani `provider + external_machine_id -> machine_id`
- ingest `DEX` souboru pres HTTP POST do raw vrstvy
- parser `DEX -> interni telemetry_raw_events`

#### Prijimany XML format

Dodavatel muze pouzit stejny model jako pro VendSoft:

```xml
<VDITransaction TransactionReason="UploadDEX" ProviderID="IMA" CustomerID="..." TransactionID="...">
  <DEXList>
    <DexTransmission DeviceID="..." TransmitTime="...">
      <DexCollection>
        <DEX ReadDateTime="..." DexReason="..." ResponseCode="OK">
          <RawDEX>
            ...
          </RawDEX>
        </DEX>
      </DexCollection>
    </DexTransmission>
  </DEXList>
</VDITransaction>
```

Supabase endpoint vraci HTTP 200, aby odesilaci aplikace povazovala davku za prijatou. Pokud bude v Supabase nastaveny `TELEMETRY_INGEST_TOKEN`, token se posila bud v query parametru `?token=...`, nebo v hlavicce `x-olvend-telemetry-token`.

Pro GP terminaly s problemem duvery k Supabase certifikatu pouzijeme proxy:

```text
https://<render-service>.onrender.com/gp-vendsoft-telemetry
```

Pokud je na proxy nastavene `TELEMETRY_PROXY_TOKEN`, URL pro GP bude:

```text
https://<render-service>.onrender.com/gp-vendsoft-telemetry?proxy_token=...
```

XML payload zustava stejny. Proxy internim serverovym volanim prida `x-olvend-telemetry-token` a preposle payload do Supabase.

Minimalni Kotlin nastaveni na strane odesilatele:

```kotlin
MachineParam.Telemetry.server =
    "https://<render-service>.onrender.com/gp-vendsoft-telemetry"

// deviceId nastavovat na ID telemetrie z OLVEND/VendSoft evidence, ne na seriove cislo automatu.
val telemetry = VendSoft(dex = rawDex, deviceId = "582176", customerId = "OLVEND")
```

V XML wrapperu je idealni zapis:

```xml
<RawDEX><![CDATA[
DXS*...
]]></RawDEX>
```

Po prijmu endpoint ulozi puvodni XML a raw DEX do `telemetry_dex_ingests`, vytvori raw udalosti v `telemetry_raw_events` a pokud najde mapovani `provider + DeviceID`, aktualizuje `machine_telemetry_state.last_seen_at` a `counters_payload`.

Pro odepisovani planogramu se DEX `PA1` selection mapuje na `machine_planogram_slots.slot_code` konkretniho automatu. DEX countery jsou kumulativni, proto se v `telemetry_planogram_counters` drzi posledni zpracovany counter a ze slotu se odepise jen rozdil proti minulemu DEXu.

Prvni DEX pro dany slot pouze zalozi baseline counter. Odecitat se zacne az od dalsiho DEXu, aby se omylem neodecetla cela historicka prodejnost automatu.

### Faze 2 - normalizace
- preklad eventu od Global Payments do interniho modelu
- online / offline
- alarmy
- prodeje a countery
- stav zasob
- pokud `DEX` neobsahuje alarmy nebo live stav, tak je v prvni fazi nebudeme slibovat do UI

### Faze 3 - napojeni do UI
- detail stroje ukaze posledni spojeni, alarmy a stav zasob
- dashboard ukaze odchylky a stroje offline
- servis muze zakladat pozadavky z telemetricke udalosti
- inventar muze dostavat signal k doplneni

## Co jim muzes poslat z nasi strany

- ze mame vlastni evidenci stroju a lokaci
- ze potrebujeme stabilni identifikator stroje
- ze chceme navazat telemetrii primo na konkretni automat
- ze potrebujeme minimalne: online stav, alarmy, prodeje, stavy zasob a historii

## Doporuceny vystup z prvni schuzky

- technicka dokumentace
- sample `DEX` soubor
- popis poli v `DEX`
- seznam podporovanych eventu
- zpusob predani souboru
- potvrzeny identifikator stroje
- potvrzeni, jestli je mozne napojeni mimo VendSoft
