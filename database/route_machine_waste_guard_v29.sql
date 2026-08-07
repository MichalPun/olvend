begin;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.stock_movements_v13'::regclass
      and conname = 'stock_movements_v13_waste_has_no_destination'
  ) then
    alter table public.stock_movements_v13
      add constraint stock_movements_v13_waste_has_no_destination
      check (movement_type <> 'waste' or to_stock_location_id is null);
  end if;
end $$;

commit;
