(function () {
  'use strict'

  var supabaseUrl = 'https://rerjlkrhiytgscjerqgs.supabase.co'
  var supabaseKey = 'sb_publishable_A8OxCcapdNXAzQLjLsW5iA_XtGvBZ0S'
  var session = null
  var employee = null
  var attendance = null
  var routePlan = null
  var vehicle = null
  var logs = []
  var requests = []
  var dailyCheck = null
  var activePhotoInput = null

  function headers(extra) {
    return Object.assign({ apikey: supabaseKey, Authorization: 'Bearer ' + session.access_token, 'Content-Type': 'application/json' }, extra || {})
  }

  function requestJson(path, options) {
    var opts = Object.assign({}, options || {})
    opts.headers = headers(opts.headers)
    return fetch(supabaseUrl + path, opts).then(function (response) {
      if (!response.ok) return response.text().then(function (text) {
        var message = ''
        try { message = JSON.parse(text).message || JSON.parse(text).details || '' } catch (_) {}
        throw new Error(message || 'Operaci se nepodařilo dokončit (HTTP ' + response.status + ').')
      })
      if (response.status === 204) return null
      return response.text().then(function (text) { return text ? JSON.parse(text) : null })
    })
  }

  function todayIso() {
    try { return new Intl.DateTimeFormat('sv-SE', { timeZone: 'Europe/Prague' }).format(new Date()) }
    catch (_) { return new Date().toISOString().slice(0, 10) }
  }

  function formatDate(value) {
    if (!value) return 'Neuvedeno'
    return new Date(String(value).slice(0, 10) + 'T12:00:00').toLocaleDateString('cs-CZ', { day: 'numeric', month: 'numeric', year: 'numeric' })
  }

  function formatDateTime(value) {
    if (!value) return 'Neuvedeno'
    return new Date(value).toLocaleString('cs-CZ', { day: 'numeric', month: 'numeric', hour: '2-digit', minute: '2-digit' })
  }

  function daysUntil(value) {
    if (!value) return null
    return Math.ceil((new Date(String(value).slice(0, 10) + 'T12:00:00').getTime() - new Date(todayIso() + 'T12:00:00').getTime()) / 86400000)
  }

  function escapeHtml(value) {
    return String(value == null ? '' : value).replace(/[&<>"']/g, function (char) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char] })
  }

  function setBusy(active, label) {
    document.getElementById('ov-busy-label').textContent = label || 'Ukládám…'
    document.getElementById('ov-busy').hidden = !active
  }

  function toast(message, error) {
    var item = document.getElementById('ov-toast')
    item.textContent = message
    item.style.background = error ? '#b42318' : '#18202a'
    item.hidden = false
    window.clearTimeout(toast.timer)
    toast.timer = window.setTimeout(function () { item.hidden = true }, 3500)
  }

  function closeSheet() {
    var button = document.querySelector('.ov-close')
    if (button) button.click()
  }

  function vehicleLabel() {
    return vehicle ? [vehicle.name, vehicle.plate].filter(Boolean).join(' · ') : 'Vozidlo'
  }

  function currentLog() {
    return logs.find(function (row) {
      return attendance && String(row.attendance_day_id || '') === String(attendance.id) && String(row.vehicle_id) === String(vehicle && vehicle.id) && row.status !== 'closed'
    }) || null
  }

  function localVehicleKey() {
    return 'olvendOperatorVehicle:' + todayIso() + ':' + employee.id + ':' + vehicle.id
  }

  function load() {
    var date = todayIso()
    var attendanceUrl = '/rest/v1/attendance_days?select=*&employee_id=eq.' + encodeURIComponent(employee.id) + '&attendance_date=eq.' + date + '&order=created_at.desc&limit=1'
    var routeFields = 'id,vehicle_id,title,execution_status,planning_date'
    var routeUrl = '/rest/v1/route_plans?select=' + encodeURIComponent(routeFields) + '&planned_employee_id=eq.' + encodeURIComponent(employee.id) + '&planning_date=eq.' + date + '&execution_status=neq.cancelled&order=created_at.desc&limit=1'
    return Promise.all([requestJson(attendanceUrl), requestJson(routeUrl)]).then(function (results) {
      attendance = Array.isArray(results[0]) && results[0][0] ? results[0][0] : null
      routePlan = Array.isArray(results[1]) && results[1][0] ? results[1][0] : null
      var vehicleId = attendance && attendance.vehicle_id || routePlan && routePlan.vehicle_id
      var select = 'id,name,plate,brand,model,warehouse_id,current_odometer_km,note,active,fuel_type,tank_capacity_l,assigned_employee_id,stk_valid_until,insurance_valid_until,next_service_date,next_service_odometer_km,service_scope'
      var url = '/rest/v1/vehicles?select=' + encodeURIComponent(select) + '&active=eq.true&order=id'
      return requestJson(url).then(function (rows) {
        var vehicles = Array.isArray(rows) ? rows : []
        vehicle = vehicles.find(function (item) { return String(item.id) === String(vehicleId || '') })
          || vehicles.find(function (item) { return String(item.assigned_employee_id || '') === String(employee.id) }) || null
      })
    }).then(function () {
      if (!vehicle) { renderMissingVehicle(); return }
      var logUrl = '/rest/v1/vehicle_operation_logs?select=*&vehicle_id=eq.' + encodeURIComponent(vehicle.id) + '&order=log_date.desc,updated_at.desc&limit=30'
      var requestUrl = '/rest/v1/operational_requests?select=*&employee_id=eq.' + encodeURIComponent(employee.id) + '&vehicle_id=eq.' + encodeURIComponent(vehicle.id) + '&request_kind=in.(equipment,vehicle_service)&order=created_at.desc&limit=50'
      var checkUrl = '/rest/v1/vehicle_daily_checks?select=*&employee_id=eq.' + encodeURIComponent(employee.id) + '&vehicle_id=eq.' + encodeURIComponent(vehicle.id) + '&check_date=eq.' + todayIso() + '&limit=1'
      return Promise.all([requestJson(logUrl), requestJson(requestUrl), requestJson(checkUrl).catch(function () { return [] })]).then(function (results) {
        logs = Array.isArray(results[0]) ? results[0] : []
        requests = Array.isArray(results[1]) ? results[1] : []
        dailyCheck = Array.isArray(results[2]) && results[2][0] ? results[2][0] : null
        render()
      })
    })
  }

  function renderMissingVehicle() {
    document.querySelector('.ov-vehicle-name').textContent = 'Vozidlo není přiřazené'
    document.querySelector('.ov-plate').textContent = 'Po přiřazení dnešní trasy se údaje zobrazí automaticky.'
    document.querySelector('.ov-km b').textContent = '—'
    document.querySelector('.ov-alerts').innerHTML = '<article class="ov-alert warning"><span class="ov-alert-icon">!</span><div class="ov-alert-copy"><strong>Chybí dnešní vozidlo</strong><span>Kontaktujte vedoucího nebo dispečink.</span></div></article>'
  }

  function render() {
    var log = currentLog()
    document.querySelector('.ov-vehicle-name').textContent = vehicle.name || [vehicle.brand, vehicle.model].filter(Boolean).join(' ') || 'Vozidlo'
    document.querySelector('.ov-plate').textContent = [vehicle.plate, fuelLabel(vehicle.fuel_type), vehicle.service_scope === 'coffee_only' ? 'pouze káva' : 'smíšený provoz'].filter(Boolean).join(' · ')
    document.querySelector('.ov-km b').textContent = Number(vehicle.current_odometer_km || 0).toLocaleString('cs-CZ')
    document.querySelector('.ov-shift-state').textContent = attendance && attendance.actual_start
      ? attendance.actual_end ? 'Dnešní směna je ukončená' : 'Směna právě probíhá'
      : 'Směna připravena k zahájení'
    document.querySelector('.ov-user').textContent = String((employee.name || 'O').charAt(0) + (employee.surname || 'P').charAt(0)).toUpperCase()
    renderAlerts()
    renderRequests()
    renderTech()
    renderCheck()
    renderRide(log)
    renderHistory()
  }

  function fuelLabel(value) {
    return ({ diesel: 'nafta', petrol: 'benzín', lpg: 'LPG', electric: 'elektro', hybrid: 'hybrid' })[value] || value || ''
  }

  function renderAlerts() {
    var alerts = []
    var stkDays = daysUntil(vehicle.stk_valid_until)
    var insuranceDays = daysUntil(vehicle.insurance_valid_until)
    var serviceRemaining = vehicle.next_service_odometer_km == null || vehicle.current_odometer_km == null ? null : Number(vehicle.next_service_odometer_km) - Number(vehicle.current_odometer_km)
    if (stkDays != null && stkDays < 0) alerts.push({ cls: '', icon: '!', title: 'STK je po termínu', copy: 'Evidence uvádí platnost do ' + formatDate(vehicle.stk_valid_until) + '.', action: 'service' })
    else if (stkDays != null && stkDays <= 30) alerts.push({ cls: 'warning', icon: stkDays, title: 'Blíží se konec STK', copy: 'Platnost do ' + formatDate(vehicle.stk_valid_until) + '.', action: 'service' })
    if (serviceRemaining != null && serviceRemaining <= 1000) alerts.push({ cls: serviceRemaining < 0 ? '' : 'warning', icon: serviceRemaining < 0 ? '!' : Math.max(0, serviceRemaining), title: serviceRemaining < 0 ? 'Servisní limit překročen' : 'Servis za ' + serviceRemaining.toLocaleString('cs-CZ') + ' km', copy: 'Servisní limit ' + Number(vehicle.next_service_odometer_km).toLocaleString('cs-CZ') + ' km.', action: 'service' })
    if (insuranceDays != null && insuranceDays <= 30) alerts.push({ cls: 'warning', icon: Math.max(0, insuranceDays), title: 'Blíží se konec pojištění', copy: 'Platnost do ' + formatDate(vehicle.insurance_valid_until) + '.', action: '' })
    if (!alerts.length) alerts.push({ cls: 'warning', icon: '✓', title: 'Technické termíny jsou v pořádku', copy: 'Pro dnešní směnu není evidované žádné upozornění.', action: '' })
    document.querySelector('.ov-alerts').innerHTML = alerts.slice(0, 2).map(function (item) {
      return '<article class="ov-alert ' + item.cls + '"><span class="ov-alert-icon">' + escapeHtml(item.icon) + '</span><div class="ov-alert-copy"><strong>' + escapeHtml(item.title) + '</strong><span>' + escapeHtml(item.copy) + '</span></div>' + (item.action ? '<button type="button" data-open="' + item.action + '">Nahlásit</button>' : '') + '</article>'
    }).join('')
    bindDynamicOpenButtons()
  }

  function statusMeta(status) {
    return ({ new: ['Nový', ''], in_progress: ['Řeší se', 'progress'], warehouse_queue: ['Čeká na sklad', ''], picking: ['Vychystává se', 'progress'], ready: ['Připraveno', 'done'], completed: ['Vyřízeno', 'done'], cancelled: ['Zrušeno', ''] })[status] || [status || 'Nový', '']
  }

  function requestMarkup(row) {
    var meta = statusMeta(row.status)
    var type = row.request_kind === 'vehicle_service' ? 'Servis' : 'Vybavení'
    return '<article class="ov-request"><div><small>' + type + ' · #P-' + escapeHtml(row.id) + '</small><strong>' + escapeHtml(row.title) + '</strong><p>' + escapeHtml(row.need_timing || formatDateTime(row.created_at)) + ' · ' + escapeHtml(vehicle.plate || vehicle.name) + '</p></div><span class="ov-status ' + meta[1] + '">' + escapeHtml(meta[0]) + '</span></article>'
  }

  function renderRequests() {
    var open = requests.filter(function (row) { return ['completed', 'cancelled', 'invoiced'].indexOf(row.status) === -1 })
    var badge = document.querySelector('[data-tab="requests"] i')
    badge.textContent = String(open.length)
    badge.hidden = !open.length
    document.querySelector('#ov-overview-requests').innerHTML = open.length ? open.slice(0, 4).map(requestMarkup).join('') : '<article class="ov-request"><div><strong>Bez otevřených požadavků</strong><p>Nový požadavek můžete založit výše.</p></div><span class="ov-status done">Hotovo</span></article>'
    document.querySelector('#ov-all-requests').innerHTML = requests.length ? requests.map(requestMarkup).join('') : '<article class="ov-request"><div><strong>Zatím bez požadavků</strong><p>Servis a provozní věci založíte tlačítky výše.</p></div></article>'
    var labels = document.querySelectorAll('[data-panel="overview"] .ov-section-head span')
    if (labels[1]) labels[1].textContent = open.length + (open.length === 1 ? ' čeká na vyřízení' : ' čekají na vyřízení')
  }

  function technicalCard(label, value, note, cls) {
    return '<article class="ov-tech ' + (cls || '') + '"><span>' + escapeHtml(label) + '</span><strong>' + escapeHtml(value) + '</strong><small>' + escapeHtml(note) + '</small></article>'
  }

  function deadlineValue(value) {
    var days = daysUntil(value)
    if (days == null) return ['Neuvedeno', 'Doplňte v evidenci', 'warn']
    if (days < 0) return ['Po termínu', formatDate(value), 'bad']
    if (days <= 30) return ['Za ' + days + ' dní', formatDate(value), 'warn']
    return ['V pořádku', formatDate(value), '']
  }

  function renderTech() {
    var stk = deadlineValue(vehicle.stk_valid_until)
    var insurance = deadlineValue(vehicle.insurance_valid_until)
    var remaining = vehicle.next_service_odometer_km == null ? null : Number(vehicle.next_service_odometer_km) - Number(vehicle.current_odometer_km || 0)
    document.querySelector('#ov-tech-grid').innerHTML = technicalCard('STK', stk[0], stk[1], stk[2])
      + technicalCard('Pojištění', insurance[0], insurance[1], insurance[2])
      + technicalCard('Další servis', vehicle.next_service_odometer_km == null ? 'Neuvedeno' : Number(vehicle.next_service_odometer_km).toLocaleString('cs-CZ') + ' km', remaining == null ? 'Bez limitu' : (remaining >= 0 ? 'Zbývá ' + remaining.toLocaleString('cs-CZ') + ' km' : 'Překročeno o ' + Math.abs(remaining).toLocaleString('cs-CZ') + ' km'), remaining != null && remaining <= 1000 ? 'warn' : '')
      + technicalCard('Typ provozu', vehicle.service_scope === 'coffee_only' ? 'Pouze káva' : 'Káva i potraviny', fuelLabel(vehicle.fuel_type), '')
  }

  function checkValues() {
    var keys = ['body_ok', 'tires_ok', 'lights_ok', 'equipment_ok', 'fluids_ok', 'load_secured_ok']
    return keys.map(function (key) { return Boolean(dailyCheck && dailyCheck[key]) })
  }

  function renderCheck() {
    var values = checkValues()
    var count = values.filter(Boolean).length
    document.querySelector('#ov-check-progress').textContent = count + ' z 6'
    document.querySelector('#ov-check-bar').style.width = Math.round(count / 6 * 100) + '%'
    document.querySelector('#ov-check-button').textContent = count === 6 ? 'Kontrola dokončena' : count ? 'Pokračovat v kontrole' : 'Provést kontrolu'
  }

  function renderRide(log) {
    var start = log && log.start_odometer_km != null ? Number(log.start_odometer_km) : Number(vehicle.current_odometer_km || 0)
    var end = log && log.end_odometer_km != null ? Number(log.end_odometer_km) : null
    var distance = end != null ? Math.max(0, end - start) : 0
    var latestFuel = logs.find(function (row) { return Number(row.fuel_liters || 0) > 0 })
    document.querySelector('#ov-metric-grid').innerHTML = '<article class="ov-metric"><span>Počáteční km</span><strong>' + start.toLocaleString('cs-CZ') + '</strong></article><article class="ov-metric"><span>Dnes ujeto</span><strong>' + distance.toLocaleString('cs-CZ') + ' km</strong></article><article class="ov-metric"><span>Poslední tankování</span><strong>' + (latestFuel ? formatDate(latestFuel.log_date) : 'Bez záznamu') + '</strong></article><article class="ov-metric"><span>Stav směny</span><strong>' + (attendance && attendance.actual_start ? attendance.actual_end ? 'Ukončeno' : 'Probíhá' : 'Připraveno') + '</strong></article>'
    document.querySelector('#rideKnownKm').value = Number(vehicle.current_odometer_km || 0).toLocaleString('cs-CZ') + ' km'
    if (!document.querySelector('#rideKm').value) document.querySelector('#rideKm').value = String(end != null ? end : vehicle.current_odometer_km || '')
    if (!document.querySelector('#fuelKm').value) document.querySelector('#fuelKm').value = String(vehicle.current_odometer_km || '')
  }

  function renderHistory() {
    var rows = []
    logs.slice(0, 12).forEach(function (row) {
      if (row.start_odometer_km != null || row.end_odometer_km != null) rows.push({ at: row.updated_at || row.log_date, icon: 'KM', title: row.status === 'closed' ? 'Ukončená jízda' : 'Jízda vozidla', copy: formatDate(row.log_date) + ' · start ' + (row.start_odometer_km == null ? '—' : Number(row.start_odometer_km).toLocaleString('cs-CZ') + ' km'), value: row.distance_km == null ? 'Probíhá' : Number(row.distance_km).toLocaleString('cs-CZ') + ' km' })
      if (Number(row.fuel_liters || 0) > 0) rows.push({ at: row.updated_at || row.log_date, icon: 'PHM', title: 'Tankování', copy: formatDate(row.log_date) + (row.fuel_receipt_url ? ' · účtenka přiložena' : ' · bez účtenky'), value: Number(row.fuel_liters).toLocaleString('cs-CZ') + ' l' })
    })
    requests.forEach(function (row) { var meta = statusMeta(row.status); rows.push({ at: row.updated_at || row.created_at, icon: row.request_kind === 'vehicle_service' ? 'S' : 'V', title: row.title, copy: (row.request_kind === 'vehicle_service' ? 'Servis' : 'Vybavení') + ' · ' + formatDateTime(row.created_at), value: meta[0] }) })
    rows.sort(function (a, b) { return String(b.at || '').localeCompare(String(a.at || '')) })
    document.querySelector('#ov-history-list').innerHTML = rows.length ? rows.slice(0, 20).map(function (row) { return '<article class="ov-history"><span class="ov-history-icon">' + escapeHtml(row.icon) + '</span><div><strong>' + escapeHtml(row.title) + '</strong><span>' + escapeHtml(row.copy) + '</span></div><b>' + escapeHtml(row.value) + '</b></article>' }).join('') : '<article class="ov-history"><span class="ov-history-icon">—</span><div><strong>Zatím bez historie</strong><span>První jízda nebo požadavek se objeví tady.</span></div></article>'
  }

  function bindDynamicOpenButtons() {
    document.querySelectorAll('.ov-alerts [data-open]').forEach(function (button) {
      button.addEventListener('click', function () {
        var original = document.querySelector('.ov-actions [data-open="' + button.getAttribute('data-open') + '"]')
        if (original) original.click()
      })
    })
  }

  function hydrateCheckSheet() {
    window.setTimeout(function () {
      var boxes = document.querySelectorAll('#ov-sheet-body .ov-check input')
      var values = checkValues()
      Array.prototype.forEach.call(boxes, function (box, index) { box.checked = Boolean(values[index]) })
    }, 0)
  }

  function selectPhoto(button) {
    if (activePhotoInput) activePhotoInput.remove()
    var input = document.createElement('input')
    input.type = 'file'
    input.accept = 'image/*'
    input.setAttribute('capture', 'environment')
    input.multiple = button.getAttribute('data-photo-kind') !== 'fuel' && document.getElementById('ov-sheet-title').textContent.indexOf('servis') !== -1
    input.hidden = true
    input.addEventListener('change', function () {
      button._vehicleFiles = Array.prototype.slice.call(input.files || [])
      if (button._vehicleFiles.length) { button.classList.add('ready'); button.textContent = '✓ ' + button._vehicleFiles.length + (button._vehicleFiles.length === 1 ? ' fotografie připravena' : ' fotografie připraveny') }
    })
    document.body.appendChild(input)
    activePhotoInput = input
    input.click()
  }

  function uploadFiles(button, folder) {
    var files = button && button._vehicleFiles || []
    if (!files.length) return Promise.resolve([])
    return Promise.all(files.map(function (file, index) {
      var safeName = String(file.name || 'photo.jpg').replace(/[^a-zA-Z0-9._-]+/g, '-')
      var path = 'vehicle-requests/' + employee.id + '/' + Date.now() + '-' + index + '-' + safeName
      return fetch(supabaseUrl + '/storage/v1/object/shift-documents/' + path, {
        method: 'POST', headers: { apikey: supabaseKey, Authorization: 'Bearer ' + session.access_token, 'Content-Type': file.type || 'image/jpeg', 'x-upsert': 'false' }, body: file
      }).then(function (response) { if (!response.ok) throw new Error('Fotografii se nepodařilo nahrát.'); return supabaseUrl + '/storage/v1/object/public/shift-documents/' + path })
    }))
  }

  function saveCheck(button) {
    if (!vehicle) return Promise.reject(new Error('Vozidlo není přiřazené.'))
    var boxes = document.querySelectorAll('#ov-sheet-body .ov-check input')
    var values = Array.prototype.map.call(boxes, function (box) { return Boolean(box.checked) })
    if (values.length !== 6 || values.some(function (value) { return !value })) throw new Error('Nejdřív zkontrolujte a potvrďte všech šest bodů. Problém nahlaste samostatně na servis.')
    var payload = { vehicle_id: vehicle.id, employee_id: employee.id, attendance_day_id: attendance && attendance.id || null, check_date: todayIso(), body_ok: values[0], tires_ok: values[1], lights_ok: values[2], equipment_ok: values[3], fluids_ok: values[4], load_secured_ok: values[5], checked_at: new Date().toISOString() }
    return requestJson('/rest/v1/vehicle_daily_checks?on_conflict=vehicle_id,employee_id,check_date', { method: 'POST', headers: { Prefer: 'resolution=merge-duplicates,return=representation' }, body: JSON.stringify(payload) }).then(function (rows) { dailyCheck = Array.isArray(rows) && rows[0] ? rows[0] : payload; renderCheck(); closeSheet(); toast('Kontrola vozidla byla potvrzena.') })
  }

  function createRequest(payload, items) {
    return requestJson('/rest/v1/operational_requests', { method: 'POST', headers: { Prefer: 'return=representation' }, body: JSON.stringify(payload) }).then(function (rows) {
      var saved = Array.isArray(rows) && rows[0]
      if (!saved) throw new Error('Požadavek se nepodařilo založit.')
      if (!items || !items.length) return saved
      var requestItems = items.map(function (item) { return { request_id: saved.id, product_name: item.name, unit: 'ks', requested_quantity: item.quantity, note: payload.note || null } })
      return requestJson('/rest/v1/operational_request_items', { method: 'POST', headers: { Prefer: 'return=minimal' }, body: JSON.stringify(requestItems) }).then(function () { return saved }, function () { return saved })
    })
  }

  function submitEquipment() {
    var selected = Array.prototype.map.call(document.querySelectorAll('#ov-sheet-body .ov-choice.active'), function (item) { return item.textContent.trim() })
    if (!selected.length) throw new Error('Vyberte alespoň jednu věc do vozidla.')
    var quantity = Number(document.querySelector('#ov-sheet-body input[type="number"]').value || 0)
    if (!(quantity > 0)) throw new Error('Doplňte množství.')
    var timing = document.querySelector('#ov-sheet-body select').value
    var note = document.querySelector('#ov-sheet-body textarea').value.trim()
    var payload = { request_kind: 'equipment', status: 'new', title: selected.join(', '), note: note || null, need_timing: timing, employee_id: employee.id, vehicle_id: vehicle.id }
    return createRequest(payload, selected.map(function (name) { return { name: name, quantity: quantity } })).then(function () { closeSheet(); toast('Požadavek na vybavení byl odeslán.'); return load() })
  }

  function submitService() {
    var selected = document.querySelector('#ov-sheet-body .ov-choice.active')
    if (!selected) throw new Error('Vyberte typ servisního problému.')
    var selects = document.querySelectorAll('#ov-sheet-body select')
    var driveability = selects[0].value
    var timing = selects[1].value
    var description = document.querySelector('#ov-sheet-body textarea').value.trim()
    if (!description) throw new Error('Popište prosím závadu nebo požadovaný servis.')
    var photoButton = document.querySelector('#ov-sheet-body [data-photo]')
    return uploadFiles(photoButton, 'service').then(function (urls) {
      var payload = { request_kind: 'vehicle_service', status: 'new', title: selected.textContent.trim(), note: description, need_timing: timing, employee_id: employee.id, vehicle_id: vehicle.id, issue_category: selected.textContent.trim(), drivable_status: driveability, attachment_urls: urls }
      return createRequest(payload, [])
    }).then(function () { closeSheet(); toast('Servisní požadavek byl odeslán.'); return load() })
  }

  function saveKilometers(value) {
    var km = Number(String(value || '').replace(/\s/g, ''))
    if (!Number.isFinite(km) || km < Number(vehicle.current_odometer_km || 0)) throw new Error('Stav km nesmí být nižší než poslední evidovaný stav.')
    if (!attendance || !attendance.actual_start) {
      localStorage.setItem(localVehicleKey(), JSON.stringify({ confirmed: true, odometer: km, confirmedAt: new Date().toISOString() }))
      toast('Počáteční stav kilometrů je potvrzený.')
      return Promise.resolve()
    }
    var log = currentLog()
    if (!log || !log.id) throw new Error('Pro dnešní směnu chybí otevřený záznam jízdy.')
    return Promise.all([
      requestJson('/rest/v1/vehicle_operation_logs?id=eq.' + encodeURIComponent(log.id), { method: 'PATCH', headers: { Prefer: 'return=minimal' }, body: JSON.stringify({ end_odometer_km: km }) }),
      requestJson('/rest/v1/vehicles?id=eq.' + encodeURIComponent(vehicle.id), { method: 'PATCH', headers: { Prefer: 'return=minimal' }, body: JSON.stringify({ current_odometer_km: km }) })
    ]).then(function () { vehicle.current_odometer_km = km; toast('Aktuální stav kilometrů byl uložen.'); return load() })
  }

  function saveFuelFromValues(liters, cost, km, note, photoButton) {
    if (!attendance || !attendance.actual_start || attendance.actual_end) throw new Error('Tankování lze uložit pouze během aktivní směny.')
    liters = Number(liters); cost = Number(cost); km = Number(String(km || '').replace(/\s/g, ''))
    if (!(liters > 0) || !(cost > 0) || !Number.isFinite(km)) throw new Error('Doplňte litry, cenu a stav kilometrů.')
    if (!photoButton || !(photoButton._vehicleFiles || []).length) throw new Error('K tankování vyfoťte účtenku.')
    return uploadFiles(photoButton, 'fuel').then(function (urls) {
      var log = currentLog()
      var payload = { vehicle_id: vehicle.id, employee_id: employee.id, attendance_day_id: attendance.id, log_date: todayIso(), started_at: log && log.started_at || attendance.actual_start, start_odometer_km: log && log.start_odometer_km != null ? log.start_odometer_km : vehicle.current_odometer_km, fuel_liters: liters, fuel_cost: cost, fuel_odometer_km: km, fuel_receipt_url: urls[0], fuel_note: note || null, status: log && log.status || 'open' }
      if (log && log.id) return requestJson('/rest/v1/vehicle_operation_logs?id=eq.' + encodeURIComponent(log.id), { method: 'PATCH', headers: { Prefer: 'return=minimal' }, body: JSON.stringify(payload) })
      return requestJson('/rest/v1/vehicle_operation_logs', { method: 'POST', headers: { Prefer: 'return=minimal' }, body: JSON.stringify(payload) })
    }).then(function () { toast('Tankování bylo uloženo.'); return load() })
  }

  function handleAction(button) {
    var sheetTitle = document.getElementById('ov-sheet-title').textContent.toLowerCase()
    if (button.hasAttribute('data-submit-demo')) {
      if (sheetTitle.indexOf('kontrola') !== -1) return saveCheck(button)
      if (sheetTitle.indexOf('vybavení') !== -1) return submitEquipment()
      if (sheetTitle.indexOf('servis') !== -1 || sheetTitle.indexOf('závadu') !== -1) return submitService()
      if (sheetTitle.indexOf('tankování') !== -1) {
        var inputs = document.querySelectorAll('#ov-sheet-body input')
        return saveFuelFromValues(inputs[0].value, inputs[1].value, inputs[2].value, document.querySelector('#ov-sheet-body textarea').value.trim(), document.querySelector('#ov-sheet-body [data-photo]')).then(closeSheet)
      }
      if (sheetTitle.indexOf('kilometr') !== -1) return saveKilometers(document.querySelectorAll('#ov-sheet-body input')[1].value).then(closeSheet)
    }
    if (button.getAttribute('data-save-action') === 'km') return saveKilometers(document.getElementById('rideKm').value)
    if (button.getAttribute('data-save-action') === 'fuel') return saveFuelFromValues(document.getElementById('fuelLiters').value, document.getElementById('fuelPrice').value, document.getElementById('fuelKm').value, document.getElementById('fuelNote').value.trim(), document.querySelector('[data-panel="ride"] [data-photo]'))
    return Promise.resolve()
  }

  document.addEventListener('click', function (event) {
    var target = event.target.closest('button')
    if (!target) return
    if (target.hasAttribute('data-photo')) {
      event.preventDefault(); event.stopImmediatePropagation(); selectPhoto(target); return
    }
    if (target.getAttribute('data-open') === 'check') hydrateCheckSheet()
    if (!target.hasAttribute('data-submit-demo') && !target.hasAttribute('data-save-action')) return
    event.preventDefault(); event.stopImmediatePropagation(); target.disabled = true; setBusy(true, 'Ukládám do OLVEND…')
    Promise.resolve().then(function () { return handleAction(target) }).catch(function (error) { toast(error.message || 'Operaci se nepodařilo uložit.', true) }).then(function () { target.disabled = false; setBusy(false) })
  }, true)

  window.operatorVehicleStart = function (activeSession, activeEmployee) {
    session = activeSession
    employee = activeEmployee || {}
    if (!employee.id) { toast('Profil zaměstnance se nepodařilo načíst.', true); return }
    load().catch(function (error) { toast(error.message || 'Vozidlo se nepodařilo načíst.', true) })
  }
})()
