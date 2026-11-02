begin;

-- Verified public packshots shared by the PC product master and Zebra pick list.
update public.products
set image_path = case trim(ean)
  when '7622210416407' then 'static:./assets/product-images/ean-7622210416407.jpg'
  when '7622201390648' then 'static:./assets/product-images/ean-7622201390648.jpg'
  when '8588005524056' then 'static:./assets/product-images/ean-8588005524056.webp'
  when '18584004024105' then 'static:./assets/product-images/ean-18584004024105.jpg'
  when '8593803224398' then 'static:./assets/product-images/ean-8593803224398.jpg'
  when '8594033172497' then 'static:./assets/product-images/ean-8594033172497.jpg'
  when '8594027770487' then 'static:./assets/product-images/ean-8594027770487.jpg'
  when '8594027770494' then 'static:./assets/product-images/ean-8594027770494.jpg'
  when '8594027770947' then 'static:./assets/product-images/ean-8594027770947.jpg'
  when '8594027779985' then 'static:./assets/product-images/ean-8594027779985.jpg'
  when '4000177407523' then 'static:./assets/product-images/ean-4000177407523.webp'
  when '8594027772184' then 'static:./assets/product-images/ean-8594027772184.jpg'
  when '4011800548506' then 'static:./assets/product-images/ean-4011800548506.jpg'
  when '5900259138293' then 'static:./assets/product-images/ean-5900259138293.jpg'
  when '8586018180863' then 'static:./assets/product-images/ean-8586018180863.jpg'
  when '8595646210392' then 'static:./assets/product-images/ean-8595646210392.jpg'
  when '8595646210415' then 'static:./assets/product-images/ean-8595646210415.jpg'
  when '8595646210439' then 'static:./assets/product-images/ean-8595646210439.jpg'
  when '5949040204427' then 'static:./assets/product-images/ean-5949040204427.jpg'
  when '8586012827450' then 'static:./assets/product-images/ean-8586012827450.jpg'
  when '8594004583130' then 'static:./assets/product-images/ean-8594004583130.png'
  when '9002975301558' then 'static:./assets/product-images/ean-9002975301558.webp'
  when '8594012320123' then 'static:./assets/product-images/ean-8594012320123.png'
  when '5999884034414' then 'static:./assets/product-images/ean-5999884034414.jpg'
  when '8594057829773' then 'static:./assets/product-images/ean-8594057829773.jpg'
  when '8000500073698' then 'static:./assets/product-images/ean-8000500073698.jpg'
  when '8000500033784' then 'static:./assets/product-images/ean-8000500033784.jpg'
  when '7613035357754' then 'static:./assets/product-images/ean-7613035357754.jpg'
  when '40144382' then 'static:./assets/product-images/ean-40144382.webp'
  when '8595231200111' then 'static:./assets/product-images/ean-8595231200111.jpg'
  when '8595646209693' then 'static:./assets/product-images/ean-8595646209693.jpg'
  when '8593893788398' then 'static:./assets/product-images/ean-8593893788398.jpg'
  when '58584004030005' then 'static:./assets/product-images/ean-58584004030005.jpg'
  when '8593894809764' then 'static:./assets/product-images/ean-8593894809764.jpg'
  when '8595646203516' then 'static:./assets/product-images/ean-8595646203516.jpg'
  when '8595646203554' then 'static:./assets/product-images/ean-8595646203554.jpg'
  when '8595573401344' then 'static:./assets/product-images/ean-8595573401344.jpg'
  when '08000500262849' then 'static:./assets/product-images/ean-08000500262849.webp'
  when '8594064474584' then 'static:./assets/product-images/ean-8594064474584.jpg'
  when '8594027770104' then 'static:./assets/product-images/ean-8594027770104.jpg'
  when '5900497312240' then 'static:./assets/product-images/ean-5900497312240.jpg'
  when '8594004632487' then 'static:./assets/product-images/ean-8594004632487.jpg'
  when '5900535013733' then 'static:./assets/product-images/ean-5900535013733.jpg'
  when '8594000097587' then 'static:./assets/product-images/ean-8594000097587.jpg'
  when '9002490200091' then 'static:./assets/product-images/ean-9002490200091.webp'
  when '8595646203813' then 'static:./assets/product-images/ean-8595646203813.jpg'
  when '8584004150166' then 'static:./assets/product-images/ean-8584004150166.png'
  when '68584004040100' then 'static:./assets/product-images/ean-68584004040100.jpg'
  when '4009900456630' then 'static:./assets/product-images/ean-4009900456630.jpg'
  when '5900951311512' then 'static:./assets/product-images/ean-5900951311512.jpg'
  when '8593868004447' then 'static:./assets/product-images/ean-8593868004447.webp'
  when '8594014630022' then 'static:./assets/product-images/ean-8594014630022.jpg'
  when '8445290662545' then 'static:./assets/product-images/ean-8445290662545.webp'
  when '8693029603189' then 'static:./assets/product-images/ean-8693029603189.jpg'
  when '5900951313608' then 'static:./assets/product-images/ean-5900951313608.jpg'
  when '8594002072858' then 'static:./assets/product-images/ean-8594002072858.webp'
  when '5205422270375' then 'static:./assets/product-images/ean-5205422270375.jpg'
  when '8594006245067' then 'static:./assets/product-images/ean-8594006245067.jpg'
  else image_path
end,
image_updated_at = now()
where trim(ean) in ('7622210416407', '7622201390648', '8588005524056', '18584004024105', '8593803224398', '8594033172497', '8594027770487', '8594027770494', '8594027770947', '8594027779985', '4000177407523', '8594027772184', '4011800548506', '5900259138293', '8586018180863', '8595646210392', '8595646210415', '8595646210439', '5949040204427', '8586012827450', '8594004583130', '9002975301558', '8594012320123', '5999884034414', '8594057829773', '8000500073698', '8000500033784', '7613035357754', '40144382', '8595231200111', '8595646209693', '8593893788398', '58584004030005', '8593894809764', '8595646203516', '8595646203554', '8595573401344', '08000500262849', '8594064474584', '8594027770104', '5900497312240', '8594004632487', '5900535013733', '8594000097587', '9002490200091', '8595646203813', '8584004150166', '68584004040100', '4009900456630', '5900951311512', '8593868004447', '8594014630022', '8445290662545', '8693029603189', '5900951313608', '8594002072858', '5205422270375', '8594006245067')
  and image_path is null;

commit;

notify pgrst, 'reload schema';

