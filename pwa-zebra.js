(function () {
  'use strict'

  if (!('serviceWorker' in navigator)) return
  window.addEventListener('load', function () {
    var version = '20261102-zebra-shelf-label-v14'
    var storageKey = 'olvendPwaBootstrapVersion'
    var reloadKey = 'olvendPwaControllerReloadVersion'
    try {
      if (localStorage.getItem(storageKey) !== version) localStorage.setItem(storageKey, version)
    } catch (_) {}

    navigator.serviceWorker.addEventListener('controllerchange', function () {
      try {
        if (sessionStorage.getItem(reloadKey) === version) return
        sessionStorage.setItem(reloadKey, version)
      } catch (_) {}
      window.location.reload()
    })

    navigator.serviceWorker.register('./sw.js?v=20261102-zebra-shelf-label-v14')
      .then(function (registration) { return registration.update() })
      .catch(function (error) {
        if (window.console && console.error) console.error('PWA registrace service workeru selhala:', error)
      })
  })
})()
