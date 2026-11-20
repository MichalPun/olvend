(function () {
  'use strict'

  var CACHE_NAME = 'olvend-operator-v55-confirm-bagette-load'
  var APP_SHELL = [
    './',
    './index.html',
    './uvod.html',
    './trasa.html',
    './sklad.html',
    './profil.html',
    './pokyny.html',
    './vozidlo.html',
    './potravinovy-automat-preview.html',
    './prihlaseni.html',
    './manifest.webmanifest?v=20261118-warehouse-v2',
    './operator-login.js',
    './operator-nav.css',
    './operator-profile-v3.css',
    './approved-home-v35.js?v=20261119-unrestricted-shift-start-v2',
    './operator-dashboard-v1.css?v=20261117-1',
    './operator-dashboard-v1.js?v=20261117-weather-v2',
    './operator-route.js',
    './operator-warehouse.js',
    './operator-warehouse-v2.css',
    './operator-profile-v11.js',
    './operator-instructions.js',
    './operator-vehicle.js',
    './auth-guard.js',
    './pwa-v27.js',
    './pwa-v36.js',
    './icon-192.png',
    './icon-512.png',
    './icon-maskable-512.png',
    './assets/instructions/pokyn-dne-test-2026-11-17.pdf',
    './assets/instructions/pokyn-dne-test-2026-11-17-page-1.png',
    './assets/instructions/pokyn-dne-test-2026-11-17-page-1-hires.png',
    './assets/product-images/201.jpg',
    './assets/product-images/bagette-debrecin.jpg',
    './assets/product-images/bagette-hamka.jpg',
    './assets/product-images/bagette-mlska.jpg',
    './assets/product-images/bagette-nuget.jpg',
    './assets/product-images/bagette-porizek.jpg',
    './assets/product-images/bagette-strips.jpg',
    './assets/product-images/bagette-svacinka.jpg',
    './assets/product-images/ean-3838945043694.png',
    './assets/product-images/ean-5949040204427.jpg',
    './assets/product-images/ean-7622201390648.jpg',
    './assets/product-images/ean-8000500073698.jpg',
    './assets/product-images/ean-8586018180863.jpg',
    './assets/product-images/ean-8594002072858.webp',
    './assets/product-images/ean-9002490200091.webp',
    '../assets/vehicles/fiat-doblo-modern.png?v=20261111-fleet-art-v2',
    '../assets/vehicles/fiat-doblo-2012.png?v=20261111-fleet-art-v2',
    '../assets/vehicles/opel-combo-2024-passenger.png?v=20261111-fleet-art-v2',
    '../assets/vehicles/opel-movano-older.png?v=20261111-fleet-art-v2',
    '../assets/vehicles/renault-kangoo-2019.png?v=20261111-fleet-art-v2'
  ]

  self.addEventListener('install', function (event) {
    event.waitUntil(caches.open(CACHE_NAME).then(function (cache) { return cache.addAll(APP_SHELL) }))
    self.skipWaiting()
  })

  self.addEventListener('activate', function (event) {
    event.waitUntil(caches.keys().then(function (keys) {
      return Promise.all(keys.filter(function (key) {
        return key.indexOf('olvend-operator-') === 0 && key !== CACHE_NAME
      }).map(function (key) { return caches.delete(key) }))
    }).then(function () { return self.clients.claim() }))
  })

  self.addEventListener('fetch', function (event) {
    if (event.request.method !== 'GET') return
    var requestUrl = new URL(event.request.url)
    if (requestUrl.origin !== self.location.origin) return
    var mustRefresh = event.request.mode === 'navigate' || /\.(?:html|js|css|webmanifest)$/.test(requestUrl.pathname)
    if (mustRefresh) {
      event.respondWith(fetch(event.request).then(function (response) {
        if (response && response.ok) caches.open(CACHE_NAME).then(function (cache) { cache.put(event.request, response.clone()) })
        return response
      }).catch(function () {
        return caches.match(event.request).then(function (cached) { return cached || caches.match('./index.html') })
      }))
      return
    }
    event.respondWith(caches.match(event.request).then(function (cached) {
      return cached || fetch(event.request).then(function (response) {
        if (response && response.ok) caches.open(CACHE_NAME).then(function (cache) { cache.put(event.request, response.clone()) })
        return response
      })
    }))
  })
})()
