const CACHE_NAME = 'olvend-v40-telemetry-readable-layout-assets';
const APP_SHELL = [
  './',
  './index.html',
  './dashboard.html',
  './attendance.html',
  './hr.html',
  './settings.html',
  './employees.html',
  './vehicles.html',
  './warehouses.html',
  './company.html',
  './budget.html',
  './reporty.html',
  './report-telemetry.html',
  './report-monthly-review.html',
  './report-invoice-comparison.html',
  './report-attendance.html',
  './sidebar.js',
  './pwa.js',
  './manifest.webmanifest',
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
  if (requestUrl.origin !== self.location.origin) return;

  const isFreshAsset =
    event.request.mode === 'navigate'
    || ['script', 'style', 'worker'].includes(event.request.destination)
    || requestUrl.pathname.endsWith('.html')
    || requestUrl.pathname.endsWith('.js')
    || requestUrl.pathname.endsWith('.css');

  if (isFreshAsset) {
    event.respondWith(
      fetch(event.request)
        .then((response) => {
          const responseClone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, responseClone));
          return response;
        })
        .catch(() => caches.match(event.request).then((cached) => cached || caches.match('./index.html')))
    );
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
