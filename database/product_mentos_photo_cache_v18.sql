-- Exact product photo for Mentos CleanBreath Wintergreen 21 g.
-- The version suffix invalidates previously cached 404 responses on operator PDAs.
update public.products
set image_path = 'static:./assets/product-images/265.jpg?v=20261120-mentos-v1'
where id = 265
  and name = 'Mentos CleanBreath Wintergreen 21g';
