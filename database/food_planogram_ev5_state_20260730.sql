-- Aktuální fyzický stav EV 5 / Europa Snack podle planogramu 2026-07-30.
-- Sortiment, SKU a schválené náhrady zůstávají beze změny.
-- Expirace ze zdrojového Excelu se podle pokynu uživatele nepřebírají.
begin;

update public.machine_planogram_slots s
set
  price_czk = v.price_czk,
  dex_price_czk = v.dex_price_czk,
  current_units = v.current_units,
  last_units = v.last_units,
  capacity_units = v.capacity_units,
  target_units = least(v.capacity_units, v.current_units + v.desired_units),
  desired_units = v.desired_units,
  fill_percent = case
    when v.capacity_units > 0 then least(100, round(v.current_units::numeric / v.capacity_units::numeric * 100, 2))
    else 0
  end,
  expiry_date = null,
  note = concat_ws(' · ', nullif(s.note, ''), 'Aktuální stav převzat z planogramu 2026-07-30; expirace nepřevzata.'),
  updated_at = now()
from (values
  ('1',19,4,6,6,19,2),('2',19,6,6,6,19,0),('3',27,3,6,6,27,3),
  ('4',48,6,6,6,48,0),('5',25,6,6,6,25,0),('6',15,6,6,6,15,0),
  ('7',25,5,6,6,25,1),('12',33,5,6,6,33,1),('13',30,6,6,6,30,0),
  ('14',32,6,6,6,32,0),('15',24,4,6,6,24,2),('16',29,6,6,6,29,0),
  ('17',39,6,6,6,39,0),('18',28,6,6,6,28,0),('23',55,2,5,5,55,3),
  ('24',55,5,5,5,55,0),('25',55,5,5,5,55,0),('26',19,6,6,6,19,0),
  ('27',25,5,5,5,25,0),('28',29,6,6,6,29,0),('29',29,6,6,6,29,0),
  ('34',26,14,15,15,26,1),('35',20,10,10,10,20,0),('36',11,15,15,15,11,0),
  ('37',26,11,11,15,26,4),('38',30,10,10,10,30,0),('39',25,10,10,10,25,0),
  ('40',8,15,15,15,8,0),('45',26,15,15,15,26,0),('46',24,15,15,15,24,0),
  ('47',11,19,20,20,11,1),('48',14,15,15,15,14,0),('49',24,20,20,20,24,0),
  ('50',30,15,15,15,30,0),('51',21,10,10,10,21,0),('57',27,10,10,10,27,0),
  ('59',20,2,2,2,20,0),('61',19,6,6,5,19,0),('62',21,10,10,10,21,0)
) as v(slot_code, price_czk, current_units, last_units, capacity_units, dex_price_czk, desired_units)
where s.machine_id = 3
  and s.slot_code = v.slot_code
  and s.active = true;

do $$
declare
  v_count integer;
begin
  select count(*) into v_count
  from public.machine_planogram_slots
  where machine_id = 3 and active = true;
  if v_count <> 39 then
    raise exception 'EV 5: expected 39 active slots, found %', v_count;
  end if;
end
$$;

commit;
notify pgrst, 'reload schema';
