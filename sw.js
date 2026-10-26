const CACHE_NAME = 'olvend-v232-coffee-initial-count';
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
  './mobile-personal-zone.js',
  './vendor/leaflet/leaflet.css',
  './vendor/leaflet/leaflet.js',
  './route-skip-approval.html',
  './route-add-approval.html',
  './routes-create.html',
  './supabase.js',
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
  './assets/product-images/44.jpg',
  './assets/product-images/47.jpg',
  './assets/product-images/48.jpg',
  './assets/product-images/201.jpg',
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
              if (response?.ok) caches.open(CACHE_NAME).then((cache) => cache.put(stableImageRequest, response.clone()));
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

  const isFreshAsset =
    event.request.mode === 'navigate'
    || ['script', 'style', 'worker'].includes(event.request.destination)
    || requestUrl.pathname.endsWith('.html')
    || requestUrl.pathname.endsWith('.js')
    || requestUrl.pathname.endsWith('.css');

  if (isFreshAsset) {
    const networkResponse = fetch(event.request)
      .then(async (response) => {
        if (response?.ok) {
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
        const responseClone = response.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(event.request, responseClone));
        return response;
      });
    })
  );
});
