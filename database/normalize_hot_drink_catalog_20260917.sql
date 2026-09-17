begin;

-- Telemetrie historicky posilala ruzne textove nazvy pro stejny napoj.
-- SKU je stabilni identita; katalog proto drzi jeden aktualni nazev a typ.
with hot_drink_skus(sku) as (
  values
    ('238'),
    ('283'), ('284'), ('285'), ('286'), ('287'), ('288'), ('289'),
    ('290'), ('291'), ('292'), ('293'), ('294'), ('295'), ('296'),
    ('297'), ('298'), ('299'),
    ('304'), ('305'), ('306'), ('307')
), hot_drinks as (
  select product.id
  from public.products product
  where coalesce(product.note, '') ilike '%Zdrojový typ: Teplé nápoje%'
     or product.sku in (select sku from hot_drink_skus)
)
update public.products product
set
  name = regexp_replace(btrim(product.name), '\s+NEW$', '', 'i'),
  product_category = 'beverage_ready',
  note = case
    when coalesce(product.note, '') ~ '\[olvend_product_kind:hot_drink\]' then product.note
    when nullif(btrim(product.note), '') is null then '[olvend_product_kind:hot_drink]'
    else '[olvend_product_kind:hot_drink]' || E'\n' || btrim(product.note)
  end,
  updated_at = now()
where product.id in (select id from hot_drinks);

do $$
begin
  if exists (
    select 1
    from public.products product
    where (
      coalesce(product.note, '') ilike '%Zdrojový typ: Teplé nápoje%'
      or product.sku in (
        '238', '283', '284', '285', '286', '287', '288', '289',
        '290', '291', '292', '293', '294', '295', '296', '297',
        '298', '299', '304', '305', '306', '307'
      )
    )
      and (
        product.product_category <> 'beverage_ready'
        or coalesce(product.note, '') !~ '\[olvend_product_kind:hot_drink\]'
        or product.name ~* '\s+NEW$'
      )
  ) then
    raise exception 'Normalizace katalogu teplych napoju nebyla uplna.';
  end if;
end;
$$;

commit;
