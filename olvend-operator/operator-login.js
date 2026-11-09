(function () {
  'use strict'

  var supabaseUrl = 'https://rerjlkrhiytgscjerqgs.supabase.co'
  var supabaseKey = 'sb_publishable_A8OxCcapdNXAzQLjLsW5iA_XtGvBZ0S'
  var authStorageKey = 'sb-rerjlkrhiytgscjerqgs-auth-token'
  var statusLine = document.getElementById('statusLine')
  var loginForm = document.getElementById('loginForm')
  var loginButton = document.getElementById('loginButton')
  var emailInput = document.getElementById('email')
  var passwordInput = document.getElementById('password')

  function setStatus(message, type) {
    statusLine.textContent = message
    statusLine.className = 'login-status' + (type ? ' ' + type : '')
  }

  function clearLogin() {
    localStorage.removeItem(authStorageKey)
    localStorage.removeItem('olvendUser')
    sessionStorage.removeItem('olvendUser')
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
        reject(new Error('Server neodpověděl včas. Zkontroluj Wi‑Fi a zkus to znovu.'))
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

  function readError(response) {
    return response.json().then(function (payload) {
      return payload.error_description || payload.msg || payload.message || payload.error || ('HTTP ' + response.status)
    }).catch(function () { return 'HTTP ' + response.status })
  }

  function signIn(email, password) {
    return fetchWithTimeout(
      supabaseUrl + '/auth/v1/token?grant_type=password',
      { method: 'POST', headers: apiHeaders(), body: JSON.stringify({ email: email, password: password }) },
      12000
    ).then(function (response) {
      if (!response.ok) return readError(response).then(function (message) { throw new Error(message) })
      return response.json()
    })
  }

  function verifyActiveEmployee(accessToken) {
    return fetchWithTimeout(
      supabaseUrl + '/rest/v1/rpc/security_active_employee',
      { method: 'POST', headers: apiHeaders(accessToken), body: '{}' },
      10000
    ).then(function (response) {
      if (!response.ok) return readError(response).then(function (message) { throw new Error(message) })
      return response.json()
    }).then(function (active) {
      if (active !== true) throw new Error('Účet není vedený jako aktivní zaměstnanec.')
    })
  }

  function loadEmployee(authUserId, accessToken) {
    var query = '?select=id,name,surname,role,email,auth_user_id,active'
      + '&auth_user_id=eq.' + encodeURIComponent(authUserId)
      + '&active=eq.true&limit=1'
    return fetchWithTimeout(
      supabaseUrl + '/rest/v1/employees' + query,
      { method: 'GET', headers: apiHeaders(accessToken) },
      10000
    ).then(function (response) {
      if (!response.ok) return readError(response).then(function (message) { throw new Error(message) })
      return response.json()
    }).then(function (employees) {
      return Array.isArray(employees) && employees.length ? employees[0] : null
    })
  }

  function storeLogin(session, employee) {
    var expiresAt = Math.floor(Date.now() / 1000) + Number(session.expires_in || 3600)
    var storedSession = Object.assign({}, session, { expires_at: expiresAt })
    localStorage.setItem(authStorageKey, JSON.stringify(storedSession))
    localStorage.setItem('olvendUser', JSON.stringify({
      id: employee.id,
      name: employee.name || '',
      surname: employee.surname || '',
      role: employee.role || '',
      email: employee.email || ''
    }))
  }

  loginForm.addEventListener('submit', function (event) {
    event.preventDefault()
    var attemptFinished = false
    var attemptWatchdog = window.setTimeout(function () {
      attemptFinished = true
      clearLogin()
      setStatus('Přihlášení se nepodařilo dokončit. Zkontroluj připojení a zkus to znovu.', 'error')
      loginButton.disabled = false
      loginButton.textContent = 'Zkusit znovu'
    }, 25000)
    loginButton.disabled = true
    loginButton.textContent = 'Přihlašuji…'
    setStatus('Ověřuji e-mail a heslo…')
    var email = String(emailInput.value || '').trim().toLowerCase()
    var password = String(passwordInput.value || '')
    if (!email || !password) {
      window.clearTimeout(attemptWatchdog)
      setStatus('Vyplň e-mail i heslo.', 'error')
      loginButton.disabled = false
      loginButton.textContent = 'Přihlásit se'
      return
    }

    signIn(email, password).then(function (session) {
      if (attemptFinished) return null
      if (!session || !session.access_token || !session.user || !session.user.id) throw new Error('Server nevrátil platné přihlášení.')
      setStatus('Kontroluji zaměstnanecký účet…')
      return Promise.all([
        verifyActiveEmployee(session.access_token),
        loadEmployee(session.user.id, session.access_token)
      ]).then(function (results) {
        if (attemptFinished) return null
        var employee = results[1]
        if (!employee) throw new Error('K účtu není přiřazený aktivní zaměstnanec.')
        storeLogin(session, employee)
        return true
      })
    }).then(function (completed) {
      if (!completed || attemptFinished) return
      attemptFinished = true
      window.clearTimeout(attemptWatchdog)
      setStatus('Přihlášení proběhlo. Otevírám aplikaci…', 'success')
      window.location.replace('./')
    }).catch(function (error) {
      if (attemptFinished) return
      attemptFinished = true
      window.clearTimeout(attemptWatchdog)
      clearLogin()
      var message = error && error.message ? error.message : 'Přihlášení se nezdařilo.'
      if (/invalid login credentials/i.test(message)) message = 'Nesprávný e-mail nebo heslo.'
      setStatus(message, 'error')
      loginButton.disabled = false
      loginButton.textContent = 'Přihlásit se'
    })
  })

  clearLogin()
  setStatus('Přihlas se účtem OLVEND.')
})()
