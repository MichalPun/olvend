begin;

do $$
declare
  v_updated integer;
begin
  if not exists (select 1 from products where sku = '67' and active = true)
     or not exists (select 1 from products where sku = '275' and active = true) then
    raise exception 'Nestea Peach SKU 67 or Nestea Lemon SKU 275 is not active';
  end if;

  update machine_planogram_slots
  set product_family = 'Nestea',
      substitution_policy = 'approved_list',
      allowed_substitutes = 'Nestea Peach 0,5l (SKU 67); Nestea Lemon 0,5l (SKU 275)',
      operator_instruction = regexp_replace(
        coalesce(operator_instruction, ''),
        '^Přednostně Peach SKU 67; lze použít Lemon SKU 275\.?(\s*)',
        'Použij dostupnou příchuť z auta: Peach SKU 67 nebo Lemon SKU 275. '
      )
  where active = true
    and (
      product_sku in ('67', '275')
      or lower(coalesce(product_name, '')) like '%nestea%'
      or lower(coalesce(product_family, '')) = 'nestea'
    );

  get diagnostics v_updated = row_count;
  if v_updated <> 24 then
    raise exception 'Expected 24 active Nestea slots, updated %', v_updated;
  end if;
end $$;

commit;
