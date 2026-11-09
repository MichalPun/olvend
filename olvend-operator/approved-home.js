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
  var instructionConfirmed = false

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

  function requestJson(url, timeoutMs) {
    var controller = typeof AbortController === 'function' ? new AbortController() : null
    var timer
    var timeout = new Promise(function (_, reject) {
      timer = window.setTimeout(function () {
        if (controller) controller.abort()
        reject(new Error('Načítání úvodní obrazovky trvalo příliš dlouho.'))
      }, timeoutMs)
    })
    var request = fetch(url, {
      headers: {
        'apikey': supabaseKey,
        'Authorization': 'Bearer ' + session.access_token,
        'Content-Type': 'application/json'
      },
      signal: controller ? controller.signal : undefined
    })
    return Promise.race([request, timeout]).then(function (response) {
      window.clearTimeout(timer)
      if (!response.ok) throw new Error('Data směny se nepodařilo načíst (HTTP ' + response.status + ').')
      return response.json()
    }, function (error) {
      window.clearTimeout(timer)
      throw error
    })
  }

  function loadRoute() {
    var select = 'id,planning_date,title,vehicle_id,execution_status,estimated_distance_km,route_plan_stops(id,stop_order,status)'
    var url = supabaseUrl + '/rest/v1/route_plans?select=' + encodeURIComponent(select)
      + '&planned_employee_id=eq.' + encodeURIComponent(employee.id)
      + '&planning_date=eq.' + encodeURIComponent(todayIso())
      + '&execution_status=neq.cancelled&order=created_at.desc&limit=1'
    return requestJson(url, 12000).then(function (rows) { return Array.isArray(rows) && rows.length ? rows[0] : null })
  }

  function loadVehicle(vehicleId) {
    if (!vehicleId) return Promise.resolve(null)
    var url = supabaseUrl + '/rest/v1/vehicles?select=' + encodeURIComponent('id,name,plate,current_odometer_km')
      + '&id=eq.' + encodeURIComponent(vehicleId) + '&limit=1'
    return requestJson(url, 8000).then(function (rows) { return Array.isArray(rows) && rows.length ? rows[0] : null }).catch(function () { return null })
  }

  function loadInstruction() {
    var url = supabaseUrl + '/rest/v1/daily_instructions?select=*&is_active=eq.true&order=created_at.desc&limit=20'
    return requestJson(url, 9000).then(function (rows) {
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

  function setConfirmed(confirmed) {
    instructionConfirmed = confirmed
    var instructions = root.querySelector('#ot-instructions')
    var required = root.querySelector('#ot-required')
    var stateLabel = root.querySelector('#ot-instruction-state')
    instructions.classList.toggle('pending', Boolean(instruction) && !confirmed)
    required.classList.toggle('confirmed', !instruction || confirmed)
    required.textContent = !instruction ? 'Bez pokynu' : confirmed ? 'Potvrzeno' : 'Povinné'
    stateLabel.textContent = !instruction ? 'Dnes není nový povinný pokyn' : confirmed ? 'Všechny pokyny potvrzeny' : '1 pokyn čeká na potvrzení'
    updateReadiness()
  }

  function updateReadiness() {
    var start = root.querySelector('#ot-start')
    var help = root.querySelector('#ot-start-help')
    var ready = Boolean(routePlan && vehicle && (!instruction || instructionConfirmed))
    start.disabled = !ready
    if (ready) {
      start.innerHTML = 'Zahájit směnu <span data-lucide="arrow-right" aria-hidden="true"></span>'
      help.hidden = true
    } else {
      var reason = instruction && !instructionConfirmed ? 'Nejprve potvrďte pokyn' : !routePlan ? 'Čeká na dnešní trasu' : 'Nejprve potvrďte vozidlo'
      start.innerHTML = '<span data-lucide="lock-keyhole" aria-hidden="true"></span><span>' + reason + '</span>'
      help.hidden = false
      help.textContent = instruction && !instructionConfirmed ? 'Směnu lze zahájit až po potvrzení všech povinných pokynů.' : !routePlan ? 'Vedoucí zatím nepřiřadil dnešní trasu.' : 'Před zahájením směny zkontrolujte přidělené vozidlo.'
    }
    installIcons()
    var state = root.querySelector('.ot-state')
    state.innerHTML = ready ? 'Směna ještě nebyla zahájena · <b>vše je připravené</b>' : 'Směna ještě nebyla zahájena · <b>čeká povinný krok</b>'
  }

  function renderData() {
    var firstName = String(employee.name || '').trim()
    root.querySelector('.ot-date').textContent = formatDateLong()
    root.querySelector('.ot-main h2').textContent = (new Date().getHours() < 12 ? 'Dobré ráno' : 'Dobrý den') + (firstName ? ', ' + firstName : '')
    root.querySelector('.ot-tile.profile strong').textContent = [employee.name, employee.surname].filter(Boolean).join(' ') || 'Můj profil'

    var routeTile = root.querySelector('.ot-tile.route')
    var stops = routePlan && Array.isArray(routePlan.route_plan_stops) ? routePlan.route_plan_stops.length : 0
    routeTile.querySelector('p').textContent = routePlan ? (routePlan.title || 'Dnešní trasa') : 'Trasa zatím nepřiřazena'
    routeTile.querySelector('strong').textContent = routePlan ? stops + ' zastávek · ' + (Number(routePlan.estimated_distance_km || 0) ? Number(routePlan.estimated_distance_km).toLocaleString('cs-CZ', { maximumFractionDigits: 1 }) + ' km' : 'vzdálenost se načítá') : 'Čeká na plán'

    var vehicleTile = root.querySelector('.ot-tile.vehicle')
    vehicleTile.querySelector('p').textContent = vehicle ? (vehicle.name || 'Přiřazené vozidlo') : 'Vozidlo zatím není přiřazeno'
    vehicleTile.querySelector('strong').textContent = vehicle ? (vehicle.plate || 'Bez RZ') : 'Nevybráno'
    root.querySelector('.ot-brand-copy span').textContent = vehicle ? 'Před směnou · ' + (vehicle.plate || vehicle.name || 'vozidlo') : 'Před zahájením směny'

    if (instruction) {
      root.querySelector('.ot-sheet-title h3').textContent = instruction.title || instruction.name || 'Povinný pokyn dne'
      root.querySelector('.ot-instruction').textContent = instruction.body || instruction.content || instruction.message || instruction.note || 'Přečtěte si pokyn a potvrďte jeho převzetí.'
    }
    var key = instruction ? 'olvendOperatorInstruction:' + instruction.id + ':' + todayIso() : ''
    setConfirmed(!instruction || localStorage.getItem(key) === 'confirmed')
  }

  function bindInteractions() {
    var overlay = root.querySelector('#ot-overlay')
    root.querySelector('#ot-instructions').addEventListener('click', function () {
      if (!instruction) return
      overlay.hidden = false
    })
    root.querySelector('#ot-close').addEventListener('click', function () { overlay.hidden = true })
    root.querySelector('#ot-confirm').addEventListener('click', function () {
      overlay.hidden = true
      if (instruction) localStorage.setItem('olvendOperatorInstruction:' + instruction.id + ':' + todayIso(), 'confirmed')
      setConfirmed(true)
    })
    root.querySelector('.ot-refresh').addEventListener('click', function () { window.location.reload() })
  }

  bindInteractions()
  installIcons()
  var mark = root.querySelector('.ot-mark')
  mark.innerHTML = '<img src="./icon-192.png" alt="">'

  window.operatorApprovedHomeStart = function (activeSession, activeEmployee) {
    session = activeSession
    employee = activeEmployee || {}
    if (!employee.id) {
      root.querySelector('.ot-state').innerHTML = 'Profil zaměstnance se nepodařilo načíst · <b>obnovte přihlášení</b>'
      return
    }
    Promise.all([loadRoute(), loadInstruction()]).then(function (results) {
      routePlan = results[0]
      instruction = results[1]
      return loadVehicle(routePlan && routePlan.vehicle_id)
    }).then(function (loadedVehicle) {
      vehicle = loadedVehicle
      renderData()
    }).catch(function (error) {
      root.querySelector('.ot-state').innerHTML = 'Data směny se nepodařilo načíst · <b>' + String(error.message || 'zkuste obnovit') + '</b>'
      updateReadiness()
    })
  }
})()
