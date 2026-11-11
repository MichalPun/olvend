(function () {
  'use strict'

  var supabaseUrl = 'https://rerjlkrhiytgscjerqgs.supabase.co'
  var supabaseKey = 'sb_publishable_A8OxCcapdNXAzQLjLsW5iA_XtGvBZ0S'
  var root = document.getElementById('olvend-before-shift-tiles')
  var session = null
  var employee = null
  var routePlan = null
  var vehicle = null
  var instruction = null
  var attendanceDay = null
  var vehicleLog = null
  var instructionConfirmed = false
  var vehicleConfirmed = false
  var startOdometer = null

  function isShiftPreview() {
    return location.hostname === '127.0.0.1' && new URLSearchParams(location.search).get('preview') === 'shift-start'
  }

  var iconPaths = {
    route: '<circle cx="6" cy="19" r="3"></circle><path d="M9 19h6.5a3.5 3.5 0 0 0 0-7h-8a3.5 3.5 0 0 1 0-7H15"></path><circle cx="18" cy="5" r="3"></circle>',
    'refresh-cw': '<path d="M21 12a9 9 0 0 0-15.2-6.5L3 8"></path><path d="M3 3v5h5"></path><path d="M3 12a9 9 0 0 0 15.2 6.5L21 16"></path><path d="M16 16h5v5"></path>',
    'map-pinned': '<path d="m3 6 6-3 6 3 6-3v15l-6 3-6-3-6 3Z"></path><path d="M9 3v15M15 6v15"></path><circle cx="15" cy="10" r="2"></circle>',
    'car-front': '<path d="m5 17-2 2"></path><path d="m19 17 2 2"></path><path d="M5 9l1.5-4h11L19 9"></path><path d="M3 11h18v6H3z"></path><circle cx="7" cy="14" r="1"></circle><circle cx="17" cy="14" r="1"></circle>',
    'notebook-tabs': '<path d="M4 4a2 2 0 0 1 2-2h12v20H6a2 2 0 0 1-2-2Z"></path><path d="M8 2v20M12 6h6M12 10h6"></path>',
    'circle-user-round': '<circle cx="12" cy="12" r="10"></circle><circle cx="12" cy="9" r="3"></circle><path d="M6.2 18a6 6 0 0 1 11.6 0"></path>',
    'lock-keyhole': '<rect width="16" height="12" x="4" y="10" rx="2"></rect><path d="M8 10V7a4 4 0 0 1 8 0v3"></path><circle cx="12" cy="16" r="1"></circle>',
    'arrow-right': '<path d="M5 12h14"></path><path d="m13 6 6 6-6 6"></path>'
  }

  function installIcons() {
    Array.prototype.forEach.call(root.querySelectorAll('[data-lucide]'), function (node) {
      var name = node.getAttribute('data-lucide')
      var paths = iconPaths[name] || iconPaths.route
      var svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg')
      svg.setAttribute('viewBox', '0 0 24 24')
      svg.setAttribute('fill', 'none')
      svg.setAttribute('stroke', 'currentColor')
      svg.setAttribute('stroke-width', '2')
      svg.setAttribute('stroke-linecap', 'round')
      svg.setAttribute('stroke-linejoin', 'round')
      svg.setAttribute('aria-hidden', 'true')
      svg.innerHTML = paths
      node.replaceWith(svg)
    })
  }

  function todayIso() {
    try { return new Intl.DateTimeFormat('sv-SE', { timeZone: 'Europe/Prague' }).format(new Date()) }
    catch (_) {
      var now = new Date()
      return [now.getFullYear(), ('0' + (now.getMonth() + 1)).slice(-2), ('0' + now.getDate()).slice(-2)].join('-')
    }
  }

  function formatDateLong() {
    try { return new Intl.DateTimeFormat('cs-CZ', { weekday: 'long', day: 'numeric', month: 'long' }).format(new Date()) }
    catch (_) { return todayIso() }
  }

  function machineCountLabel(count) {
    return count + (count === 1 ? ' automat' : count > 1 && count < 5 ? ' automaty' : ' automatů')
  }

  function locationCount() {
    var seen = new Set()
    ;(routePlan && routePlan.route_plan_stops || []).forEach(function (stop) {
      seen.add(stop.location_id ? 'id:' + stop.location_id : [stop.address_snapshot, stop.city_snapshot].join('|'))
    })
    return seen.size
  }

  function locationCountLabel(count) {
    return count + (count === 1 ? ' zastávka' : count > 1 && count < 5 ? ' zastávky' : ' zastávek')
  }

  function vocativeName(value) {
    var name = String(value || '').trim()
    if (!name) return ''
    var lower = name.toLocaleLowerCase('cs-CZ')
    var known = {
      michal: 'Michale', pavel: 'Pavle', petr: 'Petře', marek: 'Marku', tomáš: 'Tomáši', lukáš: 'Lukáši',
      martin: 'Martine', david: 'Davide', jan: 'Jane', jakub: 'Jakube', radek: 'Radku', roman: 'Romane',
      ondřej: 'Ondřeji', jiří: 'Jiří', filip: 'Filipe', adam: 'Adame', daniel: 'Danieli', josef: 'Josefe',
      karel: 'Karle', václav: 'Václave', aleš: 'Aleši', miloš: 'Miloši', zdeněk: 'Zdeňku', františek: 'Františku',
      kristýna: 'Kristýno', petra: 'Petro', eva: 'Evo', hana: 'Hano', jana: 'Jano', anna: 'Anno',
      veronika: 'Veroniko', monika: 'Moniko', lenka: 'Lenko', barbora: 'Barboro', nikola: 'Nikolo',
      lucie: 'Lucie', marie: 'Marie', tereza: 'Terezo', kateřina: 'Kateřino', zuzana: 'Zuzano'
    }
    if (known[lower]) return known[lower]
    if (/a$/i.test(name)) return name.slice(0, -1) + 'o'
    if (/(ec|ek|ěk)$/i.test(name)) return name.replace(/(ec|ek|ěk)$/i, '') + 'ku'
    if (/k$/i.test(name)) return name.slice(0, -1) + 'ku'
    if (/(š|č|ř|ž|j)$/i.test(name)) return name + 'i'
    if (/(l|n|m|b|d|f|v)$/i.test(name)) return name + 'e'
    return name
  }

  function apiRequest(url, options, timeoutMs) {
    var controller = typeof AbortController === 'function' ? new AbortController() : null
    var timer
    var requestOptions = Object.assign({}, options || {})
    requestOptions.headers = Object.assign({
      'apikey': supabaseKey,
      'Authorization': 'Bearer ' + session.access_token,
      'Content-Type': 'application/json'
    }, requestOptions.headers || {})
    if (controller) requestOptions.signal = controller.signal
    var timeout = new Promise(function (_, reject) {
      timer = window.setTimeout(function () {
        if (controller) controller.abort()
        reject(new Error('Načítání trvalo příliš dlouho.'))
      }, timeoutMs || 12000)
    })
    return Promise.race([fetch(url, requestOptions), timeout]).then(function (response) {
      window.clearTimeout(timer)
      if (!response.ok) return response.text().then(function (text) {
        var detail = ''
        try { detail = JSON.parse(text).message || JSON.parse(text).details || '' } catch (_) {}
        throw new Error(detail || 'Požadavek se nepodařilo uložit (HTTP ' + response.status + ').')
      })
      if (response.status === 204) return null
      return response.text().then(function (text) { return text ? JSON.parse(text) : null })
    }, function (error) {
      window.clearTimeout(timer)
      throw error
    })
  }

  function loadRoute() {
    var select = 'id,planning_date,title,vehicle_id,execution_status,estimated_distance_km,estimated_drive_minutes,started_at,route_plan_stops(id,stop_order,status,title,address_snapshot,city_snapshot,latitude,longitude,machine_id,location_id)'
    var url = supabaseUrl + '/rest/v1/route_plans?select=' + encodeURIComponent(select)
      + '&planned_employee_id=eq.' + encodeURIComponent(employee.id)
      + '&planning_date=eq.' + encodeURIComponent(todayIso())
      + '&execution_status=neq.cancelled&order=created_at.desc&limit=1'
    return apiRequest(url, {}, 12000).then(function (rows) { return Array.isArray(rows) && rows.length ? rows[0] : null })
  }

  function loadVehicle(vehicleId) {
    var fields = 'id,name,plate,current_odometer_km,warehouse_id,assigned_employee_id'
    var url = supabaseUrl + '/rest/v1/vehicles?select=' + encodeURIComponent(fields)
      + (vehicleId
        ? '&id=eq.' + encodeURIComponent(vehicleId)
        : '&assigned_employee_id=eq.' + encodeURIComponent(employee.id) + '&active=eq.true&order=id&limit=1')
    if (vehicleId) url += '&limit=1'
    return apiRequest(url, {}, 8000).then(function (rows) { return Array.isArray(rows) && rows.length ? rows[0] : null }).catch(function () { return null })
  }

  function loadInstruction() {
    var url = supabaseUrl + '/rest/v1/daily_instructions?select=*&is_active=eq.true&order=created_at.desc&limit=20'
    return apiRequest(url, {}, 9000).then(function (rows) {
      var today = todayIso()
      return (Array.isArray(rows) ? rows : []).find(function (item) {
        var starts = item.is_persistent || !item.valid_from || String(item.valid_from).slice(0, 10) <= today
        var ends = item.is_persistent || !item.valid_to || String(item.valid_to).slice(0, 10) >= today
        var target = item.target_type === 'company'
          || (item.target_type === 'role' && String(item.target_role || '').toLowerCase() === String(employee.role || '').toLowerCase())
          || (item.target_type === 'employee' && String(item.target_employee_id || '') === String(employee.id || ''))
        return starts && ends && target
      }) || null
    }).catch(function () { return null })
  }

  function loadAttendance() {
    var url = supabaseUrl + '/rest/v1/attendance_days?select=*&employee_id=eq.' + encodeURIComponent(employee.id)
      + '&attendance_date=eq.' + encodeURIComponent(todayIso()) + '&limit=1'
    return apiRequest(url, {}, 9000).then(function (rows) { return Array.isArray(rows) && rows.length ? rows[0] : null }).catch(function () { return null })
  }

  function loadInstructionAcknowledgement() {
    if (!instruction || instruction.requires_acknowledgement === false) return Promise.resolve(true)
    var url = supabaseUrl + '/rest/v1/instruction_acknowledgements?select=id&instruction_id=eq.' + encodeURIComponent(instruction.id)
      + '&employee_id=eq.' + encodeURIComponent(employee.id) + '&limit=1'
    return apiRequest(url, {}, 8000).then(function (rows) { return Boolean(Array.isArray(rows) && rows.length) }).catch(function () { return false })
  }

  function loadVehicleLog() {
    if (!attendanceDay || !attendanceDay.id || !vehicle) return Promise.resolve(null)
    var url = supabaseUrl + '/rest/v1/vehicle_operation_logs?select=*&attendance_day_id=eq.' + encodeURIComponent(attendanceDay.id)
      + '&vehicle_id=eq.' + encodeURIComponent(vehicle.id) + '&status=eq.open&order=created_at.desc&limit=1'
    return apiRequest(url, {}, 8000).then(function (rows) { return Array.isArray(rows) && rows.length ? rows[0] : null }).catch(function () { return null })
  }

  function setConfirmed(confirmed) {
    instructionConfirmed = confirmed
    var instructions = root.querySelector('#ot-instructions')
    var required = root.querySelector('#ot-required')
    var stateLabel = root.querySelector('#ot-instruction-state')
    instructions.classList.toggle('pending', Boolean(instruction) && !confirmed)
    required.classList.toggle('confirmed', !instruction || confirmed)
    required.textContent = !instruction ? 'Bez pokynu' : confirmed ? 'Potvrzeno' : 'Povinné'
    stateLabel.textContent = !instruction || confirmed ? 'Hotovo ✓' : 'Přečíst ›'
    instructions.querySelector('h3').textContent = !instruction ? '2. Dnes bez nového pokynu' : confirmed ? '2. Pokyn přečten' : '2. Přečti dnešní pokyn'
    instructions.querySelector('p').textContent = !instruction ? 'Není potřeba nic potvrzovat' : confirmed ? (instruction.title || 'Povinný pokyn potvrzen') : (instruction.title || 'Krátká informace před výjezdem')
    root.querySelector('#ot-guide-progress').textContent = (Number(vehicleConfirmed) + Number(!instruction || confirmed)) + ' ze 2 hotovo'
    updateReadiness()
  }

  function isShiftRunning() {
    return Boolean((attendanceDay && attendanceDay.actual_start && !attendanceDay.actual_end) || (routePlan && routePlan.execution_status === 'in_progress'))
  }

  function vehicleKey() {
    return 'olvendOperatorVehicleV2:' + todayIso() + ':' + (employee && employee.id || '') + ':' + (vehicle && vehicle.id || '') + ':' + (routePlan && routePlan.id || '')
  }

  function readVehicleConfirmation() {
    if (vehicleLog && vehicleLog.start_odometer_km != null) {
      vehicleConfirmed = true
      startOdometer = Number(vehicleLog.start_odometer_km)
      return
    }
    try {
      var stored = JSON.parse(localStorage.getItem(vehicleKey()) || 'null')
      vehicleConfirmed = Boolean(stored && stored.confirmed)
      startOdometer = stored && Number(stored.odometer)
    } catch (_) {
      vehicleConfirmed = false
      startOdometer = null
    }
  }

  function updateReadiness() {
    var start = root.querySelector('#ot-start')
    var help = root.querySelector('#ot-start-help')
    var running = isShiftRunning()
    var ready = running || Boolean(routePlan && vehicle && vehicleConfirmed && (!instruction || instructionConfirmed))
    start.disabled = !ready
    if (running) {
      start.innerHTML = 'Pokračovat v trase <span data-lucide="arrow-right" aria-hidden="true"></span>'
      help.hidden = true
    } else if (ready) {
      start.innerHTML = 'Zahájit směnu <span data-lucide="arrow-right" aria-hidden="true"></span>'
      help.hidden = true
    } else {
      var reason = !routePlan ? 'Čeká na dnešní trasu' : !vehicle ? 'Čeká na vozidlo' : !vehicleConfirmed ? 'Nejdřív potvrď vozidlo a km' : 'Nejdřív přečti dnešní pokyn'
      start.innerHTML = '<span data-lucide="lock-keyhole" aria-hidden="true"></span><span>' + reason + '</span>'
      help.hidden = false
      help.textContent = !routePlan ? 'Vedoucí zatím nepřiřadil dnešní trasu.'
          : !vehicle ? 'Pro dnešní směnu zatím není přiřazené vozidlo.'
            : !vehicleConfirmed ? 'Ověř RZ a opiš skutečný stav z tachometru.'
              : 'Před zahájením směny potvrď dnešní povinný pokyn.'
    }
    installIcons()
    var state = root.querySelector('.ot-state')
    state.innerHTML = running
      ? 'Směna probíhá · <b>trasa je aktivní</b>'
      : ready ? 'Směna ještě nebyla zahájena · <b>vše je připravené</b>' : 'Směna ještě nebyla zahájena · <b>čeká povinný krok</b>'
  }

  function renderData() {
    var salutation = vocativeName(employee.name)
    root.querySelector('.ot-date').textContent = formatDateLong()
    root.querySelector('.ot-main h2').textContent = (new Date().getHours() < 12 ? 'Dobré ráno' : 'Dobrý den') + (salutation ? ', ' + salutation : '')
    root.querySelector('.ot-tile.profile strong').textContent = [employee.name, employee.surname].filter(Boolean).join(' ') || 'Můj profil'
    var routeTile = root.querySelector('#ot-route')
    var stops = routePlan && Array.isArray(routePlan.route_plan_stops) ? routePlan.route_plan_stops.length : 0
    routeTile.querySelector('p').textContent = routePlan ? (routePlan.title || 'Dnešní trasa') : 'Trasa zatím nepřiřazena'
    routeTile.querySelector('strong').textContent = routePlan
      ? machineCountLabel(stops) + ' · ' + (routePlan.estimated_distance_km == null ? 'vzdálenost se načítá' : Number(routePlan.estimated_distance_km).toLocaleString('cs-CZ', { maximumFractionDigits: 1 }) + ' km')
      : 'Čeká na plán'
    var vehicleTile = root.querySelector('.ot-tile.vehicle')
    vehicleTile.classList.toggle('ready', vehicleConfirmed)
    vehicleTile.querySelector('h3').textContent = vehicleConfirmed ? '1. Vozidlo potvrzeno' : '1. Potvrď vozidlo a km'
    vehicleTile.querySelector('p').textContent = vehicle
      ? [vehicle.name || 'Přiřazené vozidlo', vehicle.plate || 'Bez RZ', vehicleConfirmed && startOdometer != null ? Number(startOdometer).toLocaleString('cs-CZ') + ' km' : ''].filter(Boolean).join(' · ')
      : 'Vozidlo zatím není přiřazeno'
    vehicleTile.querySelector('strong').textContent = vehicleConfirmed ? 'Hotovo ✓' : vehicle ? 'Potvrdit ›' : 'Nevybráno'
    var instructionTile = root.querySelector('#ot-instructions')
    instructionTile.querySelector('h3').textContent = !instruction ? '2. Dnes bez nového pokynu' : instructionConfirmed ? '2. Pokyn přečten' : '2. Přečti dnešní pokyn'
    instructionTile.querySelector('p').textContent = !instruction ? 'Není potřeba nic potvrzovat' : instructionConfirmed ? (instruction.title || 'Povinný pokyn potvrzen') : (instruction.title || 'Krátká informace před výjezdem')
    root.querySelector('#ot-guide-progress').textContent = (Number(vehicleConfirmed) + Number(!instruction || instructionConfirmed)) + ' ze 2 hotovo'
    root.querySelector('.ot-brand-copy span').textContent = vehicle ? 'Před směnou · ' + (vehicle.plate || vehicle.name || 'vozidlo') : 'Před zahájením směny'
    if (instruction) {
      root.querySelector('.ot-sheet-title h3').textContent = instruction.title || instruction.name || 'Povinný pokyn dne'
      root.querySelector('.ot-instruction').textContent = instruction.body || instruction.content || instruction.message || instruction.note || 'Přečtěte si pokyn a potvrďte jeho převzetí.'
    }
    setConfirmed(instructionConfirmed)
  }

  function showPanel(kicker, title, render) {
    var panel = root.querySelector('#ot-panel')
    var body = root.querySelector('#ot-panel-body')
    root.querySelector('#ot-panel-kicker').textContent = kicker
    root.querySelector('#ot-panel-title').textContent = title
    body.innerHTML = ''
    render(body)
    panel.hidden = false
  }

  function hidePanel() { root.querySelector('#ot-panel').hidden = true }

  function addCard(parent, title, detail) {
    var card = document.createElement('div')
    card.className = 'ot-panel-card'
    var strong = document.createElement('strong')
    var span = document.createElement('span')
    strong.textContent = title
    span.textContent = detail || ''
    card.appendChild(strong)
    card.appendChild(span)
    parent.appendChild(card)
    return card
  }

  function openRoutePanel() {
    showPanel('Dnešní plán', 'Dnešní trasa', function (body) {
      if (!routePlan) {
        addCard(body, 'Trasa zatím není přiřazená', 'Po přiřazení vedoucím se zde zobrazí skutečné zastávky.')
        return
      }
      addCard(body, routePlan.title || 'Dnešní trasa', locationCountLabel(locationCount()) + ' · ' + machineCountLabel((routePlan.route_plan_stops || []).length) + ' · ' + (routePlan.estimated_distance_km == null ? 'vzdálenost se načítá' : Number(routePlan.estimated_distance_km).toLocaleString('cs-CZ', { maximumFractionDigits: 1 }) + ' km'))
      var list = document.createElement('div')
      list.className = 'ot-route-list'
      ;(routePlan.route_plan_stops || []).slice().sort(function (a, b) { return Number(a.stop_order || 0) - Number(b.stop_order || 0) }).forEach(function (stop, index) {
        var row = document.createElement('div')
        row.className = 'ot-route-row'
        var order = document.createElement('b')
        var copy = document.createElement('div')
        var name = document.createElement('strong')
        var address = document.createElement('span')
        order.textContent = String(stop.stop_order || index + 1)
        name.textContent = stop.title || 'Zastávka ' + (index + 1)
        address.textContent = [stop.address_snapshot, stop.city_snapshot].filter(Boolean).join(', ') || 'Adresa není uvedena'
        copy.appendChild(name)
        copy.appendChild(address)
        row.appendChild(order)
        row.appendChild(copy)
        list.appendChild(row)
      })
      body.appendChild(list)
    })
  }

  function openVehiclePanel() {
    showPanel('Krok 1 ze 2', 'Potvrdit dnešní vozidlo', function (body) {
      if (!vehicle) {
        addCard(body, 'Vozidlo není přiřazené', 'Po přiřazení vozidla vedoucím bude možné potvrdit počáteční stav kilometrů.')
        return
      }
      var intro = document.createElement('div')
      intro.className = 'ot-panel-intro'
      intro.innerHTML = '<b>1.</b> Ověř, že sedí RZ. &nbsp; <b>2.</b> Opiš stav z tachometru. &nbsp; <b>3.</b> Potvrď.'
      body.appendChild(intro)
      addCard(body, vehicle.plate || 'Bez RZ', (vehicle.name || 'Přiřazené vozidlo') + ' · poslední stav ' + Number(vehicle.current_odometer_km || 0).toLocaleString('cs-CZ') + ' km')
      var field = document.createElement('div')
      field.className = 'ot-field'
      var label = document.createElement('label')
      label.setAttribute('for', 'ot-odometer')
      label.textContent = 'Stav na tachometru právě teď'
      var shell = document.createElement('div')
      shell.className = 'ot-field-shell'
      var input = document.createElement('input')
      input.id = 'ot-odometer'
      input.type = 'number'
      input.min = String(Math.max(0, Number(vehicle.current_odometer_km || 0)))
      input.step = '1'
      input.inputMode = 'numeric'
      input.value = String(startOdometer != null ? startOdometer : Number(vehicle.current_odometer_km || 0))
      var unit = document.createElement('b')
      unit.textContent = 'km'
      shell.appendChild(input)
      shell.appendChild(unit)
      field.appendChild(label)
      field.appendChild(shell)
      body.appendChild(field)
      var error = document.createElement('p')
      error.className = 'ot-panel-error'
      error.hidden = true
      body.appendChild(error)
      var button = document.createElement('button')
      button.className = 'ot-panel-action'
      button.type = 'button'
      button.textContent = vehicleConfirmed ? 'Uložit opravený stav km' : 'Ano, toto je moje vozidlo · potvrdit km'
      button.addEventListener('click', function () {
        var value = Number(input.value)
        var minimum = Number(vehicle.current_odometer_km || 0)
        if (!Number.isFinite(value) || value < minimum) {
          error.hidden = false
          error.textContent = 'Stav kilometrů nesmí být nižší než poslední evidovaný stav ' + minimum.toLocaleString('cs-CZ') + ' km.'
          return
        }
        startOdometer = Math.round(value)
        vehicleConfirmed = true
        localStorage.setItem(vehicleKey(), JSON.stringify({ confirmed: true, odometer: startOdometer, confirmedAt: new Date().toISOString() }))
        hidePanel()
        renderData()
      })
      body.appendChild(button)
    })
  }

  function setBusy(active, label) {
    root.querySelector('#ot-busy-label').textContent = label || 'Ukládám…'
    root.querySelector('#ot-busy').hidden = !active
  }

  function acknowledgeInstruction() {
    if (!instruction || instruction.requires_acknowledgement === false) return Promise.resolve()
    if (isShiftPreview()) return Promise.resolve()
    return apiRequest(supabaseUrl + '/rest/v1/instruction_acknowledgements?on_conflict=instruction_id,employee_id', {
      method: 'POST',
      headers: { 'Prefer': 'resolution=merge-duplicates,return=minimal' },
      body: JSON.stringify({ instruction_id: instruction.id, employee_id: employee.id, acknowledged_at: new Date().toISOString() })
    }, 10000)
  }

  function startShift() {
    if (isShiftRunning()) {
      window.location.href = './trasa.html'
      return
    }
    if (!routePlan || !vehicle || !vehicleConfirmed || (instruction && !instructionConfirmed)) {
      updateReadiness()
      return
    }
    setBusy(true, 'Zahajuji směnu…')
    var startedAt = new Date().toISOString()
    var attendancePayload = {
      employee_id: employee.id,
      attendance_date: todayIso(),
      status: 'open',
      actual_start: attendanceDay && attendanceDay.actual_start || startedAt,
      vehicle_id: vehicle.id,
      start_warehouse_id: vehicle.warehouse_id || null
    }
    apiRequest(supabaseUrl + '/rest/v1/attendance_days?on_conflict=employee_id,attendance_date', {
      method: 'POST',
      headers: { 'Prefer': 'resolution=merge-duplicates,return=representation' },
      body: JSON.stringify(attendancePayload)
    }, 12000).then(function (rows) {
      attendanceDay = Array.isArray(rows) ? rows[0] : rows
      if (!attendanceDay || !attendanceDay.id) throw new Error('Směna se nepodařila založit.')
      return apiRequest(supabaseUrl + '/rest/v1/attendance_events', {
        method: 'POST',
        headers: { 'Prefer': 'return=minimal' },
        body: JSON.stringify({ attendance_day_id: attendanceDay.id, employee_id: employee.id, event_type: 'shift_start', event_time: startedAt, note: 'Vozidlo ' + (vehicle.plate || vehicle.id) + ', km ' + startOdometer, created_by: employee.id })
      }, 12000).then(function () {
        if (vehicleLog && vehicleLog.id) return null
        return apiRequest(supabaseUrl + '/rest/v1/vehicle_operation_logs', {
          method: 'POST',
          headers: { 'Prefer': 'return=representation' },
          body: JSON.stringify({ vehicle_id: vehicle.id, employee_id: employee.id, attendance_day_id: attendanceDay.id, log_date: todayIso(), started_at: startedAt, start_odometer_km: startOdometer, status: 'open' })
        }, 12000)
      })
    }).then(function () {
      return apiRequest(supabaseUrl + '/rest/v1/route_plans?id=eq.' + encodeURIComponent(routePlan.id), {
        method: 'PATCH',
        headers: { 'Prefer': 'return=minimal' },
        body: JSON.stringify({ execution_status: 'in_progress', started_at: routePlan.started_at || startedAt })
      }, 12000)
    }).then(function () {
      window.location.href = './trasa.html'
    }).catch(function (error) {
      setBusy(false)
      window.alert(error && error.message ? error.message : 'Směnu se nepodařilo zahájit.')
    })
  }

  function bindInteractions() {
    var overlay = root.querySelector('#ot-overlay')
    root.querySelector('#ot-route').addEventListener('click', openRoutePanel)
    root.querySelector('#ot-vehicle').addEventListener('click', openVehiclePanel)
    root.querySelector('#ot-profile').addEventListener('click', function () { window.location.href = './profil.html' })
    root.querySelector('#ot-instructions').addEventListener('click', function () {
      if (instruction && !instructionConfirmed) overlay.hidden = false
      else window.location.href = './pokyny.html'
    })
    root.querySelector('#ot-close').addEventListener('click', function () { overlay.hidden = true })
    root.querySelector('#ot-confirm').addEventListener('click', function () {
      var button = root.querySelector('#ot-confirm')
      button.disabled = true
      button.textContent = 'Ukládám potvrzení…'
      acknowledgeInstruction().then(function () {
        overlay.hidden = true
        setConfirmed(true)
      }).catch(function (error) {
        window.alert(error && error.message ? error.message : 'Potvrzení se nepodařilo uložit.')
      }).then(function () {
        button.disabled = false
        button.textContent = 'Přečetl jsem a potvrzuji'
      })
    })
    root.querySelector('#ot-panel-close').addEventListener('click', hidePanel)
    root.querySelector('.ot-refresh').addEventListener('click', function () { window.location.reload() })
    root.querySelector('#ot-start').addEventListener('click', startShift)
  }

  bindInteractions()
  installIcons()
  root.querySelector('.ot-mark').innerHTML = '<img src="./icon-192.png" alt="">'

  window.operatorApprovedHomeStart = function (activeSession, activeEmployee) {
    session = activeSession
    employee = activeEmployee || {}
    if (!employee.id) {
      root.querySelector('.ot-state').innerHTML = 'Profil zaměstnance se nepodařilo načíst · <b>obnovte přihlášení</b>'
      return
    }
    Promise.all([loadRoute(), loadInstruction(), loadAttendance()]).then(function (results) {
      routePlan = results[0]
      instruction = results[1]
      attendanceDay = results[2]
      var resolvedVehicleId = attendanceDay && attendanceDay.vehicle_id || routePlan && routePlan.vehicle_id
      return Promise.all([loadVehicle(resolvedVehicleId), loadInstructionAcknowledgement()])
    }).then(function (results) {
      vehicle = results[0]
      instructionConfirmed = results[1]
      return loadVehicleLog()
    }).then(function (loadedVehicleLog) {
      vehicleLog = loadedVehicleLog
      readVehicleConfirmation()
      renderData()
    }).catch(function (error) {
      root.querySelector('.ot-state').innerHTML = 'Data směny se nepodařilo načíst · <b>' + String(error.message || 'zkuste obnovit') + '</b>'
      updateReadiness()
    })
  }

  if (isShiftPreview()) {
    employee = { id: 'preview-michal', name: 'Michal', surname: 'Punčochář', role: 'operator' }
    routePlan = { id: 200, title: '[TEST] HANÁK NÁBYTEK Kojetín', vehicle_id: 6, execution_status: 'assigned', estimated_distance_km: 76.4, route_plan_stops: [
      { id: 2504, stop_order: 1, title: 'EV 23 · Luce Snack X', address_snapshot: 'Popůvky 72', city_snapshot: 'Kojetín' },
      { id: 2505, stop_order: 2, title: 'EV 29 · Luce X2 I/E jídelna', address_snapshot: 'Popůvky 72', city_snapshot: 'Kojetín' }
    ] }
    vehicle = { id: 6, name: 'Fiat Doblò Cargo', plate: '3BU9736', current_odometer_km: 317658, warehouse_id: 1 }
    instruction = { id: 'preview-instruction', title: 'Kontrola vozidla před výjezdem', message: 'Před zahájením směny zkontroluj stav vozidla, povinnou výbavu a bezpečné uložení nákladu.', requires_acknowledgement: true }
    attendanceDay = null
    vehicleLog = null
    instructionConfirmed = false
    vehicleConfirmed = false
    startOdometer = null
    renderData()
  }
})()
