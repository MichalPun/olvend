begin;

-- Exact retail identities and verified local packshots for BRIMEX invoice
-- 202601100. Sale prices are intentionally left unchanged until the price list
-- is approved.
do $$
declare
  v_expected integer;
  v_updated integer;
  v_conflicts text;
begin
  select count(*)
    into v_expected
  from public.products
  where (id, sku) in (
    (257, '0011'), (258, '0014'), (259, '0017'), (260, '0022'),
    (261, '0024'), (262, '0025'), (263, '0028'), (264, '0032')
  );

  if v_expected <> 8 then
    raise exception 'Expected all 8 BRIMEX product cards, found %.', v_expected;
  end if;

  select string_agg(format('product %s already has EAN %s', id, ean), ', ' order by id)
    into v_conflicts
  from public.products
  where trim(coalesce(ean, '')) in (
    '3838945041713', '3838945035293', '3838945037808', '3838945501392',
    '3838945043694', '3838945043663', '3838945501248', '3838945508094'
  )
    and id not in (257, 258, 259, 260, 261, 262, 263, 264);

  if v_conflicts is not null then
    raise exception 'EAN conflict: %', v_conflicts;
  end if;

  update public.products as product
  set
    name = source.name,
    ean = source.ean,
    image_path = source.image_path,
    image_updated_at = now(),
    note = source.note,
    updated_at = now()
  from (values
    (257, '0011', 'Fructal First Aloe Vera & hrozno 0,5 l', '3838945041713', 'static:./assets/product-images/ean-3838945041713.jpg', E'[olvend_product_kind:water_product]\nNáhradová skupina: Funkční nápoj. Příchuť: Aloe vera & hrozno. Dodavatel: BRIMEX CZ, s.r.o. / FRUCTAL.'),
    (258, '0014', 'Fructal First Antistress Hruška & levandule 0,5 l', '3838945035293', 'static:./assets/product-images/ean-3838945035293.png', E'[olvend_product_kind:water_product]\nNáhradová skupina: Funkční nápoj. Příchuť: Hruška & levandule. Dodavatel: BRIMEX CZ, s.r.o. / FRUCTAL.'),
    (259, '0017', 'Fructal First Protect Citron & citronová tráva 0,5 l', '3838945037808', 'static:./assets/product-images/ean-3838945037808.png', E'[olvend_product_kind:water_product]\nNáhradová skupina: Funkční nápoj. Příchuť: Citron & citronová tráva. Dodavatel: BRIMEX CZ, s.r.o. / FRUCTAL.'),
    (260, '0022', 'FRUC Pomeranč & citron 0,5 l', '3838945501392', 'static:./assets/product-images/ean-3838945501392.png', E'[olvend_product_kind:water_product]\nNáhradová skupina: FRUC. Příchuť: Pomeranč & citron. Dodavatel: BRIMEX CZ, s.r.o. / FRUCTAL.'),
    (261, '0024', 'FRUC Ice Tea Lesní plody 0,5 l', '3838945043694', 'static:./assets/product-images/ean-3838945043694.png', E'[olvend_product_kind:water_product]\nNáhradová skupina: Ice Tea. Příchuť: Lesní plody. Dodavatel: BRIMEX CZ, s.r.o. / FRUCTAL.'),
    (262, '0025', 'FRUC Ice Tea Broskev 0,5 l', '3838945043663', 'static:./assets/product-images/ean-3838945043663.png', E'[olvend_product_kind:water_product]\nNáhradová skupina: Ice Tea. Příchuť: Broskev. Dodavatel: BRIMEX CZ, s.r.o. / FRUCTAL.'),
    (263, '0028', 'FRUC Multivitamin 0,5 l', '3838945501248', 'static:./assets/product-images/ean-3838945501248.png', E'[olvend_product_kind:water_product]\nNáhradová skupina: FRUC. Příchuť: Multivitamin. Dodavatel: BRIMEX CZ, s.r.o. / FRUCTAL.'),
    (264, '0032', 'FRUC Černý rybíz & arónie 0,5 l', '3838945508094', 'static:./assets/product-images/ean-3838945508094.webp', E'[olvend_product_kind:water_product]\nNáhradová skupina: FRUC. Příchuť: Černý rybíz & arónie. Dodavatel: BRIMEX CZ, s.r.o. / FRUCTAL.')
  ) as source(id, sku, name, ean, image_path, note)
  where product.id = source.id
    and product.sku = source.sku;

  get diagnostics v_updated = row_count;
  if v_updated <> 8 then
    raise exception 'Expected to update 8 BRIMEX product cards, updated %.', v_updated;
  end if;

  -- The new FRUC Ice Tea 0.5 l variants are supplied in 12-piece cartons.
  update public.product_packages
  set units_per_package = 12,
      updated_at = now()
  where product_id in (261, 262)
    and package_name = 'Celé balení'
    and active is true;

  get diagnostics v_updated = row_count;
  if v_updated <> 2 then
    raise exception 'Expected to update 2 FRUC Ice Tea cartons, updated %.', v_updated;
  end if;
end
$$;

commit;

notify pgrst, 'reload schema';
