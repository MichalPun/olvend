# OLVEND Service Module

## Proc je servis prvni

Servisni modul je nejdulezitejsi cast prvni verze, protoze resi skutecny provozni problem:

- automat nefunguje
- je potreba rychle vedet co se stalo
- nekdo musi prevzit odpovednost za zasah
- musi zustat dohledatelna historie

Bez tohoto modulu se dalsi casti systemu stavaji jen evidenci bez operativni hodnoty.

## Cil v1

Prvni verze servisniho modulu ma umet:

- zalozit servisni ticket
- priradit ticket ke konkretnimu automatu
- nastavit prioritu
- priradit odpovednou osobu
- menit stav zasahu
- ukladat poznamky a vysledek opravy
- zobrazit historii zasahu na automatu

## Doporuceny workflow

### 1. Vznik problemu

Uzivatel nebo operator zalozi zaznam:

- machine_id
- lokace
- kratky popis problemu
- priorita
- datum a cas hlaseni

### 2. Dispecerske zpracovani

Ticket se zkontroluje a doplni:

- assigned_to
- planovany termin zasahu
- interni poznamka
- potvrzeni zavaznosti

### 3. Zasah na miste

Technik nebo operator zapisuje:

- diagnostiku
- provedene kroky
- pouzite dily nebo material
- stav po zasahu

### 4. Uzavreni

Pri uzavreni se ulozi:

- vysledek opravy
- finalni stav ticketu
- datum uzavreni
- doporuceni pro dalsi kontrolu

## Stavy ticketu

Doporuceny zaklad:

- `reported`
- `assigned`
- `in_progress`
- `resolved`

Volitelne pozdeji:

- `waiting_parts`
- `cancelled`
- `reopened`

## Priority

Doporuceny zaklad:

- `low`
- `medium`
- `high`
- `critical`

## Minimalni datovy model

### `service_tickets`

- `id`
- `machine_id`
- `location_id`
- `title`
- `description`
- `priority`
- `status`
- `reported_at`
- `assigned_to`
- `scheduled_at`
- `resolved_at`
- `created_by`
- `updated_at`

### `service_ticket_updates`

- `id`
- `ticket_id`
- `author_id`
- `update_type`
- `note`
- `created_at`

### Vazby

- jeden automat muze mit vice servisnich ticketu
- jeden ticket muze mit vice aktualizaci
- operator nebo technik muze mit vice otevrenych ticketu

## Prvni frontend obrazovky

Nejmensi smysluplna sada:

- servisni dashboard
- seznam ticketu
- detail ticketu
- formular pro novy zasah
- historie zasahu na automatu

## Co kodovat jako dalsi krok

Nejvhodnejsi pokracovani je vytvorit primo ve frontendu:

1. servisni dashboard s testovacimi daty
2. seznam ticketu podle stavu a priority
3. detail jednoho zasahu

To je nejkratsi cesta k tomu, aby OLVEND zacal resit realny provoz.
