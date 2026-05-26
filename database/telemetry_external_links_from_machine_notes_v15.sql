insert into public.machine_external_links (
  machine_id,
  provider,
  external_machine_id,
  telemetry_enabled,
  note
)
select
  id as machine_id,
  provider,
  substring(note from 'Telemetry ID: ([0-9]+)') as external_machine_id,
  true as telemetry_enabled,
  'Backfill z importni poznamky automatu.' as note
from public.machines
cross join (values ('IMA'), ('GP')) as providers(provider)
where note ~ 'Telemetry ID: [0-9]+'
on conflict (provider, external_machine_id) do update
set
  machine_id = excluded.machine_id,
  telemetry_enabled = true,
  note = excluded.note;

with imported_links(source_code, telemetry_id) as (
  values
    ('1', '592146'),
    ('3', '582177'),
    ('5', '597850'),
    ('6', '597851'),
    ('7', '582173'),
    ('9', '597849'),
    ('12', '592145'),
    ('16', '602221'),
    ('17', '596512'),
    ('18', '604306'),
    ('19', '592143'),
    ('20', '587382'),
    ('22', '597848'),
    ('23', '582171'),
    ('27', '596509'),
    ('28', '602228'),
    ('29', '596507'),
    ('31', '592149'),
    ('32', '582178'),
    ('35', '596504'),
    ('36', '602225'),
    ('38', '602222'),
    ('42', '596506'),
    ('43', '587376'),
    ('45', '592151'),
    ('58', '596505'),
    ('65', '596503'),
    ('67', '592144'),
    ('71', '582170'),
    ('72', '582175'),
    ('73', '602224'),
    ('74', '587379'),
    ('76', '598500'),
    ('77', '598501'),
    ('78', '587377'),
    ('79', '604313'),
    ('80', '592150'),
    ('81', '598502'),
    ('82', '598504'),
    ('83', '598503'),
    ('84', '597852'),
    ('85', '602226'),
    ('86', '602227'),
    ('87', '602229'),
    ('88', '604310'),
    ('89', '596511'),
    ('90', '592147'),
    ('91', '604309'),
    ('92', '604315'),
    ('93', '604314'),
    ('94', '604311'),
    ('95', '604312'),
    ('96', '602223'),
    ('97', '587380'),
    ('98', '596508'),
    ('99', '582172'),
    ('100', '582176'),
    ('101', '587374'),
    ('102', '604308'),
    ('103', '587375'),
    ('107', '596510'),
    ('110', '592148'),
    ('111', '587373'),
    ('123', '604307')
)
insert into public.machine_external_links (
  machine_id,
  provider,
  external_machine_id,
  telemetry_enabled,
  note
)
select
  machines.id as machine_id,
  providers.provider,
  imported_links.telemetry_id as external_machine_id,
  true as telemetry_enabled,
  'Backfill z VendSoft kodu automatu.' as note
from imported_links
join public.machines
  on machines.qr_token = 'vendsoft-' || imported_links.source_code
cross join (values ('IMA'), ('GP')) as providers(provider)
on conflict (provider, external_machine_id) do update
set
  machine_id = excluded.machine_id,
  telemetry_enabled = true,
  note = excluded.note;
