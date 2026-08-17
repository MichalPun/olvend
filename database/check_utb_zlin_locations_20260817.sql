select jsonb_build_object(
  'existing_locations', (
    select coalesce(jsonb_agg(to_jsonb(location_row) order by location_row.name), '[]'::jsonb)
    from (
      select
        id, name, city, address, customer_name, active,
        latitude, longitude, route_note
      from public.locations
      where lower(coalesce(name, '')) like any (array['%utb%', '%tomáše bati%', '%tgm%'])
         or lower(coalesce(customer_name, '')) like any (array['%utb%', '%univerzita tomáše bati%'])
         or (
           lower(coalesce(city, '')) = 'zlín'
           and lower(coalesce(address, '')) like any (
             array['%vavrečkova%', '%univerzitní%', '%nad stráněmi%', '%nad ovčírnou%', '%t. g. masaryka%', '%tgm%', '%štefánikova%', '%antonínova%']
           )
         )
    ) location_row
  ),
  'columns', (
    select jsonb_agg(jsonb_build_object(
      'name', column_name,
      'type', data_type,
      'nullable', is_nullable
    ) order by ordinal_position)
    from information_schema.columns
    where table_schema = 'public' and table_name = 'locations'
  )
) as audit;
