(function () {
  'use strict'

  var installPrompt = null
  var installButton = document.querySelector('[data-install-app]')

  if ('serviceWorker' in navigator) {
    window.addEventListener('load', function () {
      navigator.serviceWorker.register('./sw.js', { scope: './' }).catch(function () {})
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
