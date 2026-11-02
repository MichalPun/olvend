begin;

-- Verified public packshots shared by the PC product master and Zebra pick list.
update public.products
set image_path = case trim(sku)
  when '43' then 'static:./assets/product-images/43.webp'
  when '46' then 'static:./assets/product-images/46.webp'
  when '49' then 'static:./assets/product-images/49.webp'
  when '51' then 'static:./assets/product-images/51.webp'
  when '197' then 'static:./assets/product-images/197.webp'
  when '262' then 'static:./assets/product-images/262.webp'
  when '263' then 'static:./assets/product-images/263.webp'
  when '45' then 'static:./assets/product-images/cups.webp'
  when '53' then 'static:./assets/product-images/cups.webp'
  when '255' then 'static:./assets/product-images/cups.webp'
  when '88' then 'static:./assets/product-images/lids.webp'
  when '183' then 'static:./assets/product-images/lids.webp'
  else image_path
end,
image_updated_at = now()
where trim(sku) in ('43', '46', '49', '51', '197', '262', '263', '45', '53', '255', '88', '183')
  and image_path is null;

commit;

notify pgrst, 'reload schema';
