(function () {
  'use strict'

  var installPrompt = null
  var installButton = document.querySelector('[data-install-app]')
  var refreshingForUpdate = false

  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.addEventListener('controllerchange', function () {
      if (refreshingForUpdate) return
      refreshingForUpdate = true
      window.location.reload()
    })
    window.addEventListener('load', function () {
      navigator.serviceWorker.register('./sw.js', { scope: './' }).then(function (registration) {
        registration.update().catch(function () {})
      }).catch(function () {})
    })
  }

  window.addEventListener('beforeinstallprompt', function (event) {
    event.preventDefault()
    installPrompt = event
    if (installButton) installButton.hidden = false
  })

  if (installButton) {
    installButton.addEventListener('click', function () {
      if (!installPrompt) return
      installButton.disabled = true
      installPrompt.prompt()
      installPrompt.userChoice.then(function () {
        installPrompt = null
        installButton.hidden = true
        installButton.disabled = false
      }, function () {
        installButton.disabled = false
      })
    })
  }

  window.addEventListener('appinstalled', function () {
    installPrompt = null
    if (installButton) installButton.hidden = true
  })
})()
