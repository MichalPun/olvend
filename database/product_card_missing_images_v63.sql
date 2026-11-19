begin;

with image_map(product_id, product_sku, image_path) as (
  values
    (11::bigint, '79'::text, 'static:./assets/product-images/ean-8594010435614.png'::text),
    (12::bigint, '16'::text, 'static:./assets/product-images/sku-16-labuznik.png'::text),
    (164::bigint, '282'::text, 'static:./assets/product-images/sku-282-kure-teriyaki.png'::text),
    (14::bigint, '17'::text, 'static:./assets/product-images/ean-8594010421358.png'::text),
    (17::bigint, '155'::text, 'static:./assets/product-images/ean-8594010433450.png'::text),
    (18::bigint, '154'::text, 'static:./assets/product-images/sku-154-trhane-veprove.png'::text),
    (20::bigint, '207'::text, 'static:./assets/product-images/sku-207-bad-brambacher-grep.jpg'::text),
    (40::bigint, '50'::text, 'static:./assets/product-images/sku-50-creamio-slany-karamel.jpg'::text),
    (64::bigint, '259'::text, 'static:./assets/product-images/sku-259-hello-malina.jpg'::text),
    (159::bigint, '279'::text, 'static:./assets/product-images/sku-279-jojo-arasidky.jpg'::text),
    (205::bigint, 'SOCO-PROTEIN-VANILKA-45'::text, 'static:./assets/product-images/ean-8594027773198.jpg'::text),
    (202::bigint, 'SOCO-RAWBAR-APPLE'::text, 'static:./assets/product-images/ean-8594027771514.jpg'::text),
    (201::bigint, 'SOCO-RAWBAR-CRANBERRY'::text, 'static:./assets/product-images/ean-8594027773150.jpg'::text),
    (200::bigint, 'SOCO-RAWBAR-PEANUTS'::text, 'static:./assets/product-images/ean-8594027771507.jpg'::text),
    (254::bigint, 'SIMPLY-HAMKA'::text, 'static:./assets/product-images/sku-simply-hamka.jpg'::text),
    (238::bigint, 'SIMPLY-MLSKA'::text, 'static:./assets/product-images/sku-simply-mlska.jpg'::text),
    (256::bigint, 'VA-PISTACIE-PRAZ-SOL-60'::text, 'static:./assets/product-images/ean-8594002072889.jpg'::text),
    (160::bigint, '280'::text, 'static:./assets/product-images/sku-280-veneto-vanilka.png'::text)
)
update public.products p
set image_path = m.image_path,
    image_updated_at = now(),
    updated_at = now()
from image_map m
where p.id = m.product_id
  and p.sku = m.product_sku
  and coalesce(btrim(p.image_path), '') = '';

commit;
