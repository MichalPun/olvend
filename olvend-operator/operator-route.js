(function () {
  'use strict'

  var supabaseUrl = 'https://rerjlkrhiytgscjerqgs.supabase.co'
  var supabaseKey = 'sb_publishable_A8OxCcapdNXAzQLjLsW5iA_XtGvBZ0S'
  var root = document.getElementById('operator-route')
  var preview = location.hostname === '127.0.0.1' && new URLSearchParams(location.search).get('preview') === 'route197'
  var session = null
  var employee = null
  var plan = null
  var vehicle = null
  var visits = []
  var groups = []
  var activeGroup = null
  var toastTimer = null

  var icons = {
    car: '<path d="M5 17h14v-5l-2-5H7l-2 5v5Z"/><path d="M7 17v2M17 17v2M5 12h14"/><circle cx="8" cy="15" r="1"/><circle cx="16" cy="15" r="1"/>',
    box: '<path d="m4 7 8-4 8 4-8 4-8-4Z"/><path d="M4 7v10l8 4 8-4V7M12 11v10"/>',
    route: '<circle cx="6" cy="19" r="3"/><path d="M9 19h6.5a3.5 3.5 0 0 0 0-7h-8a3.5 3.5 0 0 1 0-7H15"/><circle cx="18" cy="5" r="3"/>',
    navigation: '<path d="m3 11 19-9-9 19-2-8-8-2Z"/>',
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    pin: '<path d="M20 10c0 5-8 11-8 11S4 15 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="2.5"/>',
    store: '<path d="M4 10v10h16V10M3 10l2-6h14l2 6"/><path d="M8 20v-6h5v6M3 10c0 2 3 2 3 0 0 2 3 2 3 0 0 2 3 2 3 0 0 2 3 2 3 0 0 2 3 2 3 0"/>',
    back: '<path d="m15 18-6-6 6-6"/>',
    machines: '<rect x="4" y="3" width="16" height="18" rx="2"/><path d="M8 7h8M8 11h3M8 16h8"/>',
    coffee: '<path d="M5 8h11v5a5 5 0 0 1-5 5H10a5 5 0 0 1-5-5V8Z"/><path d="M16 10h1a3 3 0 0 1 0 6h-2M8 3v2m4-2v2"/>',
    snack: '<rect x="5" y="3" width="14" height="18" rx="2"/><path d="M8 7h8M8 11h8M8 15h5M15 15h1"/>',
    info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/>',
    check: '<path d="m5 12 4 4L19 6"/>'
  }

  function svg(name) {
    return '<svg viewBox="0 0 24 24" aria-hidden="true">' + (icons[name] || icons.pin) + '</svg>'
  }

  function hydrateIcons(scope) {
    Array.prototype.forEach.call((scope || document).querySelectorAll('[data-icon]'), function (node) {
      node.innerHTML = svg(node.getAttribute('data-icon')) + node.innerHTML
    })
  }

  function todayIso() {
    try { return new Intl.DateTimeFormat('sv-SE', { timeZone: 'Europe/Prague' }).format(new Date()) }
    catch (_) { return new Date().toISOString().slice(0, 10) }
  }

  function formatClock(value) {
    if (!value) return 'čas se dopočítává'
    var date = new Date(value)
    if (Number.isNaN(date.getTime())) return String(value).slice(0, 5)
    return new Intl.DateTimeFormat('cs-CZ', { timeZone: 'Europe/Prague', hour: '2-digit', minute: '2-digit' }).format(date)
  }

  function formatKm(value) {
    var number = Number(value || 0)
    if (!number) return '— km'
    return number.toLocaleString('cs-CZ', { maximumFractionDigits: 1 }) + ' km'
  }

  function machineCountLabel(count) {
    if (count === 1) return '1 automat'
    if (count > 1 && count < 5) return count + ' automaty'
    return count + ' automatů'
  }

  function visitFor(stop) {
    return visits.find(function (visit) { return String(visit.route_plan_stop_id) === String(stop.id) }) || null
  }

  function stopStatus(stop) {
    var visit = visitFor(stop)
    return String(visit && visit.status || stop.status || 'planned').toLowerCase()
  }

  function isClosed(stop) {
    return ['done', 'completed', 'skipped'].indexOf(stopStatus(stop)) !== -1
  }

  function isArrived(stop) {
    return Boolean(stop && stop.arrived_at) || ['arrived', 'in_progress', 'started'].indexOf(stopStatus(stop)) !== -1
  }

  function requestJson(path, options) {
    var requestOptions = Object.assign({}, options || {})
    requestOptions.headers = Object.assign({
      apikey: supabaseKey,
      Authorization: 'Bearer ' + session.access_token,
      'Content-Type': 'application/json'
    }, requestOptions.headers || {})
    return fetch(path.indexOf('http') === 0 ? path : supabaseUrl + path, requestOptions).then(function (response) {
      if (!response.ok) return response.text().then(function (text) { throw new Error(text || 'Data trasy se nepodařilo načíst.') })
      if (response.status === 204) return null
      return response.json()
    })
  }

  function fixture() {
    plan = {
      id: 197,
      title: 'Trasa 2026-11-10 · Veronika Jirdová',
      execution_status: 'in_progress',
      started_at: '2026-11-10T04:37:58.753Z',
      estimated_distance_km: 432.05,
      route_payload: { mobile_recalculation: { estimated_return_at: '2026-11-10T15:04:01.112Z' } },
      route_plan_stops: [
        previewStop(2467,1,'done',52,'REMANTE GROUP s.r.o.','K Rybníčkům 13','Otice',6,'Europa Snack','Snack'),
        previewStop(2468,2,'done',52,'REMANTE GROUP s.r.o.','K Rybníčkům 13','Otice',87,'Luce X2 I/E','Coffee'),
        previewStop(2469,3,'done',120,'OU a PrŠ Hlučín','Čs. armády 336/4a','Hlučín',130,'Bianchi Vitality L','Snack'),
        previewStop(2470,4,'done',58,'Sportisimo','Žižkova','Slezská Ostrava-Hrušov',99,'FAS 1050','Snack'),
        previewStop(2471,5,'done',58,'Sportisimo','Žižkova','Slezská Ostrava-Hrušov',98,'Luce X2 I','Coffee'),
        previewStop(2473,6,'done',58,'Sportisimo','Žižkova','Slezská Ostrava-Hrušov',90,'Saphirh 10','Snack'),
        previewStop(2472,7,'done',58,'Sportisimo','Žižkova','Slezská Ostrava-Hrušov',89,'Luce X2 I/E','Coffee'),
        previewStop(2474,8,'done',107,'Soukromá střední odborná škola Frýdek-Místek','tř. T. G. Masaryka 456','Frýdek-Místek',84,'Europa Snack','Snack'),
        previewStop(2475,9,'done',107,'Soukromá střední odborná škola Frýdek-Místek','tř. T. G. Masaryka 456','Frýdek-Místek',97,'Luce X2 I','Coffee'),
        previewStop(2476,10,'planned',111,'HANÁK NÁBYTEK Kojetín','Popůvky 72','Kojetín',23,'Luce Snack X','Snack','2026-11-10T12:59:49.112Z',183.8),
        previewStop(2477,11,'planned',111,'HANÁK NÁBYTEK Kojetín','Popůvky 72','Kojetín',29,'Luce X2 I/E jídelna','Coffee','2026-11-10T13:19:49.112Z',0),
        previewStop(2478,12,'planned',111,'HANÁK NÁBYTEK Kojetín','Popůvky 72','Kojetín',27,'Luce X2 I/E kuchyňka','Coffee','2026-11-10T13:39:49.112Z',0)
      ]
    }
    vehicle = { id: 1, name: 'Renault Kangoo', plate: '2TX7928', current_odometer_km: 130700 }
    employee = { name: 'Veronika', surname: 'Jirdová' }
    visits = []
  }

  function previewStop(id, order, status, locationId, locationName, address, city, evidence, machine, type, arrival, distance) {
    return { id: id, stop_order: order, status: status, location_id: locationId, machine_id: evidence, title: machine, address_snapshot: address, city_snapshot: city, latitude: 49.2, longitude: 17.3, view: { locationName: locationName, machineName: machine, machineType: type, evidenceNumber: evidence, arrivalAt: arrival || null, distanceKm: distance == null ? null : distance } }
  }

  function payloadStops() {
    var payload = plan && plan.route_payload || {}
    return payload.google && Array.isArray(payload.google.orderedStops) ? payload.google.orderedStops : []
  }

  function enrichStops() {
    var payloadRows = payloadStops()
    var schedule = plan && plan.route_payload && plan.route_payload.mobile_recalculation && plan.route_payload.mobile_recalculation.stop_schedule || []
    var scheduleMap = new Map(schedule.map(function (row) { return [String(row.stop_id), row] }))
    ;(plan.route_plan_stops || []).forEach(function (stop) {
      if (stop.view) return
      var payload = payloadRows.find(function (row) { return String(row.machineId) === String(stop.machine_id) }) || {}
      var machine = stop.machineRecord || {}
      var timing = scheduleMap.get(String(stop.id)) || {}
      stop.view = {
        locationName: payload.parentLocationName || stop.location_name || stop.city_snapshot || stop.title || 'Zastávka',
        machineName: payload.machineLabel || payload.name || machine.name || stop.title || 'Automat',
        machineType: payload.machineType || machine.machine_type || 'Automat',
        evidenceNumber: payload.evidenceNumber || machine.evidence_number || null,
        arrivalAt: timing.arrival_at || payload.estimatedArrivalAt || null,
        distanceKm: payload.distanceFromPreviousKm == null ? null : Number(payload.distanceFromPreviousKm)
      }
    })
  }

  function buildGroups() {
    enrichStops()
    var ordered = (plan.route_plan_stops || []).slice().sort(function (a, b) { return Number(a.stop_order || 0) - Number(b.stop_order || 0) })
    var byKey = new Map()
    groups = []
    ordered.forEach(function (stop) {
      var key = stop.location_id ? 'location:' + stop.location_id : 'address:' + [stop.address_snapshot, stop.city_snapshot].join('|')
      var group = byKey.get(key)
      if (!group) {
        group = { key: key, order: groups.length + 1, name: stop.view.locationName, address: [stop.address_snapshot, stop.city_snapshot].filter(Boolean).join(', '), latitude: stop.latitude, longitude: stop.longitude, stops: [], arrivalAt: stop.view.arrivalAt, distanceKm: stop.view.distanceKm }
        byKey.set(key, group)
        groups.push(group)
      }
      group.stops.push(stop)
      if (!group.arrivalAt && stop.view.arrivalAt) group.arrivalAt = stop.view.arrivalAt
      if (group.distanceKm == null && stop.view.distanceKm != null) group.distanceKm = stop.view.distanceKm
    })
    if (groups.length === 1 && groups[0].distanceKm == null && plan.estimated_distance_km != null) {
      groups[0].distanceKm = Number(plan.estimated_distance_km)
    }
    groups.forEach(function (group) {
      group.closed = group.stops.every(isClosed)
      group.arrived = !group.closed && group.stops.some(isArrived)
      group.skipped = group.stops.every(function (stop) { return stopStatus(stop) === 'skipped' })
    })
  }

  function currentGroup() {
    return groups.find(function (group) { return !group.closed }) || null
  }

  function groupMachineSummary(group) {
    var coffee = group.stops.filter(function (stop) { return /coffee|ká|kav/i.test(stop.view.machineType) }).length
    var food = group.stops.length - coffee
    var parts = []
    if (coffee) parts.push(coffee + (coffee === 1 ? ' kávový automat' : coffee < 5 ? ' kávové automaty' : ' kávových automatů'))
    if (food) parts.push(food + (food === 1 ? ' potravinový automat' : food < 5 ? ' potravinové automaty' : ' potravinových automatů'))
    return parts.join(' · ') || machineCountLabel(group.stops.length)
  }

  function routeEnd() {
    return plan && plan.route_payload && plan.route_payload.mobile_recalculation && plan.route_payload.mobile_recalculation.estimated_return_at || null
  }

  function showToast(message, error) {
    var toast = root.querySelector('#or-toast')
    window.clearTimeout(toastTimer)
    toast.textContent = message
    toast.className = 'or-toast' + (error ? ' error' : '')
    toast.hidden = false
    toastTimer = window.setTimeout(function () { toast.hidden = true }, 3400)
  }

  function renderOverview() {
    buildGroups()
    var completedGroups = groups.filter(function (group) { return group.closed }).length
    var completedMachines = (plan.route_plan_stops || []).filter(isClosed).length
    var remaining = Math.max(0, groups.length - completedGroups)
    var percent = groups.length ? Math.round(completedGroups / groups.length * 100) : 0
    var next = currentGroup()
    var routeDone = groups.length > 0 && !next
    var state = root.querySelector('#or-route-state')
    state.textContent = routeDone ? 'Trasa hotová' : plan.execution_status === 'in_progress' ? 'Směna běží' : 'Připravená'
    state.className = 'or-state' + (plan.execution_status === 'in_progress' || routeDone ? '' : ' waiting')
    root.querySelector('#or-header-state').textContent = (plan.execution_status === 'in_progress' ? 'Aktivní směna' : 'Dnešní trasa') + (vehicle ? ' · ' + (vehicle.plate || vehicle.name) : '')
    root.querySelector('#or-started').textContent = plan.started_at ? 'Začátek směny v ' + formatClock(plan.started_at) : 'Trasa čeká na zahájení směny'
    root.querySelector('#or-progress-label').textContent = completedGroups + ' z ' + groups.length + ' fyzických zastávek hotovo'
    root.querySelector('#or-progress-meta').textContent = completedMachines + ' z ' + (plan.route_plan_stops || []).length + ' automatů · ' + formatKm(plan.estimated_distance_km) + (routeEnd() ? ' · návrat ' + formatClock(routeEnd()) : '')
    root.querySelector('#or-remaining').textContent = remaining ? remaining + ' zbývá' : 'hotovo'
    root.querySelector('#or-progress-bar').style.width = percent + '%'
    root.querySelector('#or-vehicle [data-tile-copy]').textContent = vehicle ? [vehicle.plate, Number(vehicle.current_odometer_km || 0).toLocaleString('cs-CZ') + ' km'].filter(Boolean).join(' · ') : 'Vozidlo není přiřazené'
    root.querySelector('#or-route-list [data-tile-copy]').textContent = groups.length + ' lokalit · ' + (plan.route_plan_stops || []).length + ' automatů'
    renderNext(next, routeDone)
  }

  function renderNext(group, routeDone) {
    var article = root.querySelector('#or-next')
    article.innerHTML = ''
    if (!group) {
      article.innerHTML = '<div class="or-label"><span>Dnešní trasa</span><b>Dokončeno</b></div><div class="or-place"><i class="or-icon">' + svg('check') + '</i><div><strong>Všechny zastávky jsou hotové</strong><span>' + (routeDone ? 'Můžeš se vrátit na sklad a uzavřít dnešní trasu.' : 'Trasa nemá žádnou zastávku.') + '</span></div></div>'
      return
    }
    var label = document.createElement('div'); label.className = 'or-label'; label.innerHTML = '<span>' + (group.arrived ? 'Aktuální zastávka' : 'Další zastávka') + '</span><b>' + group.order + ' z ' + groups.length + '</b>'
    var place = document.createElement('div'); place.className = 'or-place'; place.innerHTML = '<i class="or-icon">' + svg('pin') + '</i><div><strong></strong><span></span></div>'; place.querySelector('strong').textContent = group.name; place.querySelector('span').textContent = group.address || 'Adresa není uvedena'
    var info = document.createElement('div'); info.className = 'or-stop-info'; info.innerHTML = '<div class="or-meta">' + svg('navigation') + '<span>' + (group.distanceKm == null ? 'Vzdálenost se načítá' : formatKm(group.distanceKm) + ' k zastávce') + '</span></div><div class="or-meta">' + svg('clock') + '<span>Příjezd ' + formatClock(group.arrivalAt) + '</span></div>'
    var machines = document.createElement('div'); machines.className = 'or-machines'; machines.innerHTML = svg('machines') + '<span></span>'; machines.querySelector('span').textContent = groupMachineSummary(group)
    var actions = document.createElement('div'); actions.className = 'or-actions-row'
    var navigation = document.createElement('button'); navigation.type = 'button'; navigation.className = 'or-navigate'; navigation.innerHTML = svg('navigation') + '<span>Navigovat</span>'; navigation.addEventListener('click', function () { navigateTo(group) })
    var open = document.createElement('button'); open.type = 'button'; open.className = 'or-open'; open.textContent = group.arrived ? 'Pokračovat na zastávce' : 'Otevřít zastávku'; open.addEventListener('click', function () { openGroup(group) })
    actions.appendChild(navigation); actions.appendChild(open); article.appendChild(label); article.appendChild(place); article.appendChild(info); article.appendChild(machines); article.appendChild(actions)
  }

  function openGroup(group) {
    activeGroup = group
    root.querySelector('#or-route-view').hidden = true
    root.querySelector('#or-stop-view').hidden = false
    root.querySelector('#or-stop-title').textContent = 'Zastávka'
    root.querySelector('#or-stop-subtitle').textContent = group.name
    root.querySelector('#or-stop-position').textContent = group.order + ' z ' + groups.length
    root.querySelector('#or-stop-place-name').textContent = group.name
    root.querySelector('#or-stop-address').textContent = group.address || 'Adresa není uvedena'
    root.querySelector('#or-stop-status').textContent = group.closed ? 'Hotovo' : group.arrived ? 'Návštěva probíhá' : 'Na místě'
    root.querySelector('#or-stop-arrival').textContent = (group.arrived ? 'Zahájeno' : 'Plánovaný příjezd') + ' · ' + formatClock(group.arrivalAt)
    root.querySelector('#or-stop-distance').textContent = group.distanceKm == null ? 'Navigace připravena' : formatKm(group.distanceKm) + ' k lokalitě'
    root.querySelector('#or-machine-count').textContent = machineCountLabel(group.stops.length)
    renderMachines(group)
    var start = root.querySelector('#or-start-visit')
    start.textContent = group.closed ? 'Zastávka je hotová' : group.arrived ? 'Návštěva zahájena' : 'Zahájit návštěvu'
    start.disabled = group.closed || group.arrived
    root.querySelector('#or-stop-navigate').disabled = group.closed
    window.scrollTo(0, 0)
  }

  function renderMachines(group) {
    var list = root.querySelector('#or-machine-list')
    list.innerHTML = ''
    group.stops.forEach(function (stop) {
      var status = stopStatus(stop)
      var done = ['done', 'completed'].indexOf(status) !== -1
      var skipped = status === 'skipped'
      var active = !done && !skipped && (group.arrived || isArrived(stop))
      var row = document.createElement('button'); row.type = 'button'; row.className = 'or-machine' + (done || skipped ? ' done' : active ? ' active' : '')
      row.innerHTML = '<i class="or-machine-icon">' + svg(/coffee|ká|kav/i.test(stop.view.machineType) ? 'coffee' : 'snack') + '</i><div><strong></strong><span></span></div><b></b>'
      row.querySelector('strong').textContent = (stop.view.evidenceNumber ? 'EV ' + stop.view.evidenceNumber + ' · ' : '') + stop.view.machineName
      row.querySelector('span').textContent = /coffee|ká|kav/i.test(stop.view.machineType) ? 'Kávový automat' : 'Potravinový automat'
      row.querySelector('b').textContent = done ? 'Hotovo' : skipped ? 'Nejeto' : active ? 'Otevřít ›' : 'Čeká'
      row.disabled = !active
      row.addEventListener('click', function () {
        var isCoffee = /coffee|ká|kav/i.test(stop.view.machineType)
        if (!preview) {
          if (isCoffee) {
            var coffeeParams = new URLSearchParams({
              live: '1',
              stop_id: String(stop.id),
              ev: String(stop.view.evidenceNumber || stop.machine_id || ''),
              machine: String(stop.view.machineName || stop.title || 'Kávový automat'),
              location: String(group.name || '')
            })
            window.location.href = './index.html?' + coffeeParams.toString()
            return
          }
          var liveParams = new URLSearchParams({
            live: '1',
            stop_id: String(stop.id),
            ev: String(stop.view.evidenceNumber || stop.machine_id || ''),
            machine: String(stop.view.machineName || stop.title || 'Potravinový automat'),
            location: String(group.name || '')
          })
          window.location.href = './potravinovy-automat-preview.html?' + liveParams.toString()
          return
        }
        if (isCoffee) {
          var previewCoffeeParams = new URLSearchParams({
            preview: 'route197',
            ev: String(stop.view.evidenceNumber || stop.machine_id || ''),
            machine: String(stop.view.machineName || stop.title || 'Kávový automat'),
            location: String(group.name || '')
          })
          window.location.href = './index.html?' + previewCoffeeParams.toString()
          return
        }
        var params = new URLSearchParams({
          ev: String(stop.view.evidenceNumber || stop.machine_id || ''),
          machine: String(stop.view.machineName || stop.title || 'Potravinový automat'),
          location: String(group.name || '')
        })
        if (preview) params.set('preview', 'route197')
        window.location.href = './potravinovy-automat-preview.html?' + params.toString()
      })
      list.appendChild(row)
    })
  }

  function closeGroup() {
    activeGroup = null
    root.querySelector('#or-stop-view').hidden = true
    root.querySelector('#or-route-view').hidden = false
    window.scrollTo(0, 0)
  }

  function startVisit() {
    if (!activeGroup || activeGroup.closed || activeGroup.arrived) return
    var button = root.querySelector('#or-start-visit')
    button.disabled = true
    button.textContent = 'Ukládám příjezd…'
    var now = new Date().toISOString()
    var openStops = activeGroup.stops.filter(function (stop) { return !isClosed(stop) })
    var save = preview ? Promise.resolve() : Promise.all(openStops.map(function (stop) {
      return requestJson('/rest/v1/route_plan_stops?id=eq.' + encodeURIComponent(stop.id), { method: 'PATCH', headers: { Prefer: 'return=minimal' }, body: JSON.stringify({ arrived_at: now }) })
    }))
    save.then(function () {
      openStops.forEach(function (stop) { stop.arrived_at = now })
      buildGroups()
      activeGroup = groups.find(function (group) { return group.key === activeGroup.key }) || activeGroup
      renderOverview(); openGroup(activeGroup); showToast('Návštěva byla zahájena. Můžeš otevřít konkrétní automat.')
    }).catch(function () {
      button.disabled = false; button.textContent = 'Zahájit návštěvu'; showToast('Příjezd se nepodařilo uložit. Zkus to znovu.', true)
    })
  }

  function navigateTo(group) {
    if (!group) return
    var destination = group.latitude != null && group.longitude != null ? group.latitude + ',' + group.longitude : [group.address, group.name].filter(Boolean).join(' ')
    if (!destination) return showToast('U zastávky chybí adresa i souřadnice.', true)
    if (preview) return showToast('Navigace je připravená pro ' + group.name + '.')
    window.location.href = 'https://www.google.com/maps/dir/?api=1&destination=' + encodeURIComponent(destination)
  }

  function showSheet(kicker, title) {
    root.querySelector('#or-sheet-kicker').textContent = kicker
    root.querySelector('#or-sheet-title').textContent = title
    root.querySelector('#or-sheet-body').innerHTML = ''
    root.querySelector('#or-overlay').hidden = false
    return root.querySelector('#or-sheet-body')
  }

  function openRouteList() {
    var body = showSheet('Dnešní trasa', groups.length + ' fyzických zastávek')
    var list = document.createElement('div'); list.className = 'or-list'
    var current = currentGroup()
    groups.forEach(function (group) {
      var row = document.createElement('button'); row.type = 'button'; row.className = 'or-row' + (group.closed ? ' done' : current && current.key === group.key ? ' current' : '')
      row.innerHTML = '<i class="or-row-icon">' + (group.closed ? svg('check') : group.order) + '</i><div><strong></strong><span></span></div><em>›</em>'
      row.querySelector('strong').textContent = group.name
      row.querySelector('span').textContent = group.address + ' · ' + machineCountLabel(group.stops.length) + (group.closed ? ' · hotovo' : group.arrived ? ' · rozpracováno' : '')
      row.addEventListener('click', function () { root.querySelector('#or-overlay').hidden = true; openGroup(group) })
      list.appendChild(row)
    })
    body.appendChild(list)
  }

  function load() {
    var select = 'id,title,vehicle_id,execution_status,estimated_distance_km,estimated_drive_minutes,estimated_service_minutes,started_at,completed_at,return_to_start,route_payload,route_plan_stops(id,stop_order,status,arrived_at,completed_at,skipped_at,title,address_snapshot,city_snapshot,latitude,longitude,machine_id,location_id,estimated_service_minutes)'
    var routePath = '/rest/v1/route_plans?select=' + encodeURIComponent(select) + '&planned_employee_id=eq.' + encodeURIComponent(employee.id) + '&planning_date=eq.' + encodeURIComponent(todayIso()) + '&execution_status=neq.cancelled&order=created_at.desc&limit=1'
    return requestJson(routePath).then(function (rows) {
      plan = Array.isArray(rows) && rows[0] || null
      if (!plan) throw new Error('Dnešní trasa není přiřazená.')
      var vehicleRequest = plan.vehicle_id ? requestJson('/rest/v1/vehicles?select=id,name,plate,current_odometer_km&id=eq.' + encodeURIComponent(plan.vehicle_id) + '&limit=1') : Promise.resolve([])
      var visitRequest = requestJson('/rest/v1/route_machine_visits?select=id,route_plan_stop_id,machine_id,status,arrived_at,completed_at,skipped_at&route_plan_id=eq.' + encodeURIComponent(plan.id)).catch(function () { return [] })
      var machineIds = Array.from(new Set((plan.route_plan_stops || []).map(function (stop) { return stop.machine_id }).filter(Boolean)))
      var machineRequest = machineIds.length
        ? requestJson('/rest/v1/machines?select=id,name,evidence_number,machine_type&id=in.(' + machineIds.map(encodeURIComponent).join(',') + ')')
        : Promise.resolve([])
      return Promise.all([vehicleRequest, visitRequest, machineRequest])
    }).then(function (results) {
      vehicle = Array.isArray(results[0]) && results[0][0] || null
      visits = Array.isArray(results[1]) ? results[1] : []
      var machinesById = new Map((Array.isArray(results[2]) ? results[2] : []).map(function (machine) { return [String(machine.id), machine] }))
      ;(plan.route_plan_stops || []).forEach(function (stop) { stop.machineRecord = machinesById.get(String(stop.machine_id)) || null })
      renderOverview()
    })
  }

  function showLoadError(error) {
    root.querySelector('#or-route-state').textContent = 'Bez trasy'
    root.querySelector('#or-route-state').className = 'or-state waiting'
    root.querySelector('#or-next').innerHTML = '<div class="or-loading"></div>'
    root.querySelector('#or-next .or-loading').textContent = error && error.message ? error.message : 'Trasu se nepodařilo načíst.'
  }

  function updateConnectivity() {
    var pill = root.querySelector('#or-connectivity')
    pill.textContent = navigator.onLine === false ? 'Offline' : 'Online'
    pill.className = 'or-online' + (navigator.onLine === false ? ' offline' : '')
  }

  hydrateIcons(document)
  updateConnectivity()
  window.addEventListener('online', updateConnectivity)
  window.addEventListener('offline', updateConnectivity)
  root.querySelector('#or-close').addEventListener('click', function () { root.querySelector('#or-overlay').hidden = true })
  root.querySelector('#or-overlay').addEventListener('click', function (event) { if (event.target === root.querySelector('#or-overlay')) root.querySelector('#or-overlay').hidden = true })
  root.querySelector('#or-route-list').addEventListener('click', openRouteList)
  root.querySelector('#or-vehicle').addEventListener('click', function () { location.href = './vozidlo.html' })
  root.querySelector('#or-stock').addEventListener('click', function () { showToast('Zásoby vozidla připojíme jako další obrazovku po schválení Trasy.') })
  root.querySelector('#or-back-route').addEventListener('click', closeGroup)
  root.querySelector('#or-stop-navigate').addEventListener('click', function () { navigateTo(activeGroup) })
  root.querySelector('#or-start-visit').addEventListener('click', startVisit)

  window.operatorRouteStart = function (activeSession, activeEmployee) {
    session = activeSession
    employee = activeEmployee || {}
    if (!employee.id) return
    load().catch(showLoadError)
  }

  if (preview) {
    document.body.classList.remove('auth-pending')
    document.getElementById('operatorAuthGate').hidden = true
    fixture()
    renderOverview()
  }
})()
