const CACHE_NAME = 'olvend-v254-fleet-art';
const APP_SHELL = [
  './',
  './index.html',
  './mobile.html',
  './mobile-route-completion.js?v=20261026-initial-count-v2',
  './mobile-coffee-visit.js?v=20261021-coffee-visit-v1',
  './mobile-coffee-domain.js?v=20261026-initial-count-v3',
  './mobile-food-visit.js?v=20261021-food-visit-v1',
  './mobile-food-domain.js?v=20261021-food-domain-v1',
  './mobile-route-domain.js?v=20261021-route-domain-v1',
  './mobile-control.html',
  './control-route-protocol.html',
  './controlling.html',
  './technician-mobile.html',
  './machine-calibration.html',
  './machine-calibration-core.mjs',
  './machine-pricing.html',
  './machine-pricing.js',
  './warehouse-picking.html',
  './warehouse-picking.js',
  './warehouse-picking-core.mjs',
  './warehouse-picking.webmanifest',
  './zebra-login.html',
  './zebra-prihlaseni.html',
  './zebra-login-plain.js',
  './zebra-sklad.html',
  './zebra-aplikace.html',
  './zebra-polyfills.js',
  './zebra-startup.js',
  './pwa-zebra.js',
  './warehouse-zebra-bundle.js',
  './zebra-sklad.webmanifest',
  './icons/warehouse-icon.svg',
  './icons/warehouse-192.png',
  './icons/warehouse-512.png',
  './icons/warehouse-maskable-512.png',
  './mobile-personal-zone.js',
  './vendor/leaflet/leaflet.css',
  './vendor/leaflet/leaflet.js',
  './route-skip-approval.html',
  './route-add-approval.html',
  './routes-create.html',
  './supabase.js',
  './supabase-zebra.js',
  './vendor/supabase/supabase-js-2.118.0.bundle.mjs',
  './vendor/supabase/supabase-js-2.118.0-es2017.bundle.mjs',
  './offline-queue.js',
  './secure-files.js',
  './machines-planogram.css?v=20260913d',
  './machines-planogram-ui.js?v=20260913b',
  './machine-visits.js?v=20260913',
  './dashboard.html',
  './attendance.html',
  './hr.html',
  './settings.html',
  './employees.html',
  './vehicles.html',
  './vehicle-shift-switch.js',
  './warehouses.html',
  './company.html',
  './budget.html',
  './cash-collection.html',
  './reporty.html',
  './payroll.html',
  './payroll-payslips.js',
  './payroll-payslips.css',
  './mail.html',
  './mail-settings.html',
  './mail-api.js',
  './report-telemetry.html',
  './report-monthly-review.html',
  './report-invoice-comparison.html',
  './report-attendance.html',
  './operational-requests.html',
  './technical-overview.html',
  './technical-jobs.html',
  './service-requests.html',
  './sidebar.js',
  './pwa.js',
  './manifest.webmanifest',
  './assets/rheavendors-luce-x2.jpg',
  './assets/rheavendors-luce-x2-interior.jpg',
  './assets/cash-security-bag.png',
  './assets/vehicles/fiat-doblo-2012.png?v=20261111-fleet-art-v2',
  './assets/vehicles/fiat-doblo-modern.png?v=20261111-fleet-art-v2',
  './assets/vehicles/opel-combo-2024-passenger.png?v=20261111-fleet-art-v2',
  './assets/vehicles/opel-movano-older.png?v=20261111-fleet-art-v2',
  './assets/vehicles/renault-kangoo-2019.png?v=20261111-fleet-art-v2',
  './assets/product-images/44.jpg',
  './assets/product-images/47.jpg',
  './assets/product-images/48.jpg',
  './assets/product-images/201.jpg',
  './assets/product-images/43.webp',
  './assets/product-images/46.webp',
  './assets/product-images/49.webp',
  './assets/product-images/51.webp',
  './assets/product-images/197.webp',
  './assets/product-images/262.webp',
  './assets/product-images/263.webp',
  './assets/product-images/cups.webp',
  './assets/product-images/lids.webp',
  './assets/product-images/ean-7622210416407.jpg',
  './assets/product-images/ean-7622201390648.jpg',
  './assets/product-images/ean-8588005524056.webp',
  './assets/product-images/ean-18584004024105.jpg',
  './assets/product-images/ean-8593803224398.jpg',
  './assets/product-images/ean-8594033172497.jpg',
  './assets/product-images/ean-8594027770487.jpg',
  './assets/product-images/ean-8594027770494.jpg',
  './assets/product-images/ean-8594027770947.jpg',
  './assets/product-images/ean-8594027779985.jpg',
  './assets/product-images/ean-4000177407523.webp',
  './assets/product-images/ean-8594027772184.jpg',
  './assets/product-images/ean-4011800548506.jpg',
  './assets/product-images/ean-5900259138293.jpg',
  './assets/product-images/ean-8586018180863.jpg',
  './assets/product-images/ean-8595646210392.jpg',
  './assets/product-images/ean-8595646210415.jpg',
  './assets/product-images/ean-8595646210439.jpg',
  './assets/product-images/ean-5949040204427.jpg',
  './assets/product-images/ean-8586012827450.jpg',
  './assets/product-images/ean-8594004583130.png',
  './assets/product-images/ean-9002975301558.webp',
  './assets/product-images/ean-8594012320123.png',
  './assets/product-images/ean-5999884034414.jpg',
  './assets/product-images/ean-8594057829773.jpg',
  './assets/product-images/ean-8000500073698.jpg',
  './assets/product-images/ean-8000500033784.jpg',
  './assets/product-images/ean-7613035357754.jpg',
  './assets/product-images/ean-40144382.webp',
  './assets/product-images/ean-8595231200111.jpg',
  './assets/product-images/ean-8595646209693.jpg',
  './assets/product-images/ean-8593893788398.jpg',
  './assets/product-images/ean-58584004030005.jpg',
  './assets/product-images/ean-8593894809764.jpg',
  './assets/product-images/ean-8595646203516.jpg',
  './assets/product-images/ean-8595646203554.jpg',
  './assets/product-images/ean-8595573401344.jpg',
  './assets/product-images/ean-08000500262849.webp',
  './assets/product-images/ean-8594064474584.jpg',
  './assets/product-images/ean-8594027770104.jpg',
  './assets/product-images/ean-5900497312240.jpg',
  './assets/product-images/ean-8594004632487.jpg',
  './assets/product-images/ean-5900535013733.jpg',
  './assets/product-images/ean-8594000097587.jpg',
  './assets/product-images/ean-9002490200091.webp',
  './assets/product-images/ean-8595646203813.jpg',
  './assets/product-images/ean-8584004150166.png',
  './assets/product-images/ean-68584004040100.jpg',
  './assets/product-images/ean-4009900456630.jpg',
  './assets/product-images/ean-5900951311512.jpg',
  './assets/product-images/ean-8593868004447.webp',
  './assets/product-images/ean-8594014630022.jpg',
  './assets/product-images/ean-8445290662545.webp',
  './assets/product-images/ean-8693029603189.jpg',
  './assets/product-images/ean-5900951313608.jpg',
  './assets/product-images/ean-8594002072858.webp',
  './assets/product-images/ean-5205422270375.jpg',
  './assets/product-images/ean-8594006245067.jpg',
  './assets/product-images/ean-3838945041713.jpg',
  './assets/product-images/ean-3838945035293.png',
  './assets/product-images/ean-3838945037808.png',
  './assets/product-images/ean-3838945501392.png',
  './assets/product-images/ean-3838945043694.png',
  './assets/product-images/ean-3838945043663.png',
  './assets/product-images/ean-3838945501248.png',
  './assets/product-images/ean-3838945508094.webp',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './icons/icon-maskable-512.png',
  './icons/icon.svg',
  './icons/apple-touch-icon.png'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(APP_SHELL))
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key !== CACHE_NAME)
          .map((key) => caches.delete(key))
      )
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;

  const requestUrl = new URL(event.request.url);
  if (requestUrl.origin !== self.location.origin) {
    if (requestUrl.hostname.endsWith('.supabase.co')) {
      if (requestUrl.pathname.includes('/storage/v1/object/sign/product-images/')) {
        const stableImageRequest = new Request(`${requestUrl.origin}${requestUrl.pathname}`, { method: 'GET' });
        event.respondWith(
          caches.match(stableImageRequest).then((cachedResponse) => {
            if (cachedResponse) return cachedResponse;
            return fetch(event.request).then((response) => {
              if (response && response.ok) caches.open(CACHE_NAME).then((cache) => cache.put(stableImageRequest, response.clone()));
              return response;
            });
          })
        );
        return;
      }
      event.respondWith(fetch(event.request, { cache: 'no-store' }));
      return;
    }
    event.respondWith(
      caches.match(event.request).then((cachedResponse) => {
        if (cachedResponse) return cachedResponse;
        return fetch(event.request).then((response) => {
          const responseClone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, responseClone));
          return response;
        });
      })
    );
    return;
  }

  if (requestUrl.pathname.includes('/assets/product-images/')) {
    event.respondWith(
      fetch(event.request).then((response) => {
        if (response && response.ok) {
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, response.clone()));
        }
        return response;
      }).catch(() =>
        caches.match(event.request).then((cachedResponse) =>
          cachedResponse || caches.match(event.request, { ignoreSearch: true })
        )
      )
    );
    return;
  }

  if (requestUrl.pathname.includes('/assets/vehicles/')) {
    event.respondWith(
      fetch(event.request, { cache: 'no-cache' }).then((response) => {
        if (response && response.ok) {
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, response.clone()));
        }
        return response;
      }).catch(() => caches.match(event.request))
    );
    return;
  }

  const isFreshAsset =
    event.request.mode === 'navigate'
    || ['script', 'style', 'worker'].includes(event.request.destination)
    || requestUrl.pathname.endsWith('.html')
    || requestUrl.pathname.endsWith('.js')
    || requestUrl.pathname.endsWith('.css');

  if (isFreshAsset) {
    const networkResponse = fetch(event.request)
      .then(async (response) => {
        if (response && response.ok) {
          const cache = await caches.open(CACHE_NAME);
          await cache.put(event.request, response.clone());
        }
        return response;
      });
    event.waitUntil(networkResponse.catch(() => undefined));
    event.respondWith(networkResponse.catch(async () => {
      const cachedResponse = await caches.match(event.request);
      return cachedResponse || caches.match('./index.html');
    }));
    return;
  }

  event.respondWith(
    caches.match(event.request).then((cachedResponse) => {
      if (cachedResponse) return cachedResponse;

      return fetch(event.request).then((response) => {
        if (response && response.ok) {
          const responseClone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, responseClone));
        }
        return response;
      });
    })
  );
});
