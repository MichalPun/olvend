(function () {
  'use strict'

  var supabaseUrl = 'https://rerjlkrhiytgscjerqgs.supabase.co'
  var supabaseKey = 'sb_publishable_A8OxCcapdNXAzQLjLsW5iA_XtGvBZ0S'
  var root = document.getElementById('operator-route')
  var session = null
  var employee = null
  var plan = null
  var vehicle = null
  var stops = []

  function todayIso() {
    try { return new Intl.DateTimeFormat('sv-SE', { timeZone: 'Europe/Prague' }).format(new Date()) }
    catch (_) { return new Date().toISOString().slice(0, 10) }
  }

  function requestJson(url) {
    return fetch(url, { headers: { apikey: supabaseKey, Authorization: 'Bearer ' + session.access_token } }).then(function (response) {
      if (!response.ok) throw new Error('Data trasy se nepodařilo načíst.')
      return response.json()
    })
  }

  function showSheet(kicker, title, renderer) {
    root.querySelector('#or-sheet-kicker').textContent = kicker
    root.querySelector('#or-sheet-title').textContent = title
    var body = root.querySelector('#or-sheet-body')
    body.innerHTML = ''
    renderer(body)
    root.querySelector('#or-overlay').hidden = false
  }

  function addRow(list, stop, index) {
    var row = document.createElement('div')
    row.className = 'or-row'
    var number = document.createElement('b')
    var copy = document.createElement('div')
    var title = document.createElement('strong')
    var address = document.createElement('span')
    number.textContent = String(stop.stop_order || index + 1)
    title.textContent = stop.title || 'Zastávka ' + (index + 1)
    address.textContent = [stop.address_snapshot, stop.city_snapshot].filter(Boolean).join(', ') || 'Adresa není uvedena'
    copy.appendChild(title)
    copy.appendChild(address)
    row.appendChild(number)
    row.appendChild(copy)
    list.appendChild(row)
  }

  function openRouteList() {
    showSheet('Dnešní trasa', plan && plan.title || 'Přehled zastávek', function (body) {
      var list = document.createElement('div')
      list.className = 'or-list'
      stops.forEach(function (stop, index) { addRow(list, stop, index) })
      body.appendChild(list)
    })
  }

  function openVehicle() {
    showSheet('Směna', 'Vozidlo', function (body) {
      var list = document.createElement('div')
      list.className = 'or-list'
      addRow(list, { stop_order: '✓', title: vehicle ? (vehicle.plate || vehicle.name) : 'Vozidlo není přiřazené', address_snapshot: vehicle ? vehicle.name : '' }, 0)
      body.appendChild(list)
    })
  }

  function openStock() {
    showSheet('Vozidlo', 'Zásoby', function (body) {
      var list = document.createElement('div')
      list.className = 'or-list'
      addRow(list, { stop_order: '✓', title: 'Nakládka ve vozidle', address_snapshot: 'Skutečné zásoby se při obsluze odečítají přímo z přiřazeného vozidla.' }, 0)
      body.appendChild(list)
    })
  }

  function openOverview() {
    showSheet('Aktivní směna', 'Přehled', function (body) {
      var list = document.createElement('div')
      list.className = 'or-list'
      addRow(list, { stop_order: stops.filter(isDone).length, title: 'Hotové zastávky', address_snapshot: stops.length + ' zastávek celkem' }, 0)
      addRow(list, { stop_order: 'km', title: Number(plan && plan.estimated_distance_km || 0).toLocaleString('cs-CZ', { maximumFractionDigits: 1 }) + ' km', address_snapshot: 'Plánovaná délka dnešní trasy' }, 1)
      body.appendChild(list)
    })
  }

  function openMore() {
    showSheet('Přihlášený operátor', [employee.name, employee.surname].filter(Boolean).join(' '), function (body) {
      var list = document.createElement('div')
      list.className = 'or-list'
      addRow(list, { stop_order: '●', title: 'Směna je aktivní', address_snapshot: employee.role || 'operátor' }, 0)
      body.appendChild(list)
      var button = document.createElement('button')
      button.className = 'or-sheet-action'
      button.type = 'button'
      button.textContent = 'Zpět na obrazovku před směnou'
      button.addEventListener('click', function () { window.location.href = './uvod.html' })
      body.appendChild(button)
    })
  }

  function isDone(stop) {
    return ['done', 'completed'].indexOf(String(stop && stop.status || '').toLowerCase()) !== -1
  }

  function nextStop() {
    return stops.find(function (stop) { return !isDone(stop) && String(stop.status || '').toLowerCase() !== 'skipped' }) || stops[0] || null
  }

  function openStop(stop) {
    if (!stop) return
    showSheet('Další zastávka', stop.title || 'Zastávka', function (body) {
      var list = document.createElement('div')
      list.className = 'or-list'
      addRow(list, stop, 0)
      body.appendChild(list)
      if (stop.latitude != null && stop.longitude != null || stop.address_snapshot) {
        var button = document.createElement('button')
        button.className = 'or-sheet-action'
        button.type = 'button'
        button.textContent = 'Navigovat na zastávku'
        button.addEventListener('click', function () { navigateTo(stop) })
        body.appendChild(button)
      }
    })
  }

  function navigateTo(stop) {
    var destination = stop.latitude != null && stop.longitude != null
      ? stop.latitude + ',' + stop.longitude
      : [stop.address_snapshot, stop.city_snapshot].filter(Boolean).join(', ')
    if (!destination) return
    window.location.href = 'https://www.google.com/maps/dir/?api=1&destination=' + encodeURIComponent(destination)
  }

  function render() {
    stops = (plan && Array.isArray(plan.route_plan_stops) ? plan.route_plan_stops : []).slice().sort(function (a, b) { return Number(a.stop_order || 0) - Number(b.stop_order || 0) })
    var done = stops.filter(isDone).length
    var remaining = Math.max(0, stops.length - done)
    var percent = stops.length ? Math.max(4, Math.round(done / stops.length * 100)) : 0
    root.querySelector('#or-header-state').textContent = 'Aktivní směna' + (vehicle ? ' · ' + (vehicle.plate || vehicle.name) : '')
    root.querySelector('#or-started').textContent = plan && plan.started_at ? 'Začátek směny ' + new Date(plan.started_at).toLocaleTimeString('cs-CZ', { hour: '2-digit', minute: '2-digit' }) : 'Dnešní aktivní směna'
    root.querySelector('#or-progress-label').textContent = done + ' z ' + stops.length + ' zastávek hotovo'
    root.querySelector('#or-progress-meta').textContent = Number(plan && plan.estimated_distance_km || 0).toLocaleString('cs-CZ', { maximumFractionDigits: 1 }) + ' km'
    root.querySelector('#or-remaining').textContent = remaining + ' zbývá'
    root.querySelector('#or-progress-bar').style.width = percent + '%'
    root.querySelector('#or-vehicle').querySelector('span').textContent = vehicle ? [vehicle.plate, vehicle.name].filter(Boolean).join(' · ') : 'Není přiřazené'

    var stop = nextStop()
    var article = root.querySelector('#or-next')
    article.innerHTML = ''
    if (!stop) {
      var empty = document.createElement('div')
      empty.className = 'or-loading'
      empty.textContent = 'Dnešní trasa nemá žádnou zastávku.'
      article.appendChild(empty)
      return
    }
    var label = document.createElement('div')
    label.className = 'or-label'
    label.innerHTML = '<span>Další zastávka</span><b></b>'
    label.querySelector('b').textContent = String(stop.stop_order || 1) + ' z ' + stops.length
    var place = document.createElement('div')
    place.className = 'or-place'
    var pin = document.createElement('i')
    pin.className = 'or-pin'
    pin.textContent = '●'
    var copy = document.createElement('div')
    var title = document.createElement('strong')
    var address = document.createElement('span')
    title.textContent = stop.title || 'Zastávka ' + (stop.stop_order || 1)
    address.textContent = [stop.address_snapshot, stop.city_snapshot].filter(Boolean).join(', ') || 'Adresa není uvedena'
    copy.appendChild(title)
    copy.appendChild(address)
    place.appendChild(pin)
    place.appendChild(copy)
    var meta = document.createElement('div')
    meta.className = 'or-stop-meta'
    meta.textContent = 'Pořadí ' + (stop.stop_order || 1) + ' · ' + (stop.status || 'čeká')
    var actions = document.createElement('div')
    actions.className = 'or-actions-row'
    var navigate = document.createElement('button')
    navigate.className = 'or-navigate'
    navigate.type = 'button'
    navigate.textContent = 'Navigovat'
    navigate.disabled = !(stop.latitude != null && stop.longitude != null || stop.address_snapshot)
    navigate.addEventListener('click', function () { navigateTo(stop) })
    var open = document.createElement('button')
    open.className = 'or-open'
    open.type = 'button'
    open.textContent = 'Otevřít zastávku'
    open.addEventListener('click', function () { openStop(stop) })
    actions.appendChild(navigate)
    actions.appendChild(open)
    article.appendChild(label)
    article.appendChild(place)
    article.appendChild(meta)
    article.appendChild(actions)
  }

  function load() {
    var select = 'id,title,vehicle_id,execution_status,estimated_distance_km,estimated_drive_minutes,started_at,route_plan_stops(id,stop_order,status,title,address_snapshot,city_snapshot,latitude,longitude,machine_id,location_id)'
    var routeUrl = supabaseUrl + '/rest/v1/route_plans?select=' + encodeURIComponent(select)
      + '&planned_employee_id=eq.' + encodeURIComponent(employee.id) + '&planning_date=eq.' + encodeURIComponent(todayIso())
      + '&execution_status=neq.cancelled&order=created_at.desc&limit=1'
    return requestJson(routeUrl).then(function (rows) {
      plan = Array.isArray(rows) && rows.length ? rows[0] : null
      if (!plan) throw new Error('Dnešní trasa není přiřazená.')
      if (!plan.vehicle_id) return null
      return requestJson(supabaseUrl + '/rest/v1/vehicles?select=id,name,plate,current_odometer_km&id=eq.' + encodeURIComponent(plan.vehicle_id) + '&limit=1')
    }).then(function (rows) {
      vehicle = Array.isArray(rows) && rows.length ? rows[0] : null
      render()
    })
  }

  root.querySelector('#or-close').addEventListener('click', function () { root.querySelector('#or-overlay').hidden = true })
  root.querySelector('#or-nav-route').addEventListener('click', openRouteList)
  root.querySelector('#or-vehicle').addEventListener('click', openVehicle)
  root.querySelector('#or-stock').addEventListener('click', openStock)
  root.querySelector('#or-nav-stock').addEventListener('click', openStock)
  root.querySelector('#or-nav-overview').addEventListener('click', openOverview)
  root.querySelector('#or-nav-more').addEventListener('click', openMore)

  window.operatorRouteStart = function (activeSession, activeEmployee) {
    session = activeSession
    employee = activeEmployee || {}
    if (!employee.id) return
    load().catch(function (error) {
      root.querySelector('#or-next').innerHTML = '<div class="or-loading"></div>'
      root.querySelector('#or-next .or-loading').textContent = error && error.message ? error.message : 'Trasu se nepodařilo načíst.'
    })
  }
})()
