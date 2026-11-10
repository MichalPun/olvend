(function () {
  'use strict'

  var CACHE_NAME = 'olvend-operator-v7'
  var APP_SHELL = [
    './',
    './index.html',
    './uvod.html',
    './trasa.html',
    './profil.html',
    './prihlaseni.html',
    './manifest.webmanifest',
    './operator-login.js',
    './approved-home.js',
    './operator-route.js',
    './operator-profile.js',
    './auth-guard.js',
    './pwa.js',
    './icon-192.png',
    './icon-512.png',
    './icon-maskable-512.png'
  ]

  self.addEventListener('install', function (event) {
    event.waitUntil(caches.open(CACHE_NAME).then(function (cache) { return cache.addAll(APP_SHELL) }))
    self.skipWaiting()
  })

  self.addEventListener('activate', function (event) {
    event.waitUntil(
      caches.keys().then(function (keys) {
        return Promise.all(keys.filter(function (key) {
          return key.indexOf('olvend-operator-') === 0 && key !== CACHE_NAME
        }).map(function (key) { return caches.delete(key) }))
      }).then(function () { return self.clients.claim() })
    )
  })

  self.addEventListener('fetch', function (event) {
    if (event.request.method !== 'GET') return
    var requestUrl = new URL(event.request.url)
    if (requestUrl.origin !== self.location.origin) return

    if (event.request.mode === 'navigate') {
      event.respondWith(
        fetch(event.request).then(function (response) {
          if (response && response.ok) caches.open(CACHE_NAME).then(function (cache) { cache.put(event.request, response.clone()) })
          return response
        }).catch(function () {
          return caches.match(event.request).then(function (cached) { return cached || caches.match('./index.html') })
        })
      )
      return
    }

    event.respondWith(
      caches.match(event.request).then(function (cached) {
        return cached || fetch(event.request).then(function (response) {
          if (response && response.ok) caches.open(CACHE_NAME).then(function (cache) { cache.put(event.request, response.clone()) })
          return response
        })
      })
    )
  })
})()
