(function () {
  'use strict'

  var authKey = 'sb-rerjlkrhiytgscjerqgs-auth-token'
  var loginUrl = 'zebra-prihlaseni.html'
  var loadingStatus = document.getElementById('loadingStatus')

  window.__warehouseSetBootStage = function (message) {
    if (loadingStatus && !window.__warehousePickingReady) loadingStatus.textContent = message
  }

  function hasStoredSession() {
    try {
      var stored = JSON.parse(localStorage.getItem(authKey) || 'null')
      var session = stored && (stored.currentSession || stored.session || stored)
      var expiresAt = Number(session && session.expires_at || 0) * 1000
      return Boolean(session && session.access_token && session.user && session.user.id && expiresAt > Date.now() + 30000)
    } catch (_) {
      return false
    }
  }

  function showBootError(message) {
    if (window.__warehousePickingReady) return
    window.__warehousePickingReady = true
    var loading = document.getElementById('loadingView')
    var errorView = document.getElementById('errorView')
    var errorMessage = document.getElementById('errorMessage')
    if (loading) {
      loading.hidden = true
      loading.style.setProperty('display', 'none', 'important')
    }
    if (errorMessage) errorMessage.textContent = message
    if (errorView) {
      errorView.hidden = false
      errorView.style.setProperty('display', 'block', 'important')
    }
  }

  if (navigator.onLine !== false && !hasStoredSession()) {
    localStorage.removeItem(authKey)
    window.location.replace(loginUrl)
    return
  }

  var retryButton = document.getElementById('errorRetryBtn')
  var loginButton = document.getElementById('errorLoginBtn')
  if (retryButton) retryButton.addEventListener('click', function () { window.location.reload() })
  if (loginButton) {
    loginButton.addEventListener('click', function () {
      localStorage.removeItem(authKey)
      localStorage.removeItem('olvendUser')
      sessionStorage.removeItem('olvendUser')
      window.location.replace(loginUrl)
    })
  }

  window.addEventListener('error', function (event) {
    if (!window.__warehousePickingReady && event && event.message) {
      showBootError('Aplikaci se nepodařilo spustit: ' + event.message)
    }
  })
  window.addEventListener('unhandledrejection', function (event) {
    var reason = event && event.reason
    var message = reason && reason.message ? reason.message : String(reason || '')
    if (!window.__warehousePickingReady && message) showBootError('Aplikaci se nepodařilo spustit: ' + message)
  })
  window.setTimeout(function () {
    if (!window.__warehousePickingReady) window.__warehouseSetBootStage('Ověřuji uložené přihlášení…')
  }, 3000)
  window.setTimeout(function () {
    if (!window.__warehousePickingReady) window.__warehouseSetBootStage('Server odpovídá pomalu, ještě chvíli čekám…')
  }, 7000)
  window.setTimeout(function () {
    showBootError('Spojení se systémem neodpovídá. Zkontroluj Wi‑Fi a zkus načtení znovu. Pokud problém trvá, přihlas se znovu.')
  }, 12000)
})()
