(function () {
  'use strict'

  if (!('serviceWorker' in navigator)) return
  window.addEventListener('load', function () {
    var version = '20261102-zebra-spacing-v8'
    var storageKey = 'olvendPwaBootstrapVersion'
    try {
      if (localStorage.getItem(storageKey) !== version) localStorage.setItem(storageKey, version)
    } catch (_) {}

    navigator.serviceWorker.register('./sw.js?v=20261102-zebra-spacing-v8').catch(function (error) {
      if (window.console && console.error) console.error('PWA registrace service workeru selhala:', error)
    })
  })
})()
