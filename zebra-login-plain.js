(function () {
  'use strict'

  var supabaseUrl = 'https://rerjlkrhiytgscjerqgs.supabase.co'
  var supabaseKey = 'sb_publishable_A8OxCcapdNXAzQLjLsW5iA_XtGvBZ0S'
  var authStorageKey = 'sb-rerjlkrhiytgscjerqgs-auth-token'
  var statusLine = document.getElementById('statusLine')
  var loginForm = document.getElementById('loginForm')
  var loginBtn = document.getElementById('loginBtn')
  var rememberMeInput = document.getElementById('rememberMe')
  var forgotPasswordBtn = document.getElementById('forgotPasswordBtn')

  function setStatus(message, type) {
    statusLine.textContent = message
    statusLine.className = 'status-line'
    if (type) statusLine.classList.add(type)
  }

  function clearStoredLogin() {
    localStorage.removeItem(authStorageKey)
    localStorage.removeItem('olvendUser')
    sessionStorage.removeItem('olvendUser')
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

  function apiHeaders(accessToken) {
    return {
      'apikey': supabaseKey,
      'Authorization': 'Bearer ' + (accessToken || supabaseKey),
      'Content-Type': 'application/json'
    }
  }

  async function readError(response) {
    try {
      var payload = await response.json()
      return payload.error_description || payload.msg || payload.message || payload.error || ('HTTP ' + response.status)
    } catch (_) {
      return 'HTTP ' + response.status
    }
  }

  async function signIn(email, password) {
    var response = await fetchWithTimeout(
      supabaseUrl + '/auth/v1/token?grant_type=password',
      {
        method: 'POST',
        headers: apiHeaders(),
        body: JSON.stringify({ email: email, password: password })
      },
      12000
    )
    if (!response.ok) throw new Error(await readError(response))
    return response.json()
  }

  async function verifyActiveEmployee(accessToken) {
    var response = await fetchWithTimeout(
      supabaseUrl + '/rest/v1/rpc/security_active_employee',
      { method: 'POST', headers: apiHeaders(accessToken), body: '{}' },
      10000
    )
    if (!response.ok) throw new Error(await readError(response))
    var active = await response.json()
    if (active !== true) throw new Error('Účet není vedený jako aktivní zaměstnanec.')
  }

  async function loadEmployee(authUserId, accessToken) {
    var query = '?select=id,name,surname,role,email,auth_user_id,active'
      + '&auth_user_id=eq.' + encodeURIComponent(authUserId)
      + '&active=eq.true&limit=1'
    var response = await fetchWithTimeout(
      supabaseUrl + '/rest/v1/employees' + query,
      { method: 'GET', headers: apiHeaders(accessToken) },
      10000
    )
    if (!response.ok) throw new Error(await readError(response))
    var employees = await response.json()
    return Array.isArray(employees) && employees.length ? employees[0] : null
  }

  function storeLogin(session, employee, rememberMe) {
    var expiresAt = Math.floor(Date.now() / 1000) + Number(session.expires_in || 3600)
    var storedSession = Object.assign({}, session, { expires_at: expiresAt })
    localStorage.setItem(authStorageKey, JSON.stringify(storedSession))

    var employeePayload = JSON.stringify({
      id: employee.id,
      name: employee.name || '',
      surname: employee.surname || '',
      role: employee.role || '',
      email: employee.email || ''
    })
    localStorage.removeItem('olvendUser')
    sessionStorage.removeItem('olvendUser')
    if (rememberMe) localStorage.setItem('olvendUser', employeePayload)
    else sessionStorage.setItem('olvendUser', employeePayload)
  }

  loginForm.addEventListener('submit', async function (event) {
    event.preventDefault()
    loginBtn.disabled = true
    loginBtn.textContent = 'Přihlašuji…'
    setStatus('Ověřuji e-mail a heslo…')

    try {
      var formData = new FormData(loginForm)
      var email = String(formData.get('email') || '').trim().toLowerCase()
      var password = String(formData.get('password') || '')
      if (!email || !password) throw new Error('Vyplň e-mail i heslo.')

      var session = await signIn(email, password)
      if (!session || !session.access_token || !session.user || !session.user.id) {
        throw new Error('Server nevrátil platné přihlášení.')
      }

      setStatus('Kontroluji zaměstnanecký účet…')
      await verifyActiveEmployee(session.access_token)
      var employee = await loadEmployee(session.user.id, session.access_token)
      if (!employee) throw new Error('K účtu není přiřazený aktivní zaměstnanec.')

      storeLogin(session, employee, rememberMeInput.checked)
      setStatus('Přihlášení proběhlo. Otevírám sklad…', 'success')
      window.location.replace('zebra-aplikace.html')
    } catch (error) {
      clearStoredLogin()
      var message = error && error.message ? error.message : 'Přihlášení se nezdařilo.'
      if (/invalid login credentials/i.test(message)) message = 'Nesprávný e-mail nebo heslo.'
      setStatus(message, 'error')
      loginBtn.disabled = false
      loginBtn.textContent = 'Přihlásit se'
    }
  })

  forgotPasswordBtn.addEventListener('click', function () {
    setStatus('Obnovu hesla proveď na počítači v běžném přihlášení OLVEND.', 'error')
  })

  clearStoredLogin()
  loginBtn.disabled = false
  loginBtn.textContent = 'Přihlásit se'
  forgotPasswordBtn.disabled = false
  setStatus('Zadej e-mail a heslo.')
})()
