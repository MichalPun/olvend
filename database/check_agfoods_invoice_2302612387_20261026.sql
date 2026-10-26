select json_build_object(
  'existing_invoice', (
    select json_agg(json_build_object(
      'id', id,
      'status', status,
      'invoice_number', invoice_number,
      'delivery_note_number', delivery_note_number
    ))
    from public.purchase_orders
    where replace(upper(coalesce(invoice_number, '')), ' ', '') = 'P012302612387'
      and status <> 'cancelled'
  ),
  'candidate_products', (
    select json_agg(json_build_object(
      'id', p.id,
      'sku', p.sku,
      'name', p.name,
      'ean', p.ean,
      'base_unit', p.base_unit,
      'purchase_price', p.purchase_price,
      'image_path', p.image_path,
      'packages', (
        select json_agg(json_build_object(
          'id', pp.id,
          'name', pp.package_name,
          'units', pp.units_per_package,
          'default', pp.is_default
        ) order by pp.id)
        from public.product_packages pp
        where pp.product_id = p.id
      )
    ) order by p.id)
    from public.products p
    where p.active = true
      and (
        lower(coalesce(p.name, '')) like '%cream%'
        or lower(coalesce(p.name, '')) like '%sophia%'
        or lower(coalesce(p.name, '')) like '%staccato%'
        or p.sku = '44'
      )
  ),
  'supplier_mappings', (
    select json_agg(json_build_object(
      'id', spm.id,
      'supplier_id', spm.supplier_id,
      'product_id', spm.product_id,
      'code', spm.supplier_item_code,
      'name', spm.supplier_item_name,
      'units', spm.base_units_per_invoice_unit,
      'price', spm.last_unit_price
    ) order by spm.id)
    from public.supplier_product_mappings spm
    where spm.supplier_id = 11
      and spm.supplier_item_code in ('20430', '510006', '676230')
  )
) as result;
