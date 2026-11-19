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
  var issues = []
  var equipmentRequests = []
  var equipmentItems = []
  var stockRows = []
  var livePosition = null
  var liveHistory = []
  var mileageSummary = null
  var activePhotoInput = null

  var preview = location.hostname === '127.0.0.1' && new URLSearchParams(location.search).get('preview') === 'dashboard'
  if (preview) {
    stockRows = [
      { product_name: 'Snack Svačinka 158 g', sku: '40300015', ean: '', base_unit: 'ks', product_category: 'food_ready', usage_type: '', quantity_on_hand: 8, product_image: './assets/product-images/bagette-svacinka.jpg' },
      { product_name: 'Snack Hamka 146 g', sku: '40300014', ean: '', base_unit: 'ks', product_category: 'food_ready', usage_type: '', quantity_on_hand: 5, product_image: './assets/product-images/bagette-hamka.jpg' },
      { product_name: 'Snickers', sku: 'SNICKERS', ean: '8000500073698', base_unit: 'ks', product_category: 'snack', usage_type: '', quantity_on_hand: 12, product_image: './assets/product-images/ean-8000500073698.jpg' },
      { product_name: 'Red Bull 0,25 l', sku: 'RED-BULL-025', ean: '9002490200091', base_unit: 'ks', product_category: 'drink', usage_type: '', quantity_on_hand: 9, product_image: './assets/product-images/ean-9002490200091.webp' },
      { product_name: 'Creamer White AG PRO 1 kg', sku: 'CREAMER-WHITE', ean: '', base_unit: 'bal.', product_category: 'ingredient', usage_type: 'coffee', quantity_on_hand: 2, image_path: 'static:./assets/product-images/48.jpg' }
    ]
  }

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
      var select = 'id,name,plate,brand,model,warehouse_id,current_odometer_km,note,active,fuel_type,tank_capacity_l,assigned_employee_id,stk_valid_until,insurance_valid_until,next_service_date,next_service_odometer_km,target_consumption_l_100km,tolerated_consumption_l_100km,service_scope,image_path,private_mileage_allowance_percent,mojio_vehicle_id,telemetry_baseline_device_km,telemetry_baseline_vehicle_km,telemetry_baseline_at'
      var url = '/rest/v1/vehicles?select=' + encodeURIComponent(select) + '&active=eq.true&order=id'
      return requestJson(url).then(function (rows) {
        var vehicles = Array.isArray(rows) ? rows : []
        vehicle = vehicles.find(function (item) { return String(item.id) === String(vehicleId || '') })
          || vehicles.find(function (item) { return String(item.assigned_employee_id || '') === String(employee.id) }) || null
      })
    }).then(function () {
      if (!vehicle) { renderMissingVehicle(); return }
      var logUrl = '/rest/v1/vehicle_operation_logs?select=*&vehicle_id=eq.' + encodeURIComponent(vehicle.id) + '&order=log_date.desc,updated_at.desc&limit=30'
      var liveUrl = '/rest/v1/vehicle_live_positions?select=*&vehicle_id=eq.' + encodeURIComponent(vehicle.id) + '&order=ingested_at.desc&limit=1'
      var historyUrl = '/rest/v1/vehicle_live_position_history?select=vehicle_id,odometer_km,fuel_value,fuel_unit,source_updated_at,ingested_at&vehicle_id=eq.' + encodeURIComponent(vehicle.id) + '&order=ingested_at.desc&limit=20'
      var issueUrl = '/rest/v1/vehicle_issues?select=*&vehicle_id=eq.' + encodeURIComponent(vehicle.id) + '&order=created_at.desc&limit=50'
      var equipmentUrl = '/rest/v1/vehicle_equipment_requests?select=*&vehicle_id=eq.' + encodeURIComponent(vehicle.id) + '&order=created_at.desc&limit=50'
      var locationUrl = '/rest/v1/stock_locations?select=id&location_type=eq.vehicle&vehicle_id=eq.' + encodeURIComponent(vehicle.id) + '&active=eq.true&limit=1'
      var mileageRequest = requestJson('/rest/v1/rpc/get_my_vehicle_mileage_summary_v61', { method: 'POST', body: JSON.stringify({ p_vehicle_id: vehicle.id, p_log_date: todayIso() }) })
      return Promise.all([requestJson(logUrl), requestJson(liveUrl).catch(function () { return [] }), requestJson(historyUrl).catch(function () { return [] }), mileageRequest.catch(function () { return null }), requestJson(issueUrl), requestJson(equipmentUrl), requestJson(locationUrl)]).then(function (results) {
        logs = Array.isArray(results[0]) ? results[0] : []
        livePosition = Array.isArray(results[1]) && results[1][0] ? results[1][0] : null
        liveHistory = Array.isArray(results[2]) ? results[2] : []
        mileageSummary = results[3] && !Array.isArray(results[3]) ? results[3] : null
        issues = Array.isArray(results[4]) ? results[4] : []
        equipmentRequests = Array.isArray(results[5]) ? results[5] : []
        var location = Array.isArray(results[6]) && results[6][0] ? results[6][0] : null
        var equipmentIds = equipmentRequests.map(function (row) { return row.id }).filter(Boolean)
        var equipmentItemsRequest = equipmentIds.length ? requestJson('/rest/v1/vehicle_equipment_request_items?select=*&request_id=in.(' + equipmentIds.map(encodeURIComponent).join(',') + ')&order=id') : Promise.resolve([])
        var stockRequest = location ? requestJson('/rest/v1/stock_location_balances?select=id,product_id,quantity_on_hand,reserved_quantity,updated_at,products(id,name,sku,ean,base_unit,product_category,usage_type,image_path)&stock_location_id=eq.' + encodeURIComponent(location.id) + '&quantity_on_hand=gt.0&order=updated_at.desc') : Promise.resolve([])
        return Promise.all([equipmentItemsRequest, stockRequest])
      }).then(function (detailResults) {
        equipmentItems = Array.isArray(detailResults[0]) ? detailResults[0] : []
        stockRows = window.OlvendOperatorStockCore.aggregateStockRows((Array.isArray(detailResults[1]) ? detailResults[1] : []).map(function (row) {
          var product = row.products || {}
          return Object.assign({}, row, { product_name: product.name || 'Položka', sku: product.sku || '', ean: product.ean || '', base_unit: product.base_unit || 'ks', product_category: product.product_category || '', usage_type: product.usage_type || '', image_path: product.image_path || '' })
        }))
        return Promise.all(stockRows.map(hydrateStockImage))
      }).then(function (hydratedStockRows) {
        stockRows = hydratedStockRows
        requests = issues.map(function (row) {
          return Object.assign({}, row, { source: 'issue', request_kind: 'vehicle_service', title: row.subcategory || issueCategoryLabel(row.category), note: row.description })
        }).concat(equipmentRequests.map(function (row) {
          var items = equipmentItems.filter(function (item) { return String(item.request_id) === String(row.id) })
          return Object.assign({}, row, { source: 'equipment', request_kind: 'equipment', title: items.map(function (item) { return item.item_name + ' ' + Number(item.quantity).toLocaleString('cs-CZ') + ' ' + item.unit }).join(', ') || 'Vybavení do auta' })
        })).sort(function (a, b) { return String(b.created_at || '').localeCompare(String(a.created_at || '')) })
        render()
      })
    })
  }

  function renderMissingVehicle() {
    document.querySelector('.ov-vehicle-name').textContent = 'Vozidlo není přiřazené'
    document.querySelector('.ov-plate').textContent = 'Po přiřazení dnešní trasy se údaje zobrazí automaticky.'
    document.querySelector('.ov-km b').textContent = '—'
    document.getElementById('ovVehiclePhoto').hidden = true
    document.getElementById('ovLiveFuel').textContent = 'Bez vozidla'
    document.getElementById('ovLiveState').textContent = 'Bez vozidla'
    document.querySelector('.ov-alerts').innerHTML = '<article class="ov-alert warning"><span class="ov-alert-icon">!</span><div class="ov-alert-copy"><strong>Chybí dnešní vozidlo</strong><span>Kontaktujte vedoucího nebo dispečink.</span></div></article>'
  }

  function render() {
    var log = currentLog()
    var currentOdometer = estimatedVehicleOdometer()
    document.querySelector('.ov-vehicle-name').textContent = vehicle.name || [vehicle.brand, vehicle.model].filter(Boolean).join(' ') || 'Vozidlo'
    document.querySelector('.ov-plate').textContent = [vehicle.plate, fuelLabel(vehicle.fuel_type), vehicle.service_scope === 'coffee_only' ? 'pouze káva' : 'smíšený provoz'].filter(Boolean).join(' · ')
    document.querySelector('.ov-km b').textContent = currentOdometer.toLocaleString('cs-CZ', { maximumFractionDigits: 0 })
    document.querySelector('.ov-shift-state').textContent = attendance && attendance.actual_start
      ? attendance.actual_end ? 'Dnešní směna je ukončená' : 'Směna právě probíhá'
      : 'Směna připravena k zahájení'
    document.querySelector('.ov-user').textContent = String((employee.name || 'O').charAt(0) + (employee.surname || 'P').charAt(0)).toUpperCase()
    renderVehiclePhoto()
    renderLiveVehicle()
    renderMileage()
    renderStock()
    renderAlerts()
    renderRequests()
    renderTech()
    renderRide(log)
    renderHistory()
  }

  function fuelLabel(value) {
    return ({ diesel: 'nafta', petrol: 'benzín', lpg: 'LPG', electric: 'elektro', hybrid: 'hybrid' })[value] || value || ''
  }

  function issueCategoryLabel(value) {
    return ({ engine: 'Kontrolka / motor', tires: 'Pneumatiky', fluids: 'Olej a kapaliny', brakes: 'Brzdy', lights: 'Světla', body: 'Karoserie / sklo', cargo: 'Nákladový prostor', service: 'Servis / údržba', other: 'Jiná závada' })[value] || value || 'Závada'
  }

  function estimatedVehicleOdometer() {
    var raw = livePosition && livePosition.odometer_km != null ? Number(livePosition.odometer_km) : null
    var deviceBase = vehicle && vehicle.telemetry_baseline_device_km != null ? Number(vehicle.telemetry_baseline_device_km) : null
    var vehicleBase = vehicle && vehicle.telemetry_baseline_vehicle_km != null ? Number(vehicle.telemetry_baseline_vehicle_km) : null
    if (Number.isFinite(raw) && Number.isFinite(deviceBase) && Number.isFinite(vehicleBase) && raw >= deviceBase) return vehicleBase + raw - deviceBase
    return Number(vehicle && vehicle.current_odometer_km || 0)
  }

  function vehicleImageUrl() {
    var path = String(vehicle && vehicle.image_path || '').trim()
    if (path.indexOf('static:') === 0) return path.slice(7)
    var plate = String(vehicle && vehicle.plate || '').replace(/\s+/g, '').toUpperCase()
    return ({ '3BU9736': '../assets/vehicles/fiat-doblo-2012.png?v=20261111-fleet-art-v2', '5AP9000': '../assets/vehicles/fiat-doblo-modern.png?v=20261111-fleet-art-v2', '7Z71808': '../assets/vehicles/opel-combo-2024-passenger.png?v=20261111-fleet-art-v2', '2BN7419': '../assets/vehicles/opel-movano-older.png?v=20261111-fleet-art-v2', '2TX7928': '../assets/vehicles/renault-kangoo-2019.png?v=20261111-fleet-art-v2' })[plate] || ''
  }

  function renderVehiclePhoto() {
    var image = document.getElementById('ovVehiclePhoto')
    var url = vehicleImageUrl()
    image.hidden = !url
    if (url) image.src = url
  }

  function fuelPercent() {
    if (!livePosition || livePosition.fuel_value == null) return null
    var value = Number(livePosition.fuel_value)
    if (!Number.isFinite(value)) return null
    var unit = String(livePosition.fuel_unit || '').toLowerCase()
    if (unit.indexOf('%') !== -1 || unit.indexOf('percent') !== -1) return Math.max(0, Math.min(100, value))
    if (vehicle.tank_capacity_l && value <= Number(vehicle.tank_capacity_l) * 1.15) return Math.max(0, Math.min(100, value / Number(vehicle.tank_capacity_l) * 100))
    return value <= 100 ? Math.max(0, value) : null
  }

  function renderLiveVehicle() {
    var percent = fuelPercent()
    var online = livePosition && livePosition.is_online === true
    document.getElementById('ovLiveFuel').textContent = percent == null ? 'Bez dat' : Math.round(percent).toLocaleString('cs-CZ') + ' %' + (vehicle.tank_capacity_l ? ' · cca ' + Math.round(Number(vehicle.tank_capacity_l) * percent / 100).toLocaleString('cs-CZ') + ' l' : '')
    document.getElementById('ovLiveFuelTime').textContent = livePosition && livePosition.ingested_at ? 'T-Mobile · ' + formatDateTime(livePosition.ingested_at) : 'T-Mobile · čeká na data'
    document.getElementById('ovLiveState').textContent = livePosition ? online ? 'Online' : livePosition.is_parked ? 'Zaparkováno' : 'Offline' : 'Bez dat'
    document.getElementById('ovLiveTime').textContent = livePosition && (livePosition.source_updated_at || livePosition.ingested_at) ? formatDateTime(livePosition.source_updated_at || livePosition.ingested_at) + (vehicle.telemetry_baseline_at ? ' · km kalibrovány' : ' · km čekají na potvrzení') : 'Poslední synchronizace není dostupná'
  }

  function renderMileage() {
    var summary = mileageSummary || {}
    var percent = Number(summary.allowance_percent == null ? vehicle.private_mileage_allowance_percent || 5 : summary.allowance_percent)
    document.getElementById('ovMileagePercent').textContent = percent.toLocaleString('cs-CZ') + ' % z plánu'
    document.getElementById('ovMileagePlan').textContent = Number(summary.today_planned_km || 0).toLocaleString('cs-CZ') + ' km'
    document.getElementById('ovMileageActual').textContent = Number(summary.today_actual_km || 0).toLocaleString('cs-CZ') + ' km'
    document.getElementById('ovMileageRemaining').textContent = Number(summary.today_private_remaining_km || 0).toLocaleString('cs-CZ') + ' km'
    document.getElementById('ovMileageToday').textContent = 'Dnes čerpáno ' + Number(summary.today_private_used_km || 0).toLocaleString('cs-CZ') + ' km'
    document.getElementById('ovMileageMonth').textContent = 'Měsíc zbývá ' + Number(summary.month_private_remaining_km || 0).toLocaleString('cs-CZ') + ' km'
  }

  function normalizeText(value) {
    return String(value || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase()
  }

  function stockCategory(row) {
    return window.OlvendOperatorStockCore.stockCategory(row)
  }

  function stockCategoryLabel(category) {
    return ({ fresh: 'Bagety a čerstvé', sweets: 'Cukrovinky a snacky', drinks: 'Nápoje', ingredients: 'Suroviny a obaly' })[category] || 'Ostatní'
  }

  function stockCategoryRank(category) {
    return ({ fresh: 0, sweets: 1, drinks: 2, ingredients: 3 })[category] == null ? 9 : ({ fresh: 0, sweets: 1, drinks: 2, ingredients: 3 })[category]
  }

  function stockItemCountLabel(count) {
    if (count === 1) return '1 položka'
    if (count >= 2 && count <= 4) return count.toLocaleString('cs-CZ') + ' položky'
    return count.toLocaleString('cs-CZ') + ' položek'
  }

  function stockProductImage(row) {
    if (row.product_image) return row.product_image
    var path = String(row.image_path || '')
    if (path.indexOf('static:') === 0) {
      var staticPath = path.slice(7)
      return staticPath.indexOf('./assets/') === 0 ? '../assets/' + staticPath.slice(9) : staticPath
    }
    var name = normalizeText(row.product_name)
    if (name.indexOf('svacink') >= 0) return './assets/product-images/bagette-svacinka.jpg'
    if (name.indexOf('hamka') >= 0) return './assets/product-images/bagette-hamka.jpg'
    if (name.indexOf('porizek') >= 0) return './assets/product-images/bagette-porizek.jpg'
    var byEan = { '9002490200091': 'ean-9002490200091.webp', '7622201390648': 'ean-7622201390648.jpg', '5949040204427': 'ean-5949040204427.jpg', '8000500073698': 'ean-8000500073698.jpg', '3838945043694': 'ean-3838945043694.png', '8586018180863': 'ean-8586018180863.jpg', '8594002072858': 'ean-8594002072858.webp' }
    return byEan[String(row.ean || '')] ? './assets/product-images/' + byEan[String(row.ean)] : './icon-192.png'
  }

  function hydrateStockImage(row) {
    var path = String(row.image_path || '')
    if (!path || path.indexOf('static:') === 0) {
      row.product_image = stockProductImage(row)
      return Promise.resolve(row)
    }
    return requestJson('/storage/v1/object/sign/product-images/' + path.split('/').map(encodeURIComponent).join('/'), { method: 'POST', body: JSON.stringify({ expiresIn: 43200 }) }).then(function (data) {
      if (data && data.signedURL) row.product_image = supabaseUrl + '/storage/v1' + data.signedURL
      else if (data && data.signedUrl) row.product_image = data.signedUrl
      else row.product_image = stockProductImage(row)
      return row
    }).catch(function () { row.product_image = stockProductImage(row); return row })
  }

  function renderStock() {
    var totals = { fresh: 0, sweets: 0, drinks: 0, ingredients: 0 }
    stockRows.forEach(function (row) { totals[stockCategory(row)] += Number(row.quantity_on_hand || 0) })
    document.getElementById('ovStockFresh').textContent = totals.fresh.toLocaleString('cs-CZ') + ' ks'
    document.getElementById('ovStockSweets').textContent = totals.sweets.toLocaleString('cs-CZ') + ' ks'
    document.getElementById('ovStockDrinks').textContent = totals.drinks.toLocaleString('cs-CZ') + ' ks'
    document.getElementById('ovStockIngredients').textContent = totals.ingredients.toLocaleString('cs-CZ') + ' j.'
  }

  function openStockSheet() {
    var rows = stockRows.slice().sort(function (a, b) { return stockCategoryRank(stockCategory(a)) - stockCategoryRank(stockCategory(b)) || String(a.product_name).localeCompare(String(b.product_name), 'cs') })
    var categories = ['fresh', 'sweets', 'drinks', 'ingredients']
    var html = '<div class="ov-stock-list">' + (rows.length ? categories.map(function (category) {
      var items = rows.filter(function (row) { return stockCategory(row) === category })
      if (!items.length) return ''
      var total = items.reduce(function (sum, row) { return sum + Number(row.quantity_on_hand || 0) }, 0)
      return '<section class="ov-stock-group"><header class="ov-stock-group-head"><strong>' + stockCategoryLabel(category) + '</strong><span>' + stockItemCountLabel(items.length) + ' · celkem ' + total.toLocaleString('cs-CZ') + '</span></header>' + items.map(function (row) {
        return '<article class="ov-stock-row"><img src="' + escapeHtml(stockProductImage(row)) + '" alt=""><div><strong>' + escapeHtml(row.product_name) + '</strong><small>' + escapeHtml([row.sku, row.ean].filter(Boolean).join(' · ')) + '</small></div><b>' + Number(row.quantity_on_hand || 0).toLocaleString('cs-CZ') + ' ' + escapeHtml(row.base_unit || 'ks') + '</b></article>'
      }).join('') + '</section>'
    }).join('') : '<article class="ov-request"><div><strong>Vozidlo je bez evidované zásoby</strong><p>Stav se načítá přímo ze skladu vozidla.</p></div></article>') + '</div>'
    if (window.operatorVehicleOpenCustomSheet) window.operatorVehicleOpenCustomSheet('▣', 'Zásoby vozidla', 'Co je právě v autě', html)
  }

  function detectedFuelIncrease() {
    var rows = liveHistory.filter(function (row) { return row.fuel_value != null }).slice().sort(function (a, b) { return String(a.ingested_at || a.source_updated_at || '').localeCompare(String(b.ingested_at || b.source_updated_at || '')) })
    if (rows.length < 2) return null
    var previous = Number(rows[rows.length - 2].fuel_value)
    var current = Number(rows[rows.length - 1].fuel_value)
    if (!Number.isFinite(previous) || !Number.isFinite(current) || current - previous < 5) return null
    return { previous: previous, current: current, increase: current - previous }
  }

  window.operatorVehicleHydrateSheet = function (name) {
    if (name === 'fuel') {
      var inputs = document.querySelectorAll('#ov-sheet-body input')
      var log = currentLog()
      if (inputs[0]) inputs[0].value = log && log.fuel_liters || ''
      if (inputs[1]) inputs[1].value = log && log.fuel_cost || ''
      if (inputs[2]) inputs[2].value = log && log.fuel_odometer_km || livePosition && livePosition.odometer_km || vehicle.current_odometer_km || ''
      var fullTank = document.querySelector('#ov-sheet-body [data-full-tank]') || document.getElementById('rideFuelFullTank')
      if (fullTank) fullTank.checked = Boolean(log && log.fuel_full_tank)
      var warning = document.querySelector('#ov-sheet-body [data-fuel-telemetry]')
      var increase = detectedFuelIncrease()
      if (warning && increase && !(log && log.fuel_logged_at)) {
        warning.hidden = false
        warning.textContent = 'T-Mobile zaznamenal zvýšení paliva o ' + increase.increase.toLocaleString('cs-CZ', { maximumFractionDigits: 1 }) + '. Pokud jste tankovali, zápis a účtenku uložte před ukončením směny.'
      }
    }
    if (name === 'km') {
      var kmInputs = document.querySelectorAll('#ov-sheet-body input')
      var known = livePosition && livePosition.odometer_km != null ? livePosition.odometer_km : vehicle.current_odometer_km
      if (kmInputs[0]) kmInputs[0].value = Number(known || 0).toLocaleString('cs-CZ') + ' km'
      if (kmInputs[1]) kmInputs[1].value = currentLog() && currentLog().end_odometer_km != null ? currentLog().end_odometer_km : known || ''
    }
  }

  function renderAlerts() {
    var alerts = []
    var stoppedIssue = issues.find(function (row) { return row.drive_status === 'stop' && ['resolved', 'cancelled'].indexOf(row.status) === -1 })
    var adviceIssue = issues.find(function (row) { return row.drive_status === 'advice' && ['resolved', 'cancelled'].indexOf(row.status) === -1 })
    var stkDays = daysUntil(vehicle.stk_valid_until)
    var insuranceDays = daysUntil(vehicle.insurance_valid_until)
    var serviceRemaining = vehicle.next_service_odometer_km == null ? null : Number(vehicle.next_service_odometer_km) - estimatedVehicleOdometer()
    if (stoppedIssue) alerts.push({ cls: '', icon: '!', title: 'Vozidlo je zastavené', copy: stoppedIssue.description || 'Čeká na vyřešení nahlášené závady.', action: 'service' })
    else if (adviceIssue) alerts.push({ cls: 'warning', icon: '!', title: 'Čeká se na posouzení závady', copy: adviceIssue.description || 'Operátor potřebuje rozhodnutí, zda lze pokračovat.', action: 'service' })
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
    return ({ new: ['Nový', ''], assigned: ['Převzatá', 'progress'], service: ['V servisu', 'progress'], resolved: ['Vyřešená', 'done'], in_progress: ['Řeší se', 'progress'], warehouse_queue: ['Čeká na sklad', ''], picking: ['Vychystává se', 'progress'], ready: ['Připraveno', 'done'], completed: ['Vyřízeno', 'done'], cancelled: ['Zrušeno', ''] })[status] || [status || 'Nový', '']
  }

  function requestMarkup(row) {
    var meta = statusMeta(row.status)
    var type = row.request_kind === 'vehicle_service' ? 'Servis' : 'Vybavení'
    return '<article class="ov-request"><div><small>' + type + ' · #' + escapeHtml(row.id) + '</small><strong>' + escapeHtml(row.title) + '</strong><p>' + escapeHtml((row.note ? row.note + ' · ' : '') + formatDateTime(row.created_at)) + ' · ' + escapeHtml(vehicle.plate || vehicle.name) + '</p></div><span class="ov-status ' + meta[1] + '">' + escapeHtml(meta[0]) + '</span></article>'
  }

  function renderRequests() {
    var open = requests.filter(function (row) { return ['resolved', 'completed', 'cancelled', 'invoiced'].indexOf(row.status) === -1 })
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
    var remaining = vehicle.next_service_odometer_km == null ? null : Number(vehicle.next_service_odometer_km) - estimatedVehicleOdometer()
    document.querySelector('#ov-tech-grid').innerHTML = technicalCard('STK', stk[0], stk[1], stk[2])
      + technicalCard('Pojištění', insurance[0], insurance[1], insurance[2])
      + technicalCard('Další servis', vehicle.next_service_odometer_km == null ? 'Neuvedeno' : Number(vehicle.next_service_odometer_km).toLocaleString('cs-CZ') + ' km', remaining == null ? 'Bez limitu' : (remaining >= 0 ? 'Zbývá ' + remaining.toLocaleString('cs-CZ') + ' km' : 'Překročeno o ' + Math.abs(remaining).toLocaleString('cs-CZ') + ' km'), remaining != null && remaining <= 1000 ? 'warn' : '')
      + technicalCard('Typ provozu', vehicle.service_scope === 'coffee_only' ? 'Pouze káva' : 'Káva i potraviny', fuelLabel(vehicle.fuel_type), '')
  }

  function renderRide(log) {
    var start = log && log.start_odometer_km != null ? Number(log.start_odometer_km) : Number(vehicle.current_odometer_km || 0)
    var end = log && log.end_odometer_km != null ? Number(log.end_odometer_km) : null
    var distance = end != null ? Math.max(0, end - start) : 0
    var latestFuel = logs.find(function (row) { return Number(row.fuel_liters || 0) > 0 })
    var fuelLogs = logs.filter(function (row) { return Number(row.fuel_liters || 0) > 0 && Number(row.fuel_odometer_km || 0) > 0 }).slice().sort(function (a, b) { return Number(a.fuel_odometer_km) - Number(b.fuel_odometer_km) })
    var consumption = null
    if (fuelLogs.length > 1) {
      var last = fuelLogs[fuelLogs.length - 1]
      var before = fuelLogs[fuelLogs.length - 2]
      var kmDistance = Number(last.fuel_odometer_km) - Number(before.fuel_odometer_km)
      if (kmDistance > 0) consumption = Number(last.fuel_liters) / kmDistance * 100
    }
    document.querySelector('#ov-metric-grid').innerHTML = '<article class="ov-metric"><span>Počáteční km</span><strong>' + start.toLocaleString('cs-CZ') + '</strong></article><article class="ov-metric"><span>Dnes ujeto</span><strong>' + distance.toLocaleString('cs-CZ') + ' km</strong></article><article class="ov-metric"><span>Poslední tankování</span><strong>' + (latestFuel ? formatDate(latestFuel.log_date) : 'Bez záznamu') + '</strong></article><article class="ov-metric"><span>Kontrolní spotřeba</span><strong>' + (consumption == null ? 'Čeká na data' : consumption.toLocaleString('cs-CZ', { maximumFractionDigits: 1 }) + ' l / 100 km') + '</strong></article>'
    var knownKm = estimatedVehicleOdometer()
    document.querySelector('#rideKnownKm').value = knownKm.toLocaleString('cs-CZ') + ' km'
    if (!document.querySelector('#rideKm').value) document.querySelector('#rideKm').value = String(end != null ? end : vehicle.current_odometer_km || '')
    if (!document.querySelector('#fuelKm').value) document.querySelector('#fuelKm').value = String(knownKm || '')
    var increase = detectedFuelIncrease()
    var warning = document.getElementById('ovFuelTelemetryWarning')
    var fuelLogged = Boolean(log && (log.fuel_logged_at || log.fuel_receipt_url))
    warning.hidden = !increase || fuelLogged
    warning.textContent = increase ? 'T-Mobile zaznamenal zvýšení paliva o ' + increase.increase.toLocaleString('cs-CZ', { maximumFractionDigits: 1 }) + '. Pokud jste tankovali, zapište tankování a přiložte účtenku.' : ''
    if (consumption != null && vehicle.tolerated_consumption_l_100km != null && consumption > Number(vehicle.tolerated_consumption_l_100km)) {
      warning.hidden = false
      warning.textContent += (warning.textContent ? ' ' : '') + 'Kontrolní spotřeba je nad nastaveným limitem ' + Number(vehicle.tolerated_consumption_l_100km).toLocaleString('cs-CZ') + ' l / 100 km.'
    }
  }

  function renderHistory() {
    var rows = []
    logs.slice(0, 12).forEach(function (row) {
      if (row.start_odometer_km != null || row.end_odometer_km != null) rows.push({ at: row.updated_at || row.log_date, icon: 'odometer', title: row.status === 'closed' ? 'Ukončená jízda' : 'Jízda vozidla', copy: formatDate(row.log_date) + ' · start ' + (row.start_odometer_km == null ? '—' : Number(row.start_odometer_km).toLocaleString('cs-CZ') + ' km'), value: row.distance_km == null ? 'Probíhá' : Number(row.distance_km).toLocaleString('cs-CZ') + ' km' })
      if (Number(row.fuel_liters || 0) > 0) rows.push({ at: row.updated_at || row.log_date, icon: 'fuel', title: 'Tankování', copy: formatDate(row.log_date) + (row.fuel_receipt_url ? ' · účtenka přiložena' : ' · bez účtenky'), value: Number(row.fuel_liters).toLocaleString('cs-CZ') + ' l' })
    })
    requests.forEach(function (row) { var meta = statusMeta(row.status); rows.push({ at: row.updated_at || row.created_at, icon: row.request_kind === 'vehicle_service' ? 'service' : 'equipment', title: row.title, copy: (row.request_kind === 'vehicle_service' ? 'Servis' : 'Vybavení') + ' · ' + formatDateTime(row.created_at), value: meta[0] }) })
    rows.sort(function (a, b) { return String(b.at || '').localeCompare(String(a.at || '')) })
    document.querySelector('#ov-history-list').innerHTML = rows.length ? rows.slice(0, 20).map(function (row) { return '<article class="ov-history"><span class="ov-history-icon">' + historyIcon(row.icon) + '</span><div><strong>' + escapeHtml(row.title) + '</strong><span>' + escapeHtml(row.copy) + '</span></div><b>' + escapeHtml(row.value) + '</b></article>' }).join('') : '<article class="ov-history"><span class="ov-history-icon">' + historyIcon('history') + '</span><div><strong>Zatím bez historie</strong><span>První jízda nebo požadavek se objeví tady.</span></div></article>'
  }

  function historyIcon(type) {
    var paths = {
      odometer: '<path d="M4 16a8 8 0 1 1 16 0"/><path d="M12 12l3-3"/><path d="M8 17h8"/><path d="M6.5 12.5l-1.5-1M17.5 12.5l1.5-1M12 8V6"/>',
      fuel: '<path d="M5 21V4h10v17"/><path d="M4 21h12"/><path d="M8 8h4"/><path d="M15 7h2l2 2v7a1.5 1.5 0 0 0 3 0v-5l-2-2"/>',
      service: '<path d="M14.7 6.3a4 4 0 0 0-5-5L12 3.6 9.6 6 7.3 3.7a4 4 0 0 0 5 5L20 16.4a2.1 2.1 0 0 1-3 3l-7.7-7.7"/>',
      equipment: '<path d="M4 7h16v13H4z"/><path d="M8 7V4h8v3"/><path d="M4 12h16"/><path d="M10 12v2h4v-2"/>',
      history: '<path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5"/><path d="M12 7v5l3 2"/>'
    }
    return '<svg viewBox="0 0 24 24" aria-hidden="true">' + (paths[type] || paths.history) + '</svg>'
  }

  function bindDynamicOpenButtons() {
    document.querySelectorAll('.ov-alerts [data-open]').forEach(function (button) {
      button.addEventListener('click', function () {
        var original = document.querySelector('.ov-actions [data-open="' + button.getAttribute('data-open') + '"]')
        if (original) original.click()
      })
    })
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
    if (!attendance || String(attendance.vehicle_id || '') !== String(vehicle.id)) throw new Error('Požadavek lze odeslat jen k vozidlu dnešní směny.')
    var selected = Array.prototype.map.call(document.querySelectorAll('#ov-sheet-body [data-equipment-item]'), function (item) {
      var quantity = Number(item.querySelector('input').value || 0)
      return { item_key: item.getAttribute('data-key'), item_name: item.querySelector('span').textContent.trim(), category: item.getAttribute('data-category'), quantity: quantity, unit: item.getAttribute('data-unit'), reason: 'doplnit' }
    }).filter(function (item) { return item.quantity > 0 })
    if (!selected.length) throw new Error('U alespoň jedné položky doplňte množství.')
    var note = document.querySelector('#ov-sheet-body textarea').value.trim()
    var photoButton = document.querySelector('#ov-sheet-body [data-photo]')
    return uploadFiles(photoButton, 'equipment').then(function (urls) {
      return requestJson('/rest/v1/rpc/create_vehicle_equipment_request_v61', { method: 'POST', body: JSON.stringify({ p_request: { vehicle_id: vehicle.id, vehicle_operation_log_id: currentLog() && currentLog().id || null, attendance_day_id: attendance.id, note: note || null }, p_items: selected, p_photo_urls: urls }) })
    }).then(function () { closeSheet(); toast('Požadavek na vybavení byl odeslán.'); return load() })
  }

  function submitService() {
    var selected = document.querySelector('#ov-sheet-body .ov-choice.active')
    if (!selected) throw new Error('Vyberte typ servisního problému.')
    if (!attendance || String(attendance.vehicle_id || '') !== String(vehicle.id)) throw new Error('Závadu lze odeslat jen k vozidlu dnešní směny.')
    var driveability = document.querySelector('#ov-sheet-body select').value
    var description = document.querySelector('#ov-sheet-body textarea').value.trim()
    if (!description) throw new Error('Popište prosím závadu nebo požadovaný servis.')
    var photoButton = document.querySelector('#ov-sheet-body [data-photo]')
    if (!photoButton || !(photoButton._vehicleFiles || []).length) throw new Error('K závadě přidejte alespoň jednu fotografii.')
    return uploadFiles(photoButton, 'service').then(function (urls) {
      return requestJson('/rest/v1/rpc/create_vehicle_issue_v61', { method: 'POST', body: JSON.stringify({ p_issue: { vehicle_id: vehicle.id, vehicle_operation_log_id: currentLog() && currentLog().id || null, attendance_day_id: attendance.id, category: selected.getAttribute('data-issue-category') || 'other', subcategory: selected.textContent.trim(), description: description, drive_status: driveability }, p_photo_urls: urls }) })
    }).then(function () { closeSheet(); toast(driveability === 'stop' ? 'Závada je odeslaná a vozidlo je označené jako zastavené.' : 'Závada byla odeslána do správy vozidel.'); return load() })
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
      requestJson('/rest/v1/vehicles?id=eq.' + encodeURIComponent(vehicle.id), { method: 'PATCH', headers: { Prefer: 'return=minimal' }, body: JSON.stringify({ current_odometer_km: km, telemetry_baseline_device_km: livePosition && livePosition.odometer_km != null ? Number(livePosition.odometer_km) : null, telemetry_baseline_vehicle_km: livePosition && livePosition.odometer_km != null ? km : null, telemetry_baseline_at: livePosition && livePosition.odometer_km != null ? new Date().toISOString() : null }) })
    ]).then(function () { vehicle.current_odometer_km = km; toast('Aktuální stav kilometrů byl uložen.'); return load() })
  }

  function saveFuelFromValues(liters, cost, km, note, photoButton) {
    if (!attendance || !attendance.actual_start || attendance.actual_end) throw new Error('Tankování lze uložit pouze během aktivní směny.')
    liters = Number(liters); cost = Number(cost); km = Number(String(km || '').replace(/\s/g, ''))
    if (!(liters > 0) || !(cost > 0) || !Number.isFinite(km)) throw new Error('Doplňte litry, cenu a stav kilometrů.')
    if (!photoButton || !(photoButton._vehicleFiles || []).length) throw new Error('K tankování vyfoťte účtenku.')
    return uploadFiles(photoButton, 'fuel').then(function (urls) {
      var log = currentLog()
      var orderedFuel = liveHistory.filter(function (row) { return row.fuel_value != null }).slice().sort(function (a, b) { return String(a.ingested_at || '').localeCompare(String(b.ingested_at || '')) })
      var fullTank = document.querySelector('#ov-sheet-body [data-full-tank]')
      var payload = { vehicle_id: vehicle.id, employee_id: employee.id, attendance_day_id: attendance.id, log_date: todayIso(), started_at: log && log.started_at || attendance.actual_start, start_odometer_km: log && log.start_odometer_km != null ? log.start_odometer_km : vehicle.current_odometer_km, fuel_liters: liters, fuel_cost: cost, fuel_odometer_km: km, fuel_receipt_url: urls[0], fuel_note: note || null, fuel_full_tank: Boolean(fullTank && fullTank.checked), fuel_level_before: orderedFuel.length > 1 ? orderedFuel[orderedFuel.length - 2].fuel_value : null, fuel_level_after: orderedFuel.length ? orderedFuel[orderedFuel.length - 1].fuel_value : null, fuel_logged_at: new Date().toISOString(), status: log && log.status || 'open' }
      if (log && log.id) return requestJson('/rest/v1/vehicle_operation_logs?id=eq.' + encodeURIComponent(log.id), { method: 'PATCH', headers: { Prefer: 'return=minimal' }, body: JSON.stringify(payload) })
      return requestJson('/rest/v1/vehicle_operation_logs', { method: 'POST', headers: { Prefer: 'return=minimal' }, body: JSON.stringify(payload) })
    }).then(function () { toast('Tankování bylo uloženo.'); return load() })
  }

  function handleAction(button) {
    var sheetTitle = document.getElementById('ov-sheet-title').textContent.toLowerCase()
    if (button.hasAttribute('data-submit-demo')) {
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
    if (!target.hasAttribute('data-submit-demo') && !target.hasAttribute('data-save-action')) return
    event.preventDefault(); event.stopImmediatePropagation(); target.disabled = true; setBusy(true, 'Ukládám do OLVEND…')
    Promise.resolve().then(function () { return handleAction(target) }).catch(function (error) { toast(error.message || 'Operaci se nepodařilo uložit.', true) }).then(function () { target.disabled = false; setBusy(false) })
  }, true)

  document.getElementById('ovStockCard').addEventListener('click', openStockSheet)
  if (preview) renderStock()

  window.operatorVehicleStart = function (activeSession, activeEmployee) {
    session = activeSession
    employee = activeEmployee || {}
    if (!employee.id) { toast('Profil zaměstnance se nepodařilo načíst.', true); return }
    load().catch(function (error) { toast(error.message || 'Vozidlo se nepodařilo načíst.', true) })
  }
})()
