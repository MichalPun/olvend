-- Doplnění chybějící převodky podle výsledku cesty VendSoft 1291026.
-- Cesta: 21. 7. 2026, Sandra Svobodová, automat [102] RHFS1 BUTTONS16.
-- Doplněno: 2 balení oVe FD COFFEE SOPHIA 500g = 1 kg.
-- Zdroj: Opel Combo 7Z71808 (stock_location_id 6).
-- Cíl: sklad Automaty (stock_location_id 5).

do $$
declare
  v_reference_id text := 'manual-transfer:vendsoft-trip-1291026-machine-102';
begin
  if not exists (
    select 1
    from public.stock_movements_v13
    where reference_type = 'manual_transfer'
      and reference_id = v_reference_id
  ) then
    perform public.apply_stock_movements_v13(
      jsonb_build_array(
        jsonb_build_object(
          'product_id', 108,
          'batch_id', null,
          'from_stock_location_id', 6,
          'to_stock_location_id', 5,
          'movement_type', 'fill_machine',
          'quantity_base_units', 1,
          'reference_type', 'manual_transfer',
          'reference_id', v_reference_id,
          'note', '2026-07-21 · převod vozidlo → Automaty · VendSoft trip 1291026 · Sandra Svobodová · automat [102] RHFS1 BUTTONS16 · Sophia 2 × 0,5 kg = 1,00 kg'
        )
      )
    );
  end if;
end
$$;
