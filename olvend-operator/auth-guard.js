(function () {
  'use strict'

  var supabaseUrl = 'https://rerjlkrhiytgscjerqgs.supabase.co'
  var supabaseKey = 'sb_publishable_A8OxCcapdNXAzQLjLsW5iA_XtGvBZ0S'
  var authStorageKey = 'sb-rerjlkrhiytgscjerqgs-auth-token'
  var gate = document.getElementById('operatorAuthGate')
  var gateMessage = document.getElementById('operatorAuthMessage')
  var gateActions = document.getElementById('operatorAuthActions')
  var userButtons = document.querySelectorAll('.og-user,.ot-user,.os-user,.op-user')
  var logoutButtons = document.querySelectorAll('[data-operator-logout]')
  var gateWatchdog = window.setTimeout(function () {
    showGateError('Ověření se nepodařilo dokončit. Zkontroluj připojení a zkus to znovu.')
  }, 15000)

  function clearLogin() {
    localStorage.removeItem(authStorageKey)
    localStorage.removeItem('olvendUser')
    sessionStorage.removeItem('olvendUser')
  }

  function readStoredSession() {
    try {
      var stored = JSON.parse(localStorage.getItem(authStorageKey) || 'null')
      return stored && (stored.currentSession || stored.session || stored)
    } catch (_) {
      return null
    }
  }

  function sessionIsUsable(session) {
    var expiresAt = Number(session && session.expires_at || 0) * 1000
    return Boolean(session && session.access_token && session.user && session.user.id && expiresAt > Date.now() + 30000)
  }

  function storeSession(session) {
    var expiresAt = Number(session.expires_at || 0)
    if (!expiresAt) expiresAt = Math.floor(Date.now() / 1000) + Number(session.expires_in || 3600)
    localStorage.setItem(authStorageKey, JSON.stringify(Object.assign({}, session, { expires_at: expiresAt })))
  }

  function apiHeaders(accessToken) {
    return {
      'apikey': supabaseKey,
      'Authorization': 'Bearer ' + (accessToken || supabaseKey),
      'Content-Type': 'application/json'
    }
  }

  function fetchWithTimeout(url, options, timeoutMs) {
    var controller = typeof AbortController === 'function' ? new AbortController() : null
    var requestOptions = Object.assign({}, options || {})
    if (controller) requestOptions.signal = controller.signal
    var timer
    var timeout = new Promise(function (_, reject) {
      timer = window.setTimeout(function () {
        if (controller) controller.abort()
        reject(new Error('Ověření přihlášení trvalo příliš dlouho.'))
      }, timeoutMs)
    })
    return Promise.race([fetch(url, requestOptions), timeout]).then(function (response) {
      window.clearTimeout(timer)
      return response
    }, function (error) {
      window.clearTimeout(timer)
      throw error
    })
  }

  function revealApp() {
    window.clearTimeout(gateWatchdog)
    if (/\/olvend-operator\/$/.test(window.location.pathname) || /\/index\.html$/.test(window.location.pathname)) {
      window.location.replace('./uvod.html')
      return
    }
    document.body.classList.remove('auth-pending')
    if (gate) gate.hidden = true
    var employee = null
    try {
      employee = JSON.parse(sessionStorage.getItem('olvendUser') || localStorage.getItem('olvendUser') || 'null')
      if (employee && userButtons.length) {
        var first = String(employee.name || '').charAt(0)
        var last = String(employee.surname || '').charAt(0)
        Array.prototype.forEach.call(userButtons, function (button) {
          button.textContent = (first + last).toUpperCase() || 'OP'
          button.setAttribute('aria-label', 'Otevřít profil ' + [employee.name, employee.surname].join(' ').trim())
        })
      }
    } catch (_) {}
    if (typeof window.operatorApprovedHomeStart === 'function') window.operatorApprovedHomeStart(session, employee)
    if (typeof window.operatorRouteStart === 'function') window.operatorRouteStart(session, employee)
    if (typeof window.operatorProfileStart === 'function') window.operatorProfileStart(session, employee)
  }

  function showGateError(message) {
    window.clearTimeout(gateWatchdog)
    if (gateMessage) gateMessage.textContent = message
    if (gateActions) gateActions.hidden = false
    if (gate) gate.setAttribute('aria-busy', 'false')
  }

  function goToLogin() {
    window.clearTimeout(gateWatchdog)
    window.location.replace('./prihlaseni.html')
  }

  function refreshSession(session) {
    if (!session || !session.refresh_token || navigator.onLine === false) return Promise.reject(new Error('Přihlášení vypršelo.'))
    return fetchWithTimeout(
      supabaseUrl + '/auth/v1/token?grant_type=refresh_token',
      {
        method: 'POST',
        headers: apiHeaders(),
        body: JSON.stringify({ refresh_token: session.refresh_token })
      },
      12000
    ).then(function (response) {
      if (!response.ok) throw new Error('Přihlášení vypršelo.')
      return response.json()
    }).then(function (refreshed) {
      if (!refreshed || !refreshed.access_token || !refreshed.user || !refreshed.user.id) throw new Error('Přihlášení vypršelo.')
      storeSession(refreshed)
      return refreshed
    })
  }

  function logout(session) {
    if (!window.confirm('Odhlásit se z OLVEND Operátor?')) return
    var request = fetch(supabaseUrl + '/auth/v1/logout', {
      method: 'POST',
      headers: apiHeaders(session.access_token)
    }).catch(function () {})
    Promise.resolve(request).then(function () {
      clearLogin()
      goToLogin()
    })
  }

  var session = readStoredSession()
  if (!session) {
    clearLogin()
    goToLogin()
    return
  }

  var retryButton = document.getElementById('operatorAuthRetry')
  var loginButton = document.getElementById('operatorAuthLogin')
  if (retryButton) retryButton.addEventListener('click', function () { window.location.reload() })
  if (loginButton) loginButton.addEventListener('click', function () { clearLogin(); goToLogin() })

  var readySession = sessionIsUsable(session) ? Promise.resolve(session) : refreshSession(session)
  readySession.then(function (activeSession) {
    session = activeSession
    Array.prototype.forEach.call(userButtons, function (button) {
      button.addEventListener('click', function () {
        if (!/\/profil\.html$/.test(window.location.pathname)) window.location.href = './profil.html'
      })
    })
    Array.prototype.forEach.call(logoutButtons, function (button) {
      button.addEventListener('click', function () { logout(session) })
    })
    if (navigator.onLine === false) {
      revealApp()
      return null
    }
    return fetchWithTimeout(
      supabaseUrl + '/rest/v1/rpc/security_active_employee',
      { method: 'POST', headers: apiHeaders(session.access_token), body: '{}' },
      10000
    ).then(function (response) {
      if (!response.ok) throw new Error('Přístup nebyl potvrzen.')
      return response.json()
    }).then(function (active) {
      if (active !== true) throw new Error('Účet není vedený jako aktivní zaměstnanec.')
      revealApp()
    })
  }).catch(function (error) {
    if (error && /aktivní zaměstnanec|Přístup nebyl|vypršelo/.test(error.message || '')) clearLogin()
    showGateError(error && error.message ? error.message : 'Přihlášení se nepodařilo ověřit.')
  })
})()
