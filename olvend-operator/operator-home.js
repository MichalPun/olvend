(function () {
  'use strict'

  var supabaseUrl = 'https://rerjlkrhiytgscjerqgs.supabase.co'
  var supabaseKey = 'sb_publishable_A8OxCcapdNXAzQLjLsW5iA_XtGvBZ0S'
  var home = document.getElementById('operatorHome')
  var content = document.getElementById('operatorHomeContent')
  var employeeName = document.getElementById('operatorHomeName')
  var dateLabel = document.getElementById('operatorHomeDate')
  var currentSession = null
  var currentEmployee = null

  function escapeHtml(value) {
    return String(value == null ? '' : value).replace(/[&<>"']/g, function (character) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' }[character]
    })
  }

  function todayIso() {
    try {
      return new Intl.DateTimeFormat('sv-SE', { timeZone: 'Europe/Prague' }).format(new Date())
    } catch (_) {
      var now = new Date()
      return [now.getFullYear(), String(now.getMonth() + 1).padStart(2, '0'), String(now.getDate()).padStart(2, '0')].join('-')
    }
  }

  function formatDate(value) {
    if (!value) return 'Dnes'
    var parts = String(value).split('-')
    return parts.length === 3 ? Number(parts[2]) + '. ' + Number(parts[1]) + '. ' + parts[0] : value
  }

  function headers() {
    return {
      'apikey': supabaseKey,
      'Authorization': 'Bearer ' + currentSession.access_token,
      'Content-Type': 'application/json'
    }
  }

  function fetchJson(url, timeoutMs) {
    var controller = typeof AbortController === 'function' ? new AbortController() : null
    var timer
    var timeout = new Promise(function (_, reject) {
      timer = window.setTimeout(function () {
        if (controller) controller.abort()
        var error = new Error('Načítání trasy trvalo příliš dlouho.')
        error.name = 'AbortError'
        reject(error)
      }, timeoutMs)
    })
    return Promise.race([fetch(url, { method: 'GET', headers: headers(), signal: controller ? controller.signal : undefined }), timeout]).then(function (response) {
      window.clearTimeout(timer)
      if (!response.ok) throw new Error('Trasu se nepodařilo načíst (HTTP ' + response.status + ').')
      return response.json()
    }, function (error) {
      window.clearTimeout(timer)
      throw error
    })
  }

  function routeUrl(select) {
    return supabaseUrl + '/rest/v1/route_plans?select=' + encodeURIComponent(select)
      + '&planned_employee_id=eq.' + encodeURIComponent(currentEmployee.id)
      + '&planning_date=eq.' + encodeURIComponent(todayIso())
      + '&execution_status=neq.cancelled&order=created_at.desc&limit=1'
  }

  function loadRoute() {
    var nestedSelect = 'id,planning_date,planned_departure_time,title,vehicle_id,execution_status,estimated_distance_km,estimated_drive_minutes,route_plan_stops(id,machine_id,stop_order,status,title,address_snapshot,city_snapshot,estimated_service_minutes)'
    return fetchJson(routeUrl(nestedSelect), 12000).then(function (plans) {
      return Array.isArray(plans) && plans.length ? plans[0] : null
    })
  }

  function loadVehicle(vehicleId) {
    if (!vehicleId) return Promise.resolve(null)
    var url = supabaseUrl + '/rest/v1/vehicles?select=' + encodeURIComponent('id,name,plate')
      + '&id=eq.' + encodeURIComponent(vehicleId) + '&limit=1'
    return fetchJson(url, 8000).then(function (vehicles) {
      return Array.isArray(vehicles) && vehicles.length ? vehicles[0] : null
    }).catch(function () { return null })
  }

  function stopIsClosed(stop) {
    return ['completed', 'done', 'skipped'].indexOf(String(stop.status || '').toLowerCase()) >= 0
  }

  function renderEmpty() {
    content.innerHTML = '<section class="oh-empty"><strong>Na dnešek nemáš přiřazenou trasu</strong><span>Jakmile vedoucí trasu zveřejní a přiřadí k tvému účtu, objeví se automaticky tady.</span><button type="button" data-home-refresh>Aktualizovat</button></section>'
  }

  function renderError(error) {
    var message = error && error.name === 'AbortError' ? 'Načítání trasy trvalo příliš dlouho.' : (error && error.message ? error.message : 'Trasu se nepodařilo načíst.')
    content.innerHTML = '<section class="oh-error"><strong>Trasa se nenačetla</strong><span>' + escapeHtml(message) + '</span><button type="button" data-home-refresh>Zkusit znovu</button></section>'
  }

  function renderRoute(plan, vehicle) {
    var stops = Array.isArray(plan.route_plan_stops) ? plan.route_plan_stops.slice() : []
    stops.sort(function (a, b) { return Number(a.stop_order || 0) - Number(b.stop_order || 0) })
    var completed = stops.filter(stopIsClosed).length
    var nextStop = stops.find(function (stop) { return !stopIsClosed(stop) }) || null
    var normalizedStatus = String(plan.execution_status || '').toLowerCase()
    var status = ['done', 'completed'].indexOf(normalizedStatus) >= 0 ? 'Hotovo' : ['in_progress', 'started'].indexOf(normalizedStatus) >= 0 ? 'Probíhá' : 'Čeká na převzetí'
    var waitingClass = status === 'Čeká na převzetí' ? ' waiting' : ''
    var vehicleLabel = vehicle ? [vehicle.name || 'Vozidlo', vehicle.plate].filter(Boolean).join(' · ') : 'Vozidlo podle plánu'
    var distance = Number(plan.estimated_distance_km || 0)
    var duration = Number(plan.estimated_drive_minutes || 0)
    var stopMarkup = stops.map(function (stop) {
      var done = stopIsClosed(stop)
      var state = done ? (String(stop.status).toLowerCase() === 'skipped' ? 'Nejeto' : 'Hotovo') : 'Čeká'
      var address = [stop.address_snapshot, stop.city_snapshot].filter(Boolean).join(', ')
      return '<article class="oh-stop' + (done ? ' done' : '') + '"><span class="oh-stop-order">' + (done ? '✓' : escapeHtml(stop.stop_order || '–')) + '</span><div class="oh-stop-copy"><strong>' + escapeHtml(stop.title || 'Zastávka') + '</strong><span>' + escapeHtml(address || 'Adresa není uvedena') + '</span></div><span class="oh-stop-state">' + escapeHtml(state) + '</span></article>'
    }).join('')
    var nextMarkup = nextStop ? '<article class="oh-next"><small>Další zastávka</small><strong>' + escapeHtml(nextStop.title || 'Zastávka') + '</strong><span>' + escapeHtml([nextStop.address_snapshot, nextStop.city_snapshot].filter(Boolean).join(', ') || 'Adresa není uvedena') + '</span></article>' : ''

    content.innerHTML = '<section class="oh-route"><article class="oh-route-hero"><div class="oh-route-head"><div class="oh-route-kicker"><span>Dnešní trasa</span><span class="oh-route-status' + waitingClass + '">' + escapeHtml(status) + '</span></div><h2>' + escapeHtml(plan.title || 'Dnešní trasa') + '</h2><p>' + escapeHtml(vehicleLabel) + '</p></div><div class="oh-metrics"><div class="oh-metric"><span>Zastávky</span><strong>' + completed + ' / ' + stops.length + '</strong></div><div class="oh-metric"><span>Trasa</span><strong>' + (distance ? distance.toLocaleString('cs-CZ', { maximumFractionDigits: 1 }) + ' km' : '—') + '</strong></div><div class="oh-metric"><span>Jízda</span><strong>' + (duration ? duration + ' min' : '—') + '</strong></div></div></article>' + nextMarkup + '<div class="oh-list-head"><h3>Pořadí zastávek</h3><span>' + stops.length + ' celkem</span></div><div class="oh-stops">' + (stopMarkup || '<section class="oh-empty"><strong>Trasa zatím nemá zastávky</strong><span>Počkej na doplnění plánu vedoucím.</span></section>') + '</div><button class="oh-refresh" type="button" data-home-refresh>Aktualizovat trasu</button></section>'
  }

  function refresh() {
    content.innerHTML = '<section class="oh-loading"><i aria-hidden="true"></i><strong>Načítám dnešní trasu</strong><span>Kontroluji přiřazení, vozidlo a zastávky.</span></section>'
    return loadRoute().then(function (plan) {
      if (!plan) { renderEmpty(); return }
      return loadVehicle(plan.vehicle_id).then(function (vehicle) { renderRoute(plan, vehicle) })
    }).catch(renderError)
  }

  content.addEventListener('click', function (event) {
    if (event.target.closest('[data-home-refresh]')) refresh()
  })

  window.operatorHomeStart = function (session, employee) {
    currentSession = session
    currentEmployee = employee || {}
    if (!home || !content) return
    home.hidden = false
    var fullName = [currentEmployee.name, currentEmployee.surname].filter(Boolean).join(' ')
    employeeName.textContent = fullName ? 'Ahoj, ' + fullName : 'Dnešní směna'
    dateLabel.textContent = formatDate(todayIso())
    if (!currentEmployee.id) { renderError(new Error('K přihlášení chybí zaměstnanecký profil.')); return }
    refresh()
  }
})()
