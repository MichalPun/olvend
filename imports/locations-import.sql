-- Import lokalit vygenerovaný z Excelu Lokality-2026-04-18.xlsx
-- Sloučeno primárně podle adresy + města, s ochranou proti sloučení nesouvisejících názvů na stejné adrese.
-- Pokud chceš tabulku před importem vyčistit, odkomentuj další řádek.
-- truncate table public.locations restart identity;

insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('GMW měřící technika, s. r. o.', 'Blansko', 'Hybešova 584/53', 'GMW měřící technika, s. r. o.', 'Bc. Lucie Sladká', '+420 516 410 740', null, 'Zdrojové kódy: 90
Zdrojové názvy: GMW-měřící technika, s. r. o.
Trasy: LD_středa_2TX7829
Operátor: Markéta Jakšová
Kategorie servisu: B
Sektor: malá firma
Počet automatů ve zdroji: 1', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('OLMIKA s.r.o.', 'Blučina', 'Blučina 627', 'OLMIKA s.r.o.', 'Michal Punčochář', '+420 774 954 766', null, 'Zdrojové kódy: SÍDLO
Zdrojové názvy: OLMIKA s.r.o.', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('TEXTILOMANIE', 'Blučina', 'Blučina 627', 'TEXTILOMANIE', 'Martin Kramoliš', '+420 777 173 911', 'MO,WE 7', 'Zdrojové kódy: 62
Zdrojové názvy: Blučina_TEXTILOMANIE
Trasy: LD_pátek_2TX7829,MN_pondělí_3BJ1780,LD_středa_2TX7829
Operátor: Markéta Jakšová, od 1.9.2025
Servisní dny: MO,WE 7
Kategorie servisu: C
Sektor: veřejné místo
Počet automatů ve zdroji: 2', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Střední škola hl. budova', 'Bohumín', 'Husova 283', 'Střední škola hl. budova', 'Ing. Martina Pešatová', '+420 731 134 088', 'TH 7', 'Zdrojové kódy: 70
Zdrojové názvy: Bohumín_Střední škola - hl. budova
Trasy: MN_pátek_3BJ1780
Operátor: Michaela Nerudová
Servisní dny: TH 7
Sektor: škola
Počet automatů ve zdroji: 1', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Střední škola vedl.budova', 'Bohumín', 'Čáslavská 420', 'Střední škola vedl.budova', 'Ing. Martina Pešatová', '+420 731 134 088', 'TH 7', 'Zdrojové kódy: 71
Zdrojové názvy: Bohumín_Střední škola - vedl.budova
Trasy: MN_pátek_3BJ1780
Operátor: Michaela Nerudová
Servisní dny: TH 7
Sektor: škola
Počet automatů ve zdroji: 1', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('BVK Pisárky', 'Brno', 'Pisárecká 555/1a', 'BVK Pisárky B jídelna', null, null, 'WE 7', 'Zdrojové kódy: 5, 6
Zdrojové názvy: Brno_BVK Pisárky B jídelna | Brno_BVK Pisárky hl. budova KÁVA
Trasy: LD_středa_2TX7829
Operátor: Markéta Jakšová, od 1.9.2025
Servisní dny: WE 7
Kategorie servisu: B | C
Sektor: střední firma
Počet automatů ve zdroji: 2', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('ESB', 'Brno', 'Vídeňská 297/99', 'ESB', null, null, '7 | WE 7', 'Zdrojové kódy: 60, 8
Zdrojové názvy: Brno_ESB KÁVA | Brno_ESB POTRAVINY
Servisní dny: 7 | WE 7', null, false);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Lasspektrum', 'Brno', 'Tovární 850', 'Lasspektrum', null, null, 'MO,WE 7 | TU 7', 'Zdrojové kódy: 1, 57
Zdrojové názvy: Brno_Lasspektrum KÁVA | Brno_Lasspektrum POTRAVINY
Trasy: LD_pondělí_2TX7928 | LD_středa_2TX7829,LD_pondělí_2TX7928,LD_pátek_2TX7829
Operátor: Markéta Jakšová, od 1.9.2025
Servisní dny: MO,WE 7 | TU 7
Kategorie servisu: B | C
Sektor: malá firma
Počet automatů ve zdroji: 2', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Marius Pedersen a.s.', 'Brno', 'Hájecká 1162/3', 'Marius Pedersen a.s.', 'Ing. Eliška Hrnčířová', '+420 730 809 966', 'MO 7', 'Zdrojové kódy: 84
Zdrojové názvy: Marius Pedersen a.s. KÁVA
Trasy: LD_pondělí_2TX7928
Servisní dny: MO 7
Počet automatů ve zdroji: 1', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('OLTEC a.s.', 'Brno', 'Václavská 6', 'OLTEC a.s.', 'Dočkalová', '+420 605 229 907', 'TH 7', 'Zdrojové kódy: 92
Zdrojové názvy: OLTEC a.s.
Operátor: Markéta Jakšová
Servisní dny: TH 7
Kategorie servisu: A
Sektor: veřejné místo', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('WINE LIFE a.s.', 'Brno', 'Železná 689/7b', 'WINE LIFE a.s.', null, '702 188 590', 'TU 7', 'Zdrojové kódy: 87
Zdrojové názvy: WINE LIFE a.s. KÁVA
Trasy: LD_pátek_2TX7829,LD_středa_2TX7829
Operátor: Markéta Jakšová, od 1.9.2025
Servisní dny: TU 7
Kategorie servisu: B
Sektor: malá firma
Počet automatů ve zdroji: 1', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Zimní stadion', 'Brno', 'Úvoz 1012', 'Zimní stadion', 'Čermák Jan', '+420 603 440 568', 'MO,WE,FR 7', 'Zdrojové kódy: 72
Zdrojové názvy: Brno_Zimní stadion
Trasy: MP_čtvrtek_5AP9000_NEW,LD_středa_2TX7829,LD_pátek_2TX7829,LD_pondělí_2TX7928
Operátor: Markéta Jakšová, od 1.9.2025
Servisní dny: MO,WE,FR 7
Kategorie servisu: A
Sektor: veřejné místo
Počet automatů ve zdroji: 1', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('NTS', 'Brno - Slatina', 'Tuřanka 1313', 'NTS', null, null, 'MO,WE,FR 7', 'Zdrojové kódy: 3
Zdrojové názvy: Brno_NTS
Trasy: LD_středa_2TX7829,LD_pondělí_2TX7928,LD_pátek_2TX7829
Operátor: Markéta Jakšová, od 1.9.2025
Servisní dny: MO,WE,FR 7
Kategorie servisu: A
Sektor: střední firma
Počet automatů ve zdroji: 1', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Marius Pedersen a.s.', 'Brno - Černovice', 'Hájecká 1162/3', 'Marius Pedersen a.s.', 'Ing. Eliška Hrnčířová', '+420 730 809 966', null, 'Zdrojové kódy: 82
Zdrojové názvy: Marius Pedersen a.s. POTRAVINY
Trasy: LD_středa_2TX7829,LD_pondělí_2TX7928,LD_pátek_2TX7829
Operátor: Markéta Jakšová, od 1.9.2025
Kategorie servisu: B
Sektor: malá firma
Počet automatů ve zdroji: 1', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('BVK Hády', 'Brno-Maloměřice a Obřany', 'Hády 971', 'BVK Hády', null, null, '7', 'Zdrojové kódy: 4
Zdrojové názvy: Brno_BVK Hády
Trasy: MP_čtvrtek_5AP9000_NEW,LD_pondělí_2TX7928
Operátor: Markéta Jakšová, od 1.9.2025
Servisní dny: 7
Kategorie servisu: A
Sektor: střední firma
Počet automatů ve zdroji: 1', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('OSRAM Česká republika s.r.o.', 'Bruntál', 'Zahradní 1442/46', 'OSRAM Česká republika s.r.o.', 'Václav Šípek', '602 562 117', 'MO 7 | MO,WE,FR 7', 'Zdrojové kódy: 80, 81
Zdrojové názvy: OSRAM Česká republika s.r.o. KÁVA | OSRAM Česká republika s.r.o. POTRAVINY
Trasy: MN_středa_3BJ1780
Servisní dny: MO 7 | MO,WE,FR 7
Počet automatů ve zdroji: 5', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('AVE', 'Břeclav', 'Sovadinova 841', 'AVE', null, null, 'TU 7', 'Zdrojové kódy: 12
Zdrojové názvy: Břeclav_AVE
Trasy: MP_pondělí_5AP9000_NEW
Servisní dny: TU 7
Počet automatů ve zdroji: 1', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Domov seniorů', 'Břeclav', 'Na Pešině 2842/13', 'Domov seniorů hl.budova', null, null, 'MO,WE,FR 7 | TU 7', 'Zdrojové kódy: 11, 56
Zdrojové názvy: Břeclav_Domov seniorů hl. budova POTRAVINY | Břeclav_Domov seniorů hl.budova KÁVA
Trasy: MP_pondělí_5AP9000_NEW
Servisní dny: MO,WE,FR 7 | TU 7
Počet automatů ve zdroji: 3', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Domov seniorů vedlejší budova', 'Břeclav', 'Seniorů 1', 'Domov seniorů vedlejší budova', null, null, 'TU 7', 'Zdrojové kódy: 10
Zdrojové názvy: Břeclav_Domov seniorů vedlejší budova
Trasy: MP_pondělí_5AP9000_NEW
Servisní dny: TU 7
Počet automatů ve zdroji: 1', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('SŠ Zdravotnická', 'Břeclav', 'Slovácká 322/1a', 'SŠ Zdravotnická', null, null, 'TU 7', 'Zdrojové kódy: 13
Zdrojové názvy: Břeclav_SŠ Zdravotnická
Trasy: MP_pondělí_5AP9000_NEW
Servisní dny: TU 7
Počet automatů ve zdroji: 1', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('ČD Cargo Břeclav', 'Břeclav', 'Železniční 3', 'ČD Cargo Břeclav', 'Ing. Krška Jan, Marek Šustáček', '602 439 571,724 076 565', 'TU 168', 'Zdrojové kódy: 45
Zdrojové názvy: ČD Cargo Břeclav
Servisní dny: TU 168', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('COOP', 'Chvalovice', 'Chvalovice 35', 'COOP', null, null, 'TH 14', 'Zdrojové kódy: 36
Zdrojové názvy: Chvalovice_COOP
Servisní dny: TH 14', null, false);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('RIGUM, s.r.o.', 'Dubňany', 'Jarohněvice 1666', 'RIGUM, s.r.o.', 'Martin Bartošík', '+420733533561', 'MO,TH 7', 'Zdrojové kódy: 93
Zdrojové názvy: RIGUM, s.r.o.
Trasy: MP_pondělí_5AP9000_NEW
Operátor: Michal Punčochář
Servisní dny: MO,TH 7
Kategorie servisu: A
Sektor: střední firma
Počet automatů ve zdroji: 1', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Monita', 'Havlíčkův Brod', 'Průmyslová 1032', 'Monita', 'Zuzana Běhunčíková', '+420 739 049 179', 'TH 7', 'Zdrojové kódy: 31
Zdrojové názvy: Havlíčkův Brod_Monita
Servisní dny: TH 7', null, false);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('ČD Cargo Havlíčkův Brod', 'Havlíčkův Brod', 'Havířská 724', 'ČD Cargo Havlíčkův Brod', 'Adamcová Eva, Marek Šustáček', '725 542 673, 724 076 565', 'TU 168', 'Zdrojové kódy: 44
Zdrojové názvy: ČD Cargo Havlíčkův Brod
Servisní dny: TU 168', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('COOP', 'Hevlín', 'Hevlín 59', 'COOP', null, null, 'TH 14', 'Zdrojové kódy: 35
Zdrojové názvy: Hevlín_COOP
Servisní dny: TH 14', null, false);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('bazén', 'Hrušovany nad Jevišovkou', 'Nádražní 438', 'bazén', null, null, 'TH 14', 'Zdrojové kódy: 34
Zdrojové názvy: Hrušovany nad Jevišovkou_bazén
Trasy: MP_pondělí_5AP9000_NEW
Servisní dny: TH 14
Počet automatů ve zdroji: 1', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Domov seniorů', 'Hustopeče u Brna', 'Hybešova 1497/7', 'Domov seniorů', null, null, 'TU 7', 'Zdrojové kódy: 9
Zdrojové názvy: Hustopeče_Domov seniorů
Trasy: MP_pondělí_5AP9000_NEW
Servisní dny: TU 7
Počet automatů ve zdroji: 1', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('SWR', 'Jamné', 'Jamné 48', 'SWR', 'Miroslav Eliáš', '725 969 544', 'TH 7', 'Zdrojové kódy: 24
Zdrojové názvy: Jamné_SWR
Trasy: MP_čtvrtek_5AP9000_NEW
Operátor: Markéta Jakšová, od 1.9.2025
Servisní dny: TH 7
Kategorie servisu: A
Sektor: malá firma
Počet automatů ve zdroji: 1', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Finanční úřad', 'Jihlava', 'Tolstého 1455', 'Finanční úřad', null, null, 'TH 7', 'Zdrojové kódy: 27
Zdrojové názvy: Jihlava_Finanční úřad
Servisní dny: TH 7', null, false);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Okresní soud', 'Jihlava', 'Tř. Legionářů 1470', 'Okresní soud', null, null, 'TH 7', 'Zdrojové kódy: 28
Zdrojové názvy: Jihlava_Okresní soud
Servisní dny: TH 7', null, false);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Sonepar', 'Jihlava', 'Heroltická 5449/19', 'Sonepar', 'Patrik Volf', '777 567 806', 'TH 7', 'Zdrojové kódy: 43
Zdrojové názvy: Jihlava_Sonepar
Trasy: MP_čtvrtek_5AP9000_NEW
Operátor: Markéta Jakšová, od 1.9.2025
Servisní dny: TH 7
Kategorie servisu: B
Sektor: malá firma
Počet automatů ve zdroji: 1', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('VO Vrtal', 'Jihlava', 'Znojemská 5433', 'VO Vrtal', null, null, 'TH 7', 'Zdrojové kódy: 26
Zdrojové názvy: Jihlava_VO Vrtal
Trasy: MP_čtvrtek_5AP9000_NEW
Operátor: Markéta Jakšová, od 1.9.2025
Servisní dny: TH 7
Kategorie servisu: B
Sektor: malá firma
Počet automatů ve zdroji: 1', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('VOŠ', 'Jihlava', 'Srázná 21', 'VOŠ', 'Mgr. Marcela Křivánková', '724 162 933', 'TH 7', 'Zdrojové kódy: 29
Zdrojové názvy: Jihlava_VOŠ
Trasy: MP_čtvrtek_5AP9000_NEW
Operátor: Markéta Jakšová, od 1.9.2025
Servisní dny: TH 7
Kategorie servisu: B
Sektor: školy, úřady
Počet automatů ve zdroji: 2', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Úřad práce', 'Jihlava', 'Brtnická 2531', 'Úřad práce', null, null, 'TH 7', 'Zdrojové kódy: 25
Zdrojové názvy: Jihlava_Úřad práce
Servisní dny: TH 7', null, false);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('SPEED', 'Kyjov', 'Svatoborská 427/89', 'SPEED', null, '+420 734 221 795', 'FR 14', 'Zdrojové kódy: 39
Zdrojové názvy: Kyjov_SPEED
Trasy: MP_pondělí_5AP9000_NEW
Servisní dny: FR 14
Počet automatů ve zdroji: 2', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Primasil', 'Mikulov', 'Gagarinova 1239', 'Primasil', null, null, 'MO,TU,WE,TH,FR 7', 'Zdrojové kódy: 54
Zdrojové názvy: Mikulov_Primasil POTRAVINY
Servisní dny: MO,TU,WE,TH,FR 7', null, false);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Zámek SEZÓNKA', 'Mikulov', 'Zámek 1/4', 'Zámek SEZÓNKA', 'Martina Klimešová', '774163855', 'MO,FR 7', 'Zdrojové kódy: 49
Zdrojové názvy: Mikulov_Zámek SEZÓNKA
Servisní dny: MO,FR 7', null, false);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Primasil', 'Mikulov na Moravě', 'Gagarinova 1239', 'Primasil', null, null, 'TU 7', 'Zdrojové kódy: 15
Zdrojové názvy: Mikulov_Primasil KÁVA
Servisní dny: TU 7', null, false);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('AZ Klima', 'Milovice', 'Milovice 156', 'AZ Klima', null, null, 'MO,WE 7 | TU 7', 'Zdrojové kódy: 14, 55
Zdrojové názvy: Milovice_AZ Klima KÁVA | Milovice_AZ Klima POTRAVINY
Trasy: MP_čtvrtek_5AP9000_NEW,MP_pondělí_5AP9000_NEW
Servisní dny: MO,WE 7 | TU 7
Počet automatů ve zdroji: 2', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Bylinky jídelna', 'Miroslav', 'Suchohrdly u Miroslavi 208', 'Bylinky jídelna', null, null, 'MO,WE 7 | TU 7', 'Zdrojové kódy: 17, 51
Zdrojové názvy: Suchohrdly_Bylinky jídelna KÁVA | Suchohrdly_Bylinky jídelna POTRAVINY
Servisní dny: MO,WE 7 | TU 7', null, false);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Bylinky nová hala', 'Miroslav', 'Suchohrdly u Miroslavi 208', 'Bylinky nová hala', null, null, 'MO,WE,FR 7 | TU 7', 'Zdrojové kódy: 18, 52
Zdrojové názvy: Suchohrdly_Bylinky nová hala KÁVA | Suchohrdly_Bylinky nová hala POTRAVINY
Servisní dny: MO,WE,FR 7 | TU 7', null, false);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('BVK ČOV Modřice', 'Modřice', 'Svratecká 989', 'BVK ČOV Modřice', null, null, 'TU 7', 'Zdrojové kódy: 33
Zdrojové názvy: Brno_BVK ČOV Modřice
Trasy: LD_pátek_2TX7829
Operátor: Markéta Jakšová, od 1.9.2025
Servisní dny: TU 7
Kategorie servisu: C
Sektor: malá firma
Počet automatů ve zdroji: 1', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Microtechnic', 'Modřice', 'Evropská 884', 'Microtechnic', 'Ivana Ambrožová', '+420 703 144 039', 'TU 7 | TU,FR 7', 'Zdrojové kódy: 76, 77
Zdrojové názvy: Microtechnic KÁVA | Microtechnic POTRAVINY
Trasy: LD_pondělí_2TX7928 | LD_pátek_2TX7829,LD_pondělí_2TX7928,LD_středa_2TX7829
Operátor: Markéta Jakšová, od 1.9.2025
Servisní dny: TU 7 | TU,FR 7
Kategorie servisu: B
Sektor: malá firma
Počet automatů ve zdroji: 2', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Vinařství', 'Mutěnice', 'Údolní 1174', 'Vinařství', null, null, 'FR 14', 'Zdrojové kódy: 38
Zdrojové názvy: Mutěnice_Vinařství
Trasy: MP_pondělí_5AP9000_NEW
Servisní dny: FR 14
Počet automatů ve zdroji: 1', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Plastia', 'Nové Veselí', 'Žďárská 313', 'Plastia', null, null, 'WE 14', 'Zdrojové kódy: 30
Zdrojové názvy: Nové Veselí_Plastia
Servisní dny: WE 14', null, false);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('TEXTILOMÁNIE', 'Opatovice', 'Velké dráhy 74e', 'TEXTILOMÁNIE', 'Martin Kramoliš', '+420 777 173 911', 'FR 7 | MO,WE,FR 7', 'Zdrojové kódy: 63, 64
Zdrojové názvy: Opatovice_TEXTILOMÁNIE KÁVA | Opatovice_TEXTILOMÁNIE POTRAVINY
Trasy: LD_pátek_2TX7829 | LD_pátek_2TX7829,LD_pondělí_2TX7928
Operátor: Markéta Jakšová, od 1.9.2025
Servisní dny: FR 7 | MO,WE,FR 7
Kategorie servisu: C
Sektor: malá firma
Počet automatů ve zdroji: 2', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Pošta Ostrava 23', 'Ostrava', 'Martinovská 3168/48', 'Pošta Ostrava 23', null, null, 'MO 7', 'Zdrojové kódy: 88
Zdrojové názvy: Pošta Ostrava 23
Servisní dny: MO 7
Kategorie servisu: D
Sektor: veřejné místo', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Sportovní Hala Krásné Pole', 'Ostrava', 'Sklopčická 860', 'Sportovní Hala Krásné Pole', 'Marek Doležílek', '+420 774 637 167', null, 'Zdrojové kódy: 89
Zdrojové názvy: Sportovní Hala Krásné Pole
Trasy: MN_pátek_3BJ1780,MN_pondělí_3BJ1780
Operátor: Veronika Jirdová
Kategorie servisu: A
Sektor: veřejné místo
Počet automatů ve zdroji: 2', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('ViaPharma', 'Ostrava', '17. listopadu,', 'ViaPharma', 'Tomáš Kurka', '608 709 947', 'FR 7', 'Zdrojové kódy: 65
Zdrojové názvy: Ostrava_ViaPharma KÁVA
Trasy: MN_pátek_3BJ1780
Servisní dny: FR 7
Počet automatů ve zdroji: 1', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('ViaPharma_POTRAVINY', 'Ostrava', '17. listopadu', 'ViaPharma_POTRAVINY', 'Tomáš Kurka', '608 709 947', 'TU,FR 7', 'Zdrojové kódy: 48
Zdrojové názvy: Ostrava_ViaPharma_POTRAVINY
Trasy: MN_pátek_3BJ1780,MN_středa_3BJ1780,MN_pondělí_3BJ1780
Servisní dny: TU,FR 7
Počet automatů ve zdroji: 1', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('REMANTE GROUP s.r.o.', 'Otice', 'K Rybníčkům 13', 'REMANTE GROUP s.r.o.', 'Bártková Jarmila', '724 873 740', 'TH 7', 'Zdrojové kódy: 85, 86
Zdrojové názvy: REMANTE GROUP s.r.o. KÁVA | REMANTE GROUP s.r.o. POTRAVINY
Trasy: MN_pátek_3BJ1780,MN_středa_3BJ1780 | MN_středa_3BJ1780
Servisní dny: TH 7
Počet automatů ve zdroji: 2', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Archeopark SEZÓNKA', 'Pavlov', '23. dubna 264', 'Archeopark SEZÓNKA', 'Mgr. Zuzana HAVLICKÁ', '+420 720 948 231', 'MO,FR 7', 'Zdrojové kódy: 50
Zdrojové názvy: Pavlov_Archeopark SEZÓNKA
Servisní dny: MO,FR 7', null, false);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('ViaPharma', 'Podolí u Brna', '664 03 Podolí u Brna', 'ViaPharma', 'Seget Tomáš', '734 520 978', 'MO,TU,WE,FR 7', 'Zdrojové kódy: 47
Zdrojové názvy: Brno_ViaPharma KÁVA
Trasy: MN_pondělí_3BJ1780
Operátor: Markéta Jakšová, od 1.9.2025
Servisní dny: MO,TU,WE,FR 7
Kategorie servisu: A
Sektor: střední firma
Počet automatů ve zdroji: 2', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('ViaPharma', 'Podolí u Brna', null, 'ViaPharma', null, null, 'MO,WE,FR 7', 'Zdrojové kódy: 59
Zdrojové názvy: Brno_ViaPharma POTRAVINY
Trasy: MN_pondělí_3BJ1780,LD_pátek_2TX7829,LD_středa_2TX7829
Operátor: Markéta Jakšová, od 1.9.2025
Servisní dny: MO,WE,FR 7
Kategorie servisu: A
Sektor: střední firma
Počet automatů ve zdroji: 2', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Apex', 'Pohořelice', 'Vídeňská 1513', 'Apex', null, null, 'MO,WE 7 | TU 7', 'Zdrojové kódy: 16, 53
Zdrojové názvy: Pohořelice_Apex KÁVA | Pohořelice_Apex POTRAVINY
Trasy: MP_pondělí_5AP9000_NEW
Operátor: Markéta Jakšová, od 1.9.2025
Servisní dny: MO,WE 7 | TU 7
Kategorie servisu: B
Sektor: malá firma
Počet automatů ve zdroji: 2', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('stavba', 'Slavkov u Brna', 'Sadova', 'stavba', 'Lukáš Blaha', '+420 608 833 168', 'MO 7', 'Zdrojové kódy: 73
Zdrojové názvy: Slavkov u Brna_stavba
Servisní dny: MO 7', null, false);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Sportisimo', 'Slezská Ostrava-Hrušov', 'Žižkova', 'Sportisimo', 'Renata Hujdičová', '+420 720 935 298', '1 | MO,TH 7 | MO,TU,WE,TH,FR 7', 'Zdrojové kódy: 19, 66, 67
Zdrojové názvy: Ostrava_Sportisimo COLA | Ostrava_Sportisimo KÁVA | Ostrava_Sportisimo POTRAVINY
Trasy: MN_pondělí_3BJ1780,MN_středa_3BJ1780,MN_pátek_3BJ1780 | MN_pátek_3BJ1780,MN_středa_3BJ1780,MN_pondělí_3BJ1780
Servisní dny: 1 | MO,TH 7 | MO,TU,WE,TH,FR 7
Počet automatů ve zdroji: 7', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Hotel Kovák', 'Slezská Ostrava-Kunčice', 'Vratimovská 142', 'Hotel Kovák', 'Ivana Zavadilová', null, 'MO,WE 7 | TU 7', 'Zdrojové kódy: 68, 69
Zdrojové názvy: Ostrava_Hotel Kovák - KÁVA | Ostrava_Hotel Kovák - POTRAVINY
Trasy: MN_pátek_3BJ1780 | MN_středa_3BJ1780,MN_pátek_3BJ1780,MN_pondělí_3BJ1780
Servisní dny: MO,WE 7 | TU 7
Počet automatů ve zdroji: 3', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Vitar', 'Tišnov', 'Železné 113', 'Vitar', 'Rober Buček', '+420 728 360 893', 'FR 7 | MO,WE,FR 7', 'Zdrojové kódy: 74, 75
Zdrojové názvy: Tišnov_Vitar KÁVA | Tišnov_Vitar POTRAVINY
Trasy: LD_pondělí_2TX7928 | LD_pondělí_2TX7928,LD_středa_2TX7829,MP_čtvrtek_5AP9000_NEW,LD_pátek_2TX7829
Operátor: Markéta Jakšová, od 1.9.2025
Servisní dny: FR 7 | MO,WE,FR 7
Kategorie servisu: A
Sektor: střední firma
Počet automatů ve zdroji: 3', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Dvořák Truck', 'Velké Meziříčí', 'Karlov 1119', 'Dvořák Truck', null, null, 'TH 7', 'Zdrojové kódy: 21
Zdrojové názvy: Velké Meziříčí_Dvořák Truck
Servisní dny: TH 7', null, false);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Kabelové Bubny', 'Velké Meziříčí', 'Františkov 88/10', 'Kabelové Bubny', null, '+420 777 717 884', 'TH 7', 'Zdrojové kódy: 22
Zdrojové názvy: Velké Meziříčí_Kabelové Bubny
Trasy: MP_čtvrtek_5AP9000_NEW
Operátor: Markéta Jakšová, od 1.9.2025
Servisní dny: TH 7
Kategorie servisu: B
Sektor: malá firma
Počet automatů ve zdroji: 1', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Paramont', 'Velké Meziříčí', 'Třebíčská 194', 'Paramont', null, null, 'TH 7', 'Zdrojové kódy: 23
Zdrojové názvy: Velké Meziříčí_Paramont
Trasy: MP_čtvrtek_5AP9000_NEW
Operátor: Markéta Jakšová, od 1.9.2025
Servisní dny: TH 7
Kategorie servisu: C
Sektor: malá firma
Počet automatů ve zdroji: 1', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Dendro', 'Znojmo', 'Dr. M. Horákové 861', 'Dendro', null, null, 'TH 14', 'Zdrojové kódy: 37
Zdrojové názvy: Znojmo_Dendro
Servisní dny: TH 14
Počet automatů ve zdroji: 1', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('KILI', 'Šlapanice u Brna', 'Hybešova 1647', 'KILI', null, null, 'MO,WE,FR 7 | TU 7', 'Zdrojové kódy: 2, 58
Zdrojové názvy: Brno_KILI KÁVA | Brno_Kili POTRAVINY
Trasy: LD_pondělí_2TX7928 | LD_pondělí_2TX7928,LD_středa_2TX7829,LD_pátek_2TX7829
Operátor: Markéta Jakšová, od 1.9.2025
Servisní dny: MO,WE,FR 7 | TU 7
Kategorie servisu: B
Sektor: malá firma', null, false);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('VN machinery s.r.o.', 'Židlochovice', 'Nádražní 919', 'VN machinery s.r.o.', 'Ing. Andrea Nečasová', '+420 604 800 109', 'FR 7', 'Zdrojové kódy: 91
Zdrojové názvy: VN machinery s.r.o.
Trasy: MP_pondělí_5AP9000_NEW
Operátor: Markéta Jakšová
Servisní dny: FR 7
Kategorie servisu: B
Sektor: malá firma
Počet automatů ve zdroji: 1', null, true);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Okresní soud', 'Žďár nad Sázavou', 'Strojírenská 2210/28', 'Okresní soud', 'Ing. Monika Sobotková', '601 090 786', 'TH 14', 'Zdrojové kódy: 42
Zdrojové názvy: Žďár nad Sázavou_Okresní soud
Servisní dny: TH 14', null, false);
insert into public.locations (name, city, address, customer_name, contact_person, contact_phone, service_window, route_note, vendsoft_location_id, active) values ('Poliklinika', 'Žďár nad Sázavou', 'Studentská 1699 /4', 'Poliklinika', null, null, 'TH 14', 'Zdrojové kódy: 32
Zdrojové názvy: Žďár nad Sázavou_Poliklinika
Servisní dny: TH 14', null, false);
