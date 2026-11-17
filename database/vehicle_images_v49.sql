begin;

alter table public.vehicles
  add column if not exists image_path text;

comment on column public.vehicles.image_path is
  'Relativní cesta k fotografii konkrétního vozidla používaná v aplikacích OLVEND.';

update public.vehicles
set image_path = case replace(upper(coalesce(plate, '')), ' ', '')
  when '3BU9736' then 'static:../assets/vehicles/fiat-doblo-2012.png'
  when '5AP9000' then 'static:../assets/vehicles/fiat-doblo-modern.png'
  when '7Z71808' then 'static:../assets/vehicles/opel-combo-2024-passenger.png'
  when '2BN7419' then 'static:../assets/vehicles/opel-movano-older.png'
  when '2TX7928' then 'static:../assets/vehicles/renault-kangoo-2019.png'
  else image_path
end
where image_path is null;

commit;
