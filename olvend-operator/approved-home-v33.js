(function () {
  'use strict'

  var supabaseUrl = 'https://rerjlkrhiytgscjerqgs.supabase.co'
  var supabaseKey = 'sb_publishable_A8OxCcapdNXAzQLjLsW5iA_XtGvBZ0S'
  var root = document.getElementById('olvend-before-shift-tiles')
  var session = null
  var employee = null
  var routePlan = null
  var vehicle = null
  var warehouse = null
  var instruction = null
  var attendanceDay = null
  var vehicleLog = null
  var instructionConfirmed = false
  var vehicleConfirmed = false
  var startOdometer = null
  var preparationStarted = false
  var availableVehicles = []
  var busyVehicles = new Map()
  var assignedVehicleId = null
  var vehicleUsage = 'vehicle'
  var vehicleStepComplete = false
  var instructionReadAt = null
  var instructionSignatureEnabled = false
  var instructionSignatureHasInk = false
  var instructionSignatureSaved = false
  var instructionSignatureDraftData = null
  var renderedInstructionId = null
  var instructionOpenedRecorded = false
  var instructionPdfZoom = 140
  var instructionPdfPinchDistance = 0
  var instructionPdfPinchZoom = 140

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
    'cloud-sun': '<path d="M12 2v2"></path><path d="m4.93 4.93 1.42 1.42"></path><path d="M20 12h2"></path><path d="m19.07 4.93-1.42 1.42"></path><path d="M15 8a4 4 0 0 0-7.72 1.43"></path><path d="M17.5 18H9a5 5 0 1 1 4.9-6H15a3 3 0 0 1 2.5 6Z"></path>',
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
    var select = 'id,planning_date,title,vehicle_id,warehouse_id,start_latitude,start_longitude,execution_status,estimated_distance_km,estimated_drive_minutes,started_at,warehouse:warehouses(name,city,latitude,longitude),route_plan_stops(id,stop_order,status,title,address_snapshot,city_snapshot,latitude,longitude,machine_id,location_id)'
    var url = supabaseUrl + '/rest/v1/route_plans?select=' + encodeURIComponent(select)
      + '&planned_employee_id=eq.' + encodeURIComponent(employee.id)
      + '&planning_date=eq.' + encodeURIComponent(todayIso())
      + '&execution_status=neq.cancelled&order=created_at.desc&limit=1'
    return apiRequest(url, {}, 12000).then(function (rows) { return Array.isArray(rows) && rows.length ? rows[0] : null })
  }

  function loadVehicle(vehicleId) {
    var fields = 'id,name,plate,brand,model,current_odometer_km,warehouse_id,assigned_employee_id,active,image_path'
    var url = supabaseUrl + '/rest/v1/vehicles?select=' + encodeURIComponent(fields)
      + (vehicleId
        ? '&id=eq.' + encodeURIComponent(vehicleId)
        : '&assigned_employee_id=eq.' + encodeURIComponent(employee.id) + '&active=eq.true&order=id&limit=1')
    if (vehicleId) url += '&limit=1'
    return apiRequest(url, {}, 8000).then(function (rows) { return Array.isArray(rows) && rows.length ? rows[0] : null }).catch(function () { return null })
  }

  function loadVehicles() {
    var fields = 'id,name,plate,brand,model,current_odometer_km,warehouse_id,assigned_employee_id,active,image_path'
    var url = supabaseUrl + '/rest/v1/vehicles?select=' + encodeURIComponent(fields) + '&active=eq.true&order=name.asc,plate.asc'
    return apiRequest(url, {}, 9000).then(function (rows) { return Array.isArray(rows) ? rows : [] }).catch(function () { return [] })
  }

  function loadVehicleAvailability() {
    if (isShiftPreview()) return Promise.resolve(busyVehicles)
    var activeSince = new Date(Date.now() - 18 * 60 * 60 * 1000).toISOString()
    var attendanceUrl = supabaseUrl + '/rest/v1/attendance_days?select=id,employee_id,vehicle_id,actual_start,actual_end,status'
      + '&vehicle_id=not.is.null&actual_start=gte.' + encodeURIComponent(activeSince) + '&actual_end=is.null'
    var logsUrl = supabaseUrl + '/rest/v1/vehicle_operation_logs?select=vehicle_id,employee_id,status,started_at,ended_at'
      + '&status=eq.open&started_at=gte.' + encodeURIComponent(activeSince) + '&ended_at=is.null'
    return Promise.all([
      apiRequest(attendanceUrl, {}, 9000).catch(function () { return [] }),
      apiRequest(logsUrl, {}, 9000).catch(function () { return [] })
    ]).then(function (results) {
      var rows = (results[0] || []).concat(results[1] || [])
      var employeeIds = Array.from(new Set(rows.map(function (row) { return row.employee_id }).filter(Boolean)))
      if (!employeeIds.length) return { rows: rows, employees: [] }
      var directoryUrl = supabaseUrl + '/rest/v1/employee_directory?select=id,name,surname&id=in.(' + employeeIds.map(encodeURIComponent).join(',') + ')'
      return apiRequest(directoryUrl, {}, 9000).then(function (employees) {
        return { rows: rows, employees: employees || [] }
      }).catch(function () { return { rows: rows, employees: [] } })
    }).then(function (result) {
      var names = new Map((result.employees || []).map(function (person) {
        return [String(person.id), [person.name, person.surname].filter(Boolean).join(' ')]
      }))
      var map = new Map()
      ;(result.rows || []).forEach(function (row) {
        if (!row.vehicle_id) return
        var employeeId = String(row.employee_id || '')
        if (employee && employeeId === String(employee.id || '')) return
        map.set(String(row.vehicle_id), {
          employeeId: employeeId,
          employeeName: names.get(employeeId) || 'jiný operátor'
        })
      })
      busyVehicles = map
      return map
    })
  }

  function loadWarehouse() {
    var routeWarehouse = routePlan && routePlan.warehouse
    if (routeWarehouse && routeWarehouse.latitude != null && routeWarehouse.longitude != null) return Promise.resolve(routeWarehouse)
    var warehouseId = routePlan && routePlan.warehouse_id || vehicle && vehicle.warehouse_id
    if (!warehouseId) return Promise.resolve(null)
    var url = supabaseUrl + '/rest/v1/warehouses?select=id,name,city,latitude,longitude&id=eq.' + encodeURIComponent(warehouseId) + '&limit=1'
    return apiRequest(url, {}, 8000).then(function (rows) { return Array.isArray(rows) && rows.length ? rows[0] : null }).catch(function () { return null })
  }

  function loadWeather() {
    var usesRouteStart = Boolean(routePlan && routePlan.start_latitude != null && routePlan.start_longitude != null)
    var latitude = usesRouteStart ? Number(routePlan.start_latitude) : warehouse && Number(warehouse.latitude)
    var longitude = usesRouteStart ? Number(routePlan.start_longitude) : warehouse && Number(warehouse.longitude)
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return Promise.resolve(null)
    var routeWarehouse = routePlan && routePlan.warehouse
    var place = usesRouteStart
      ? routeWarehouse && (routeWarehouse.city || routeWarehouse.name) || 'Výchozí místo'
      : warehouse && (warehouse.city || warehouse.name) || 'Výchozí místo'
    return apiRequest(supabaseUrl + '/functions/v1/operator-weather', {
      method: 'POST',
      body: JSON.stringify({ latitude: latitude, longitude: longitude, place: place })
    }, 9000).catch(function () { return null })
  }

  function renderWeather(weather) {
    var weatherRow = root.querySelector('#operatorIdleWeatherRow')
    if (!weather || !Number.isFinite(Number(weather.temperature_c))) {
      weatherRow.hidden = true
      return
    }
    root.querySelector('#operatorIdleLocation').textContent = weather.place || warehouse && (warehouse.city || warehouse.name) || 'Výchozí místo'
    root.querySelector('#operatorIdleWeather').textContent = Math.round(Number(weather.temperature_c)).toLocaleString('cs-CZ') + ' °C, ' + String(weather.condition || 'proměnlivo')
    weatherRow.hidden = false
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

  function loadInstructionProgress() {
    instructionReadAt = null
    instructionSignatureSaved = false
    instructionSignatureDraftData = null
    if (!instruction || !employee || !employee.id) return Promise.resolve()
    var url = supabaseUrl + '/rest/v1/instruction_events?select=event_type,event_at,signature_data_url&instruction_id=eq.' + encodeURIComponent(instruction.id)
      + '&employee_id=eq.' + encodeURIComponent(employee.id) + '&event_type=in.(document_read,signature_captured)'
    return apiRequest(url, {}, 8000).then(function (rows) {
      ;(Array.isArray(rows) ? rows : []).forEach(function (row) {
        if (row.event_type === 'document_read') instructionReadAt = row.event_at || new Date().toISOString()
        if (row.event_type === 'signature_captured' && row.signature_data_url) {
          instructionSignatureSaved = true
          instructionSignatureDraftData = row.signature_data_url
        }
      })
    }).catch(function () {})
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

  function currentInstructionPayload() {
    return instruction && instruction.instruction_payload && typeof instruction.instruction_payload === 'object'
      ? instruction.instruction_payload
      : {}
  }

  function instructionRequiresSignature() {
    var value = currentInstructionPayload().requiresSignature
    return value === true || String(value || '').toLowerCase() === 'true'
  }

  function instructionDeviceInfo() {
    return {
      app: 'OLVEND Operátor',
      appVersion: '20261117-signed-instruction-v1',
      userAgent: navigator.userAgent || '',
      platform: navigator.platform || '',
      screenWidth: window.screen && window.screen.width || null,
      screenHeight: window.screen && window.screen.height || null,
      viewportWidth: window.innerWidth || null,
      viewportHeight: window.innerHeight || null,
      online: navigator.onLine !== false,
      timezone: (function () {
        try { return Intl.DateTimeFormat().resolvedOptions().timeZone || 'Europe/Prague' } catch (_) { return 'Europe/Prague' }
      })()
    }
  }

  function recordInstructionEvent(eventType) {
    if (!instruction || isShiftPreview()) return Promise.resolve(true)
    var payload = currentInstructionPayload()
    return apiRequest(supabaseUrl + '/rest/v1/rpc/record_instruction_event', {
      method: 'POST',
      body: JSON.stringify({
        p_instruction_id: instruction.id,
        p_event_type: eventType,
        p_document_version: payload.documentVersion || null,
        p_document_sha256: payload.documentSha256 || null,
        p_device_info: instructionDeviceInfo()
      })
    }, 10000)
  }

  function saveInstructionSignatureDraft(signatureDataUrl) {
    if (!instruction) return Promise.reject(new Error('Pokyn není načtený.'))
    if (isShiftPreview()) return Promise.resolve(true)
    var payload = currentInstructionPayload()
    return apiRequest(supabaseUrl + '/rest/v1/rpc/save_instruction_signature', {
      method: 'POST',
      body: JSON.stringify({
        p_instruction_id: instruction.id,
        p_signature_data_url: signatureDataUrl || null,
        p_document_version: payload.documentVersion || null,
        p_document_sha256: payload.documentSha256 || null,
        p_device_info: instructionDeviceInfo()
      })
    }, 12000)
  }

  function resetInstructionSignature(clearSaved) {
    var canvas = root.querySelector('#operatorInstructionSignaturePad')
    if (canvas && canvas.getContext) canvas.getContext('2d').clearRect(0, 0, canvas.width, canvas.height)
    instructionSignatureHasInk = false
    if (clearSaved !== false) {
      instructionSignatureSaved = false
      instructionSignatureDraftData = null
    }
    var placeholder = root.querySelector('#operatorInstructionSignaturePlaceholder')
    if (placeholder) placeholder.style.display = 'flex'
  }

  function restoreInstructionSignatureDraft() {
    if (!instructionSignatureDraftData) return
    var canvas = root.querySelector('#operatorInstructionSignaturePad')
    var image = new Image()
    image.onload = function () {
      canvas.getContext('2d').clearRect(0, 0, canvas.width, canvas.height)
      canvas.getContext('2d').drawImage(image, 0, 0, canvas.width, canvas.height)
      instructionSignatureHasInk = true
      instructionSignatureSaved = true
      root.querySelector('#operatorInstructionSignaturePlaceholder').style.display = 'none'
      renderInstructionStep()
    }
    image.src = instructionSignatureDraftData
  }

  function renderInstructionStep() {
    if (!instruction) return
    var payload = currentInstructionPayload()
    var hasAttachment = Boolean(instruction.attachment_url)
    var requiresSignature = instructionRequiresSignature()
    var pdfStep = root.querySelector('#operatorInstructionPdfStep')
    var signatureStep = root.querySelector('#operatorInstructionSignatureStep')
    var confirm = root.querySelector('#operatorInstructionConfirm')
    var error = root.querySelector('#operatorInstructionError')

    if (String(renderedInstructionId || '') !== String(instruction.id)) {
      renderedInstructionId = instruction.id
      instructionOpenedRecorded = false
      instructionSignatureEnabled = !hasAttachment
      resetInstructionSignature(false)
      if (instructionSignatureDraftData) restoreInstructionSignatureDraft()
    }

    root.querySelector('#operatorInstructionTitle').textContent = instruction.title || 'Pokyn dne'
    root.querySelector('#operatorInstructionBody').textContent = instruction.message || 'Přečtěte si pokyn a potvrďte jeho převzetí.'
    root.querySelector('#operatorInstructionNoticeText').textContent = payload.warningText || 'Potvrzení se uloží do databáze společně s časem a údaji zařízení.'
    error.hidden = true
    error.textContent = ''

    pdfStep.hidden = !hasAttachment
    signatureStep.hidden = !requiresSignature
    if (hasAttachment) {
      var pageCount = Number(payload.pageCount || 0)
      root.querySelector('#operatorInstructionAttachmentLabel').textContent = instruction.attachment_label || 'Přiložený dokument'
      root.querySelector('#operatorInstructionAttachmentMeta').textContent = (pageCount ? pageCount + (pageCount === 1 ? ' strana' : pageCount < 5 ? ' strany' : ' stran') + ' · ' : 'PDF · ') + (requiresSignature ? 'podpis je povinný' : 'vyžaduje přečtení')
      pdfStep.classList.toggle('done', Boolean(instructionReadAt))
      root.querySelector('#operatorInstructionPdfNumber').textContent = instructionReadAt ? '✓' : '1'
      root.querySelector('#operatorInstructionOpenPdf').textContent = instructionReadAt ? 'Přečteno ✓' : 'Otevřít PDF'
      root.querySelector('#operatorInstructionOpenPdf').className = 'operator-instruction-pdf-open' + (instructionReadAt ? ' read' : '')
    }

    if (requiresSignature) {
      instructionSignatureEnabled = !hasAttachment || Boolean(instructionReadAt)
      signatureStep.classList.toggle('locked', !instructionSignatureEnabled)
      signatureStep.classList.toggle('done', instructionSignatureSaved)
      root.querySelector('#operatorInstructionSignatureNumber').textContent = instructionSignatureSaved ? '✓' : hasAttachment ? '2' : '1'
      root.querySelector('#operatorInstructionSignatureHint').textContent = instructionSignatureSaved ? 'Podpis je uložený a připravený k potvrzení.' : instructionSignatureEnabled ? 'Podepište se prstem do pole níže.' : 'Tento krok se odemkne po přečtení PDF.'
      var canvas = root.querySelector('#operatorInstructionSignaturePad')
      canvas.className = 'operator-signature-pad' + (instructionSignatureEnabled ? '' : ' locked')
      var placeholder = root.querySelector('#operatorInstructionSignaturePlaceholder')
      if (!instructionSignatureHasInk) {
        placeholder.style.display = 'flex'
        placeholder.textContent = instructionSignatureEnabled ? 'Podepište se prstem do pole' : 'Nejprve dokončete krok 1'
      }
      root.querySelector('#operatorInstructionSignatureStatus').textContent = instructionSignatureSaved
        ? 'Podpis uložen · připraven k potvrzení'
        : instructionSignatureHasInk ? 'Podpis změněn · dokončete tah pro uložení'
        : instructionSignatureEnabled ? 'PDF přečteno · čeká na podpis' : 'Podpis je vyžadován'
      root.querySelector('#operatorInstructionSignatureClear').disabled = !instructionSignatureEnabled
    }

    confirm.textContent = requiresSignature ? 'Podepsat a potvrdit pokyn →' : 'Přečetl/a jsem a rozumím →'
    confirm.disabled = Boolean((hasAttachment && !instructionReadAt) || (requiresSignature && !instructionSignatureSaved))

    if (!root.querySelector('#operatorInstructionStep').hidden && !instructionOpenedRecorded) {
      instructionOpenedRecorded = true
      recordInstructionEvent('instruction_opened').catch(function () {})
    }
  }

  function clampInstructionPdfZoom(value) {
    return Math.max(100, Math.min(300, Math.round(Number(value) || 100)))
  }

  function applyInstructionPdfZoom(value, preservePosition) {
    var viewer = root.querySelector('#operatorInstructionPdfViewer')
    var pages = viewer.querySelectorAll('.operator-pdf-page')
    if (!pages.length) return
    var oldWidth = Math.max(viewer.scrollWidth, viewer.clientWidth, 1)
    var centerRatio = (viewer.scrollLeft + viewer.clientWidth / 2) / oldWidth
    instructionPdfZoom = clampInstructionPdfZoom(value)
    var availableWidth = Math.max(240, viewer.clientWidth - 28)
    var targetWidth = Math.round(availableWidth * instructionPdfZoom / 100)
    Array.prototype.forEach.call(pages, function (page) { page.style.width = targetWidth + 'px' })
    root.querySelector('#operatorInstructionPdfZoomValue').textContent = instructionPdfZoom + ' %'
    if (preservePosition === false) viewer.scrollLeft = Math.max(0, (viewer.scrollWidth - viewer.clientWidth) / 2)
    else viewer.scrollLeft = Math.max(0, centerRatio * viewer.scrollWidth - viewer.clientWidth / 2)
  }

  function changeInstructionPdfZoom(delta) {
    applyInstructionPdfZoom(instructionPdfZoom + delta, true)
  }

  function fitInstructionPdfWidth() {
    applyInstructionPdfZoom(100, false)
    root.querySelector('#operatorInstructionPdfViewer').scrollLeft = 0
  }

  function instructionPdfTouchDistance(event) {
    if (!event.touches || event.touches.length < 2) return 0
    var x = event.touches[0].clientX - event.touches[1].clientX
    var y = event.touches[0].clientY - event.touches[1].clientY
    return Math.sqrt(x * x + y * y)
  }

  function beginInstructionPdfPinch(event) {
    if (!event.touches || event.touches.length !== 2) return
    instructionPdfPinchDistance = instructionPdfTouchDistance(event)
    instructionPdfPinchZoom = instructionPdfZoom
  }

  function moveInstructionPdfPinch(event) {
    if (!instructionPdfPinchDistance || !event.touches || event.touches.length !== 2) return
    event.preventDefault()
    var distance = instructionPdfTouchDistance(event)
    applyInstructionPdfZoom(instructionPdfPinchZoom * distance / instructionPdfPinchDistance, true)
  }

  function endInstructionPdfPinch(event) {
    if (!event.touches || event.touches.length < 2) instructionPdfPinchDistance = 0
  }

  function renderInstructionPdf() {
    var payload = currentInstructionPayload()
    var pages = Array.isArray(payload.previewPages) ? payload.previewPages : []
    var viewer = root.querySelector('#operatorInstructionPdfViewer')
    viewer.innerHTML = ''
    if (pages.length) {
      var stage = document.createElement('div')
      stage.className = 'operator-pdf-stage'
      pages.forEach(function (src, index) {
        var image = document.createElement('img')
        image.className = 'operator-pdf-page'
        image.src = src
        image.alt = 'Strana ' + (index + 1) + ' dokumentu'
        image.draggable = false
        image.addEventListener('load', function () { applyInstructionPdfZoom(instructionPdfZoom, false) })
        stage.appendChild(image)
      })
      viewer.appendChild(stage)
    } else {
      var fallback = document.createElement('div')
      fallback.className = 'operator-pdf-fallback'
      fallback.textContent = 'Náhled tohoto dokumentu není v zařízení dostupný.'
      var link = document.createElement('a')
      link.href = instruction.attachment_url
      link.target = '_blank'
      link.rel = 'noopener noreferrer'
      link.textContent = 'Otevřít PDF samostatně'
      fallback.appendChild(link)
      viewer.appendChild(fallback)
    }
    root.querySelector('#operatorInstructionPdfTitle').textContent = instruction.attachment_label || 'Přiložený dokument'
    var pageCount = Number(payload.pageCount || pages.length || 0)
    root.querySelector('#operatorInstructionPdfMeta').textContent = pageCount ? 'Náhled dokumentu · ' + pageCount + (pageCount === 1 ? ' strana' : ' stran') : 'Náhled dokumentu'
    instructionPdfZoom = 140
    root.querySelector('#operatorInstructionPdfZoomValue').textContent = instructionPdfZoom + ' %'
    viewer.scrollTop = 0
    viewer.scrollLeft = 0
    window.setTimeout(function () { applyInstructionPdfZoom(140, false) }, 0)
  }

  function openInstructionPdf() {
    if (!instruction || !instruction.attachment_url) return
    root.querySelector('#operatorInstructionPdfModal').hidden = false
    renderInstructionPdf()
    recordInstructionEvent('attachment_opened').catch(function () {})
  }

  function markInstructionDocumentRead() {
    var button = root.querySelector('#operatorInstructionPdfRead')
    var error = root.querySelector('#operatorInstructionError')
    button.disabled = true
    button.textContent = 'Ukládám přečtení…'
    recordInstructionEvent('document_read').then(function () {
      instructionReadAt = new Date().toISOString()
      root.querySelector('#operatorInstructionPdfModal').hidden = true
      renderInstructionStep()
    }).catch(function (cause) {
      error.textContent = cause && cause.message ? cause.message : 'Přečtení dokumentu se nepodařilo uložit.'
      error.hidden = false
      root.querySelector('#operatorInstructionPdfModal').hidden = true
    }).then(function () {
      button.disabled = false
      button.textContent = 'Dokument jsem přečetl/a'
    })
  }

  function instructionSignaturePoint(event) {
    var canvas = root.querySelector('#operatorInstructionSignaturePad')
    var rect = canvas.getBoundingClientRect()
    var source = event.touches && event.touches[0] ? event.touches[0] : event
    return {
      x: (source.clientX - rect.left) * (canvas.width / rect.width),
      y: (source.clientY - rect.top) * (canvas.height / rect.height)
    }
  }

  function beginInstructionSignature(event) {
    if (!instructionSignatureEnabled) return
    event.preventDefault()
    var canvas = root.querySelector('#operatorInstructionSignaturePad')
    var point = instructionSignaturePoint(event)
    var context = canvas.getContext('2d')
    canvas.setAttribute('data-drawing', '1')
    context.beginPath()
    context.moveTo(point.x, point.y)
    root.querySelector('#operatorInstructionSignaturePlaceholder').style.display = 'none'
  }

  function moveInstructionSignature(event) {
    var canvas = root.querySelector('#operatorInstructionSignaturePad')
    if (!instructionSignatureEnabled || canvas.getAttribute('data-drawing') !== '1') return
    event.preventDefault()
    var point = instructionSignaturePoint(event)
    var context = canvas.getContext('2d')
    context.lineWidth = 2.6
    context.lineCap = 'round'
    context.lineJoin = 'round'
    context.strokeStyle = '#18202a'
    context.lineTo(point.x, point.y)
    context.stroke()
    instructionSignatureHasInk = true
    instructionSignatureSaved = false
    instructionSignatureDraftData = null
    var signatureStep = root.querySelector('#operatorInstructionSignatureStep')
    signatureStep.classList.remove('done')
    root.querySelector('#operatorInstructionSignatureNumber').textContent = instruction.attachment_url ? '2' : '1'
    root.querySelector('#operatorInstructionSignatureStatus').textContent = 'Podpis změněn · dokončete tah pro uložení'
    root.querySelector('#operatorInstructionConfirm').disabled = true
  }

  function endInstructionSignature() {
    var canvas = root.querySelector('#operatorInstructionSignaturePad')
    if (!canvas || canvas.getAttribute('data-drawing') !== '1') return
    canvas.removeAttribute('data-drawing')
    if (!instructionSignatureHasInk) return
    var signatureDataUrl = canvas.toDataURL('image/png')
    var status = root.querySelector('#operatorInstructionSignatureStatus')
    var error = root.querySelector('#operatorInstructionError')
    status.textContent = 'Ukládám podpis…'
    saveInstructionSignatureDraft(signatureDataUrl).then(function () {
      instructionSignatureSaved = true
      instructionSignatureDraftData = signatureDataUrl
      renderInstructionStep()
    }).catch(function (cause) {
      instructionSignatureSaved = false
      root.querySelector('#operatorInstructionConfirm').disabled = true
      status.textContent = 'Podpis se nepodařilo uložit'
      error.textContent = cause && cause.message ? cause.message : 'Podpis se nepodařilo uložit do databáze.'
      error.hidden = false
    })
  }

  function clearInstructionSignature() {
    resetInstructionSignature()
    renderInstructionStep()
    root.querySelector('#operatorInstructionSignatureStatus').textContent = 'Mažu uložený podpis…'
    saveInstructionSignatureDraft(null).then(function () {
      renderInstructionStep()
    }).catch(function (cause) {
      var error = root.querySelector('#operatorInstructionError')
      error.textContent = cause && cause.message ? cause.message : 'Uložený podpis se nepodařilo vymazat.'
      error.hidden = false
    })
  }

  function confirmInstructionStep() {
    if (!instruction) return
    var payload = currentInstructionPayload()
    var requiresSignature = instructionRequiresSignature()
    var hasAttachment = Boolean(instruction.attachment_url)
    var error = root.querySelector('#operatorInstructionError')
    var button = root.querySelector('#operatorInstructionConfirm')
    error.hidden = true
    if (hasAttachment && !instructionReadAt) {
      error.textContent = 'Nejdříve otevřete a potvrďte přečtení PDF.'
      error.hidden = false
      return
    }
    if (requiresSignature && !instructionSignatureSaved) {
      error.textContent = 'Nejdříve dokončete uložení podpisu.'
      error.hidden = false
      return
    }
    var signature = requiresSignature ? root.querySelector('#operatorInstructionSignaturePad').toDataURL('image/png') : null
    button.disabled = true
    button.textContent = 'Ukládám podpis a potvrzení…'
    var save = isShiftPreview() ? Promise.resolve(true) : apiRequest(supabaseUrl + '/rest/v1/rpc/confirm_signed_instruction', {
      method: 'POST',
      body: JSON.stringify({
        p_instruction_id: instruction.id,
        p_signature_data_url: signature,
        p_document_read_at: instructionReadAt,
        p_document_version: payload.documentVersion || null,
        p_document_sha256: payload.documentSha256 || null,
        p_device_info: instructionDeviceInfo()
      })
    }, 15000)
    save.then(function () {
      button.textContent = 'Pokyn uložen ✓'
      button.style.background = '#067647'
      button.style.borderColor = '#067647'
      window.setTimeout(function () {
        instructionConfirmed = true
        setConfirmed(true)
        renderData()
      }, 550)
    }).catch(function (cause) {
      button.disabled = false
      button.textContent = requiresSignature ? 'Podepsat a potvrdit pokyn →' : 'Přečetl/a jsem a rozumím →'
      error.textContent = cause && cause.message ? cause.message : 'Podpis a potvrzení se nepodařilo uložit.'
      error.hidden = false
    })
  }

  function isShiftRunning() {
    return Boolean((attendanceDay && attendanceDay.actual_start && !attendanceDay.actual_end) || (routePlan && routePlan.execution_status === 'in_progress'))
  }

  function vehicleKey() {
    return 'olvendOperatorVehicleV2:' + todayIso() + ':' + (employee && employee.id || '') + ':' + (vehicle && vehicle.id || '') + ':' + (routePlan && routePlan.id || '')
  }

  function vehicleChoiceKey() {
    return 'olvendOperatorVehicleChoiceV1:' + todayIso() + ':' + (employee && employee.id || '') + ':' + (routePlan && routePlan.id || '')
  }

  function normalizePlate(value) {
    return String(value || '').toLocaleUpperCase('cs-CZ').replace(/[^A-Z0-9]/g, '')
  }

  function formatPlate(value) {
    var plate = normalizePlate(value)
    return plate.length > 3 ? plate.slice(0, 3) + ' ' + plate.slice(3) : plate || '—'
  }

  function formatOdometer(value) {
    var number = Number(value)
    return Number.isFinite(number) ? Math.round(number).toLocaleString('cs-CZ') : '—'
  }

  function escapeHtml(value) {
    return String(value == null ? '' : value).replace(/[&<>"']/g, function (character) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[character]
    })
  }

  function parseOdometer(value) {
    var digits = String(value || '').replace(/[^0-9]/g, '')
    return digits ? Number(digits) : NaN
  }

  function vehicleImagePath(item) {
    var path = String(item && item.image_path || '').trim()
    if (path.indexOf('static:') === 0) path = path.slice(7)
    if (!/^\.\.\/assets\/vehicles\/[a-z0-9._-]+$/i.test(path)) return ''
    return path + '?v=20261117-vehicle-db-v1'
  }

  function vehicleFallbackMarkup() {
    return '<span class="operator-vehicle-fallback" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m5 17-2 2M19 17l2 2M5 9l1.5-4h11L19 9M3 11h18v6H3z"/><circle cx="7" cy="14" r="1"/><circle cx="17" cy="14" r="1"/></svg></span>'
  }

  function setVehicleChoice(item) {
    vehicle = item || null
    vehicleUsage = 'vehicle'
    vehicleConfirmed = false
    vehicleStepComplete = false
    startOdometer = vehicle && Number(vehicle.current_odometer_km || 0)
    renderVehicleStep()
  }

  function saveVehicleChoice(mode) {
    var payload = mode === 'without'
      ? { mode: 'without', confirmed: true, confirmedAt: new Date().toISOString() }
      : { mode: 'vehicle', confirmed: true, vehicleId: vehicle && vehicle.id, odometer: startOdometer, confirmedAt: new Date().toISOString() }
    localStorage.setItem(vehicleChoiceKey(), JSON.stringify(payload))
    if (mode === 'vehicle' && vehicle) localStorage.setItem(vehicleKey(), JSON.stringify({ confirmed: true, odometer: startOdometer, confirmedAt: payload.confirmedAt }))
  }

  function readVehicleConfirmation() {
    if (vehicleLog && vehicleLog.start_odometer_km != null) {
      vehicleUsage = 'vehicle'
      vehicleConfirmed = true
      vehicleStepComplete = true
      startOdometer = Number(vehicleLog.start_odometer_km)
      return
    }
    try {
      var choice = JSON.parse(localStorage.getItem(vehicleChoiceKey()) || 'null')
      if (choice && choice.confirmed && choice.mode === 'without') {
        vehicleUsage = 'without'
        vehicleConfirmed = true
        vehicleStepComplete = true
        startOdometer = null
        return
      }
      if (choice && choice.confirmed && choice.mode === 'vehicle') {
        var selected = availableVehicles.find(function (item) { return String(item.id) === String(choice.vehicleId) })
        if (selected) vehicle = selected
        vehicleUsage = 'vehicle'
        vehicleConfirmed = Boolean(vehicle)
        vehicleStepComplete = vehicleConfirmed
        startOdometer = Number(choice.odometer)
        if (vehicleConfirmed && Number.isFinite(startOdometer)) return
      }
      var stored = JSON.parse(localStorage.getItem(vehicleKey()) || 'null')
      vehicleUsage = 'vehicle'
      vehicleConfirmed = Boolean(stored && stored.confirmed)
      vehicleStepComplete = vehicleConfirmed
      startOdometer = stored && Number(stored.odometer)
    } catch (_) {
      vehicleUsage = 'vehicle'
      vehicleConfirmed = false
      vehicleStepComplete = false
      startOdometer = null
    }
  }

  function setVehiclePicker(open) {
    var picker = root.querySelector('#operatorVehiclePicker')
    picker.hidden = !open
    if (open) renderVehiclePicker()
  }

  function renderVehiclePicker() {
    var list = root.querySelector('#operatorVehicleList')
    list.innerHTML = ''
    var sorted = availableVehicles.filter(function (item) { return item.active !== false }).sort(function (a, b) {
      var aAssigned = String(a.id) === String(assignedVehicleId)
      var bAssigned = String(b.id) === String(assignedVehicleId)
      if (aAssigned !== bAssigned) return aAssigned ? -1 : 1
      return String(a.name || '').localeCompare(String(b.name || ''), 'cs')
    })
    if (!sorted.length) {
      list.innerHTML = '<div class="operator-vehicle-empty">V evidenci zatím není žádné vozidlo.</div>'
      return
    }
    sorted.forEach(function (item) {
      var busy = busyVehicles.get(String(item.id))
      var blocked = item.active === false || Boolean(busy)
      var assigned = String(item.id) === String(assignedVehicleId)
      var button = document.createElement('button')
      button.className = 'operator-vehicle-option'
      button.type = 'button'
      button.disabled = blocked
      if (blocked) button.style.opacity = '.52'
      var art = vehicleImagePath(item)
      var visual = art ? '<img src="' + art + '" alt="">' : vehicleFallbackMarkup()
      var state = item.active === false
        ? 'Mimo provoz · nelze vybrat'
        : busy
          ? 'Používá ' + busy.employeeName + ' · nelze vybrat'
          : assigned
            ? 'Přiřazené pro dnešní trasu · ' + formatOdometer(item.current_odometer_km) + ' km'
            : 'Dostupné · ' + formatOdometer(item.current_odometer_km) + ' km'
      button.innerHTML = visual + '<div><strong>' + escapeHtml(item.name || 'Vozidlo') + '</strong><span>' + escapeHtml(state) + '</span></div><b class="operator-vehicle-mini-plate">' + escapeHtml(formatPlate(item.plate)) + '</b>'
      if (!blocked) button.addEventListener('click', function () {
        setVehicleChoice(item)
        setVehiclePicker(false)
      })
      list.appendChild(button)
    })
  }

  function renderVehicleStep() {
    var visual = root.querySelector('#operatorVehicleVisual')
    var field = root.querySelector('.operator-vehicle-field')
    var confirm = root.querySelector('#operatorVehicleConfirm')
    var error = root.querySelector('#operatorVehicleError')
    error.hidden = true
    error.textContent = ''
    if (!vehicle) {
      visual.innerHTML = vehicleFallbackMarkup()
      root.querySelector('#operatorVehicleAssignment').textContent = 'Vozidlo není přiřazené'
      root.querySelector('#operatorVehicleName').textContent = 'Vyberte vozidlo'
      root.querySelector('#operatorVehiclePlateNumber').textContent = '—'
      root.querySelector('#operatorVehiclePlate').setAttribute('aria-label', 'Registrační značka není vybraná')
      field.hidden = true
      confirm.disabled = true
      return
    }
    var art = vehicleImagePath(vehicle)
    visual.innerHTML = art ? '<img src="' + art + '" alt="' + escapeHtml(vehicle.name || 'Vozidlo') + '">' : vehicleFallbackMarkup()
    root.querySelector('#operatorVehicleAssignment').textContent = String(vehicle.id) === String(assignedVehicleId) ? 'Přiřazené vozidlo' : 'Vybrané vozidlo'
    root.querySelector('#operatorVehicleName').textContent = vehicle.name || [vehicle.brand, vehicle.model].filter(Boolean).join(' ') || 'Vozidlo'
    root.querySelector('#operatorVehiclePlateNumber').textContent = formatPlate(vehicle.plate)
    root.querySelector('#operatorVehiclePlate').setAttribute('aria-label', 'Registrační značka ' + formatPlate(vehicle.plate))
    field.hidden = false
    confirm.disabled = false
    var odometer = startOdometer != null && Number.isFinite(Number(startOdometer)) ? Number(startOdometer) : Number(vehicle.current_odometer_km || 0)
    root.querySelector('#operatorVehicleOdometer').value = formatOdometer(odometer)
    root.querySelector('#operatorVehicleLastOdometer').textContent = formatOdometer(vehicle.current_odometer_km || 0) + ' km'
  }

  function proceedFromVehicleStep() {
    vehicleStepComplete = true
    updateReadiness()
  }

  function updateReadiness() {
    var start = root.querySelector('#ot-start')
    var help = root.querySelector('#ot-start-help')
    var running = isShiftRunning()
    var idleStart = root.querySelector('#operatorIdleStart')
    var vehicleStep = root.querySelector('#operatorVehicleStep')
    var instructionStep = root.querySelector('#operatorInstructionStep')
    var operationalHome = root.querySelector('.ot-phone')
    var showIdleStart = !running && !preparationStarted
    var showVehicleStep = !running && preparationStarted && !vehicleStepComplete
    var showInstructionStep = !running && preparationStarted && vehicleStepComplete && Boolean(instruction && !instructionConfirmed)
    idleStart.hidden = !showIdleStart
    vehicleStep.hidden = !showVehicleStep
    instructionStep.hidden = !showInstructionStep
    operationalHome.hidden = showIdleStart || showVehicleStep || showInstructionStep
    if (showInstructionStep) renderInstructionStep()
    var hasVehicleChoice = vehicleUsage === 'without' || Boolean(vehicle)
    var ready = running || Boolean(routePlan && hasVehicleChoice && vehicleConfirmed && (!instruction || instructionConfirmed))
    start.disabled = !ready
    if (running) {
      start.innerHTML = 'Pokračovat v trase <span data-lucide="arrow-right" aria-hidden="true"></span>'
      help.hidden = true
    } else if (ready) {
      start.innerHTML = 'Zahájit směnu <span data-lucide="arrow-right" aria-hidden="true"></span>'
      help.hidden = true
    } else {
      var reason = !routePlan ? 'Čeká na dnešní trasu' : !hasVehicleChoice ? 'Čeká na volbu vozidla' : !vehicleConfirmed ? 'Nejdřív potvrď vozidlo a km' : 'Nejdřív přečti dnešní pokyn'
      start.innerHTML = '<span data-lucide="lock-keyhole" aria-hidden="true"></span><span>' + reason + '</span>'
      help.hidden = false
      help.textContent = !routePlan ? 'Vedoucí zatím nepřiřadil dnešní trasu.'
          : !hasVehicleChoice ? 'Vyber vozidlo nebo potvrď, že ho dnes nebudeš používat.'
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
    var employeeName = [employee.name, employee.surname].filter(Boolean).join(' ')
    var employeeInitials = [employee.name, employee.surname].filter(Boolean).map(function (part) { return String(part).charAt(0) }).join('').slice(0, 2).toLocaleUpperCase('cs-CZ') || 'OP'
    root.querySelector('#operatorIdleDate').textContent = formatDateLong()
    root.querySelector('#operatorIdleGreeting').textContent = (new Date().getHours() < 12 ? 'Dobré ráno' : 'Dobrý den') + (salutation ? ', ' + salutation : '')
    root.querySelector('#operatorIdleUser').textContent = employeeInitials
    root.querySelector('#operatorIdleUser').setAttribute('aria-label', employeeName ? 'Otevřít nabídku účtu ' + employeeName : 'Otevřít nabídku účtu')
    root.querySelector('#operatorVehicleUser').textContent = employeeInitials
    root.querySelector('#operatorVehicleUser').setAttribute('aria-label', employeeName ? 'Otevřít nabídku účtu ' + employeeName : 'Otevřít nabídku účtu')
    root.querySelector('#operatorInstructionUser').textContent = employeeInitials
    root.querySelector('#operatorInstructionUser').setAttribute('aria-label', employeeName ? 'Otevřít nabídku účtu ' + employeeName : 'Otevřít nabídku účtu')
    root.querySelector('#operatorIdleAccountInitials').textContent = employeeInitials
    root.querySelector('#operatorIdleAccountName').textContent = employeeName || 'Přihlášený operátor'
    root.querySelector('#operatorIdleAccountRole').textContent = String(employee.role || '').toLowerCase() === 'operator' ? 'Operátor' : (employee.role || 'Uživatel OLVEND')
    if (isShiftPreview()) renderWeather({ place: 'Blučina', temperature_c: 7, condition: 'zataženo' })
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
    vehicleTile.querySelector('h3').textContent = vehicleConfirmed ? (vehicleUsage === 'without' ? '1. Bez vozidla' : '1. Vozidlo potvrzeno') : '1. Potvrď vozidlo a km'
    vehicleTile.querySelector('p').textContent = vehicleUsage === 'without'
      ? 'Dnes vozidlo nepoužíváte'
      : vehicle
      ? [vehicle.name || 'Přiřazené vozidlo', vehicle.plate || 'Bez RZ', vehicleConfirmed && startOdometer != null ? Number(startOdometer).toLocaleString('cs-CZ') + ' km' : ''].filter(Boolean).join(' · ')
      : 'Vozidlo zatím není přiřazeno'
    vehicleTile.querySelector('strong').textContent = vehicleConfirmed ? 'Hotovo ✓' : vehicle ? 'Potvrdit ›' : 'Nevybráno'
    var instructionTile = root.querySelector('#ot-instructions')
    instructionTile.querySelector('h3').textContent = !instruction ? '2. Dnes bez nového pokynu' : instructionConfirmed ? '2. Pokyn přečten' : '2. Přečti dnešní pokyn'
    instructionTile.querySelector('p').textContent = !instruction ? 'Není potřeba nic potvrzovat' : instructionConfirmed ? (instruction.title || 'Povinný pokyn potvrzen') : (instruction.title || 'Krátká informace před výjezdem')
    root.querySelector('#ot-guide-progress').textContent = (Number(vehicleConfirmed) + Number(!instruction || instructionConfirmed)) + ' ze 2 hotovo'
    root.querySelector('.ot-brand-copy span').textContent = vehicleUsage === 'without' ? 'Před směnou · bez vozidla' : vehicle ? 'Před směnou · ' + (vehicle.plate || vehicle.name || 'vozidlo') : 'Před zahájením směny'
    if (instruction) {
      root.querySelector('.ot-sheet-title h3').textContent = instruction.title || instruction.name || 'Povinný pokyn dne'
      root.querySelector('.ot-instruction').textContent = instruction.body || instruction.content || instruction.message || instruction.note || 'Přečtěte si pokyn a potvrďte jeho převzetí.'
      renderInstructionStep()
    }
    renderVehicleStep()
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

  function openVehicleStep() {
    preparationStarted = true
    vehicleStepComplete = false
    renderVehicleStep()
    updateReadiness()
  }

  function confirmVehicleStep() {
    var error = root.querySelector('#operatorVehicleError')
    error.hidden = true
    error.textContent = ''
    if (!vehicle) {
      error.textContent = 'Nejdřív vyberte vozidlo.'
      error.hidden = false
      return
    }
    var value = parseOdometer(root.querySelector('#operatorVehicleOdometer').value)
    var minimum = Number(vehicle.current_odometer_km || 0)
    if (!Number.isFinite(value) || value < minimum) {
      error.textContent = 'Stav kilometrů nesmí být nižší než poslední evidovaný stav ' + formatOdometer(minimum) + ' km.'
      error.hidden = false
      return
    }
    var button = root.querySelector('#operatorVehicleConfirm')
    button.disabled = true
    button.textContent = 'Ověřuji dostupnost…'
    loadVehicleAvailability().then(function () {
      var busy = busyVehicles.get(String(vehicle.id))
      if (vehicle.active === false || busy) {
        throw new Error(vehicle.active === false ? 'Toto vozidlo je mimo provoz.' : 'Vozidlo už používá ' + busy.employeeName + '. Vyberte jiné vozidlo.')
      }
      vehicleUsage = 'vehicle'
      startOdometer = Math.round(value)
      vehicleConfirmed = true
      vehicleStepComplete = true
      saveVehicleChoice('vehicle')
      renderData()
    }).catch(function (cause) {
      error.textContent = cause && cause.message ? cause.message : 'Dostupnost vozidla se nepodařilo ověřit.'
      error.hidden = false
      renderVehiclePicker()
    }).then(function () {
      button.disabled = false
      button.textContent = 'Potvrdit vozidlo a pokračovat →'
    })
  }

  function continueWithoutVehicle() {
    vehicleUsage = 'without'
    startOdometer = null
    vehicleConfirmed = true
    vehicleStepComplete = true
    saveVehicleChoice('without')
    renderData()
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
    var usesVehicle = vehicleUsage !== 'without'
    if (!routePlan || (usesVehicle && !vehicle) || !vehicleConfirmed || (instruction && !instructionConfirmed)) {
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
      vehicle_id: usesVehicle && vehicle ? vehicle.id : null,
      start_warehouse_id: usesVehicle && vehicle ? vehicle.warehouse_id || null : routePlan.warehouse_id || null
    }
    var availabilityCheck = usesVehicle ? loadVehicleAvailability().then(function () {
      var busy = busyVehicles.get(String(vehicle.id))
      if (vehicle.active === false || busy) throw new Error(vehicle.active === false ? 'Vybrané vozidlo je mimo provoz.' : 'Vybrané vozidlo už používá ' + busy.employeeName + '. Vraťte se a vyberte jiné vozidlo.')
    }) : Promise.resolve()
    availabilityCheck.then(function () { return apiRequest(supabaseUrl + '/rest/v1/attendance_days?on_conflict=employee_id,attendance_date', {
      method: 'POST',
      headers: { 'Prefer': 'resolution=merge-duplicates,return=representation' },
      body: JSON.stringify(attendancePayload)
    }, 12000) }).then(function (rows) {
      attendanceDay = Array.isArray(rows) ? rows[0] : rows
      if (!attendanceDay || !attendanceDay.id) throw new Error('Směna se nepodařila založit.')
      return apiRequest(supabaseUrl + '/rest/v1/attendance_events', {
        method: 'POST',
        headers: { 'Prefer': 'return=minimal' },
        body: JSON.stringify({ attendance_day_id: attendanceDay.id, employee_id: employee.id, event_type: 'shift_start', event_time: startedAt, note: usesVehicle ? 'Vozidlo ' + (vehicle.plate || vehicle.id) + ', km ' + startOdometer : 'Směna bez vozidla', created_by: employee.id })
      }, 12000).then(function () {
        if (!usesVehicle) return null
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
        body: JSON.stringify({ execution_status: 'in_progress', started_at: routePlan.started_at || startedAt, vehicle_id: usesVehicle && vehicle ? vehicle.id : null })
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
    var accountMenu = root.querySelector('#operatorIdleAccount')
    var accountButtons = root.querySelectorAll('.operator-account-trigger')
    function setAccountMenu(open) {
      accountMenu.hidden = !open
      Array.prototype.forEach.call(accountButtons, function (button) { button.setAttribute('aria-expanded', open ? 'true' : 'false') })
    }
    Array.prototype.forEach.call(accountButtons, function (button) { button.addEventListener('click', function () { setAccountMenu(true) }) })
    Array.prototype.forEach.call(root.querySelectorAll('[data-idle-account-close]'), function (button) {
      button.addEventListener('click', function () { setAccountMenu(false) })
    })
    document.addEventListener('keydown', function (event) {
      if (event.key === 'Escape' && !accountMenu.hidden) setAccountMenu(false)
    })
    root.querySelector('#operatorIdleStartButton').addEventListener('click', function () {
      preparationStarted = true
      vehicleStepComplete = false
      renderVehicleStep()
      updateReadiness()
    })
    root.querySelector('#ot-route').addEventListener('click', openRoutePanel)
    root.querySelector('#ot-vehicle').addEventListener('click', openVehicleStep)
    root.querySelector('#ot-profile').addEventListener('click', function () { window.location.href = './profil.html' })
    root.querySelector('#ot-instructions').addEventListener('click', function () {
      if (instruction && !instructionConfirmed) {
        preparationStarted = true
        vehicleStepComplete = true
        updateReadiness()
      }
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
    root.querySelector('#operatorChooseVehicle').addEventListener('click', function () {
      setVehiclePicker(true)
      loadVehicleAvailability().then(renderVehiclePicker).catch(function () {})
    })
    root.querySelector('#operatorVehiclePickerClose').addEventListener('click', function () { setVehiclePicker(false) })
    root.querySelector('#operatorVehiclePicker').addEventListener('click', function (event) {
      if (event.target === root.querySelector('#operatorVehiclePicker')) setVehiclePicker(false)
    })
    root.querySelector('#operatorVehicleConfirm').addEventListener('click', confirmVehicleStep)
    root.querySelector('#operatorVehicleWithout').addEventListener('click', continueWithoutVehicle)
    root.querySelector('#operatorVehicleBack').addEventListener('click', function () {
      preparationStarted = false
      vehicleStepComplete = false
      updateReadiness()
    })
    root.querySelector('#operatorInstructionOpenPdf').addEventListener('click', openInstructionPdf)
    root.querySelector('#operatorInstructionPdfClose').addEventListener('click', function () { root.querySelector('#operatorInstructionPdfModal').hidden = true })
    root.querySelector('#operatorInstructionPdfModal').addEventListener('click', function (event) {
      if (event.target === root.querySelector('#operatorInstructionPdfModal')) root.querySelector('#operatorInstructionPdfModal').hidden = true
    })
    root.querySelector('#operatorInstructionPdfRead').addEventListener('click', markInstructionDocumentRead)
    root.querySelector('#operatorInstructionPdfZoomOut').addEventListener('click', function () { changeInstructionPdfZoom(-25) })
    root.querySelector('#operatorInstructionPdfZoomIn').addEventListener('click', function () { changeInstructionPdfZoom(25) })
    root.querySelector('#operatorInstructionPdfFit').addEventListener('click', fitInstructionPdfWidth)
    var pdfViewer = root.querySelector('#operatorInstructionPdfViewer')
    pdfViewer.addEventListener('touchstart', beginInstructionPdfPinch, { passive: true })
    pdfViewer.addEventListener('touchmove', moveInstructionPdfPinch, { passive: false })
    pdfViewer.addEventListener('touchend', endInstructionPdfPinch, { passive: true })
    pdfViewer.addEventListener('dblclick', function () {
      applyInstructionPdfZoom(instructionPdfZoom >= 220 ? 100 : instructionPdfZoom + 50, true)
    })
    window.addEventListener('resize', function () {
      if (!root.querySelector('#operatorInstructionPdfModal').hidden) applyInstructionPdfZoom(instructionPdfZoom, true)
    })
    root.querySelector('#operatorInstructionConfirm').addEventListener('click', confirmInstructionStep)
    root.querySelector('#operatorInstructionBack').addEventListener('click', function () {
      vehicleStepComplete = false
      updateReadiness()
    })
    root.querySelector('#operatorInstructionSignatureClear').addEventListener('click', clearInstructionSignature)
    var signaturePad = root.querySelector('#operatorInstructionSignaturePad')
    signaturePad.addEventListener('mousedown', beginInstructionSignature)
    signaturePad.addEventListener('mousemove', moveInstructionSignature)
    window.addEventListener('mouseup', endInstructionSignature)
    signaturePad.addEventListener('touchstart', beginInstructionSignature, { passive: false })
    signaturePad.addEventListener('touchmove', moveInstructionSignature, { passive: false })
    signaturePad.addEventListener('touchend', endInstructionSignature)
    root.querySelector('#operatorVehicleOdometer').addEventListener('focus', function (event) {
      event.target.value = String(parseOdometer(event.target.value) || '')
    })
    root.querySelector('#operatorVehicleOdometer').addEventListener('blur', function (event) {
      var value = parseOdometer(event.target.value)
      if (Number.isFinite(value)) event.target.value = formatOdometer(value)
    })
    document.addEventListener('keydown', function (event) {
      if (event.key === 'Escape') {
        setVehiclePicker(false)
        root.querySelector('#operatorInstructionPdfModal').hidden = true
      }
    })
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
    Promise.all([loadRoute(), loadInstruction(), loadAttendance(), loadVehicles(), loadVehicleAvailability()]).then(function (results) {
      routePlan = results[0]
      instruction = results[1]
      attendanceDay = results[2]
      availableVehicles = results[3]
      var resolvedVehicleId = attendanceDay && attendanceDay.vehicle_id || routePlan && routePlan.vehicle_id
      assignedVehicleId = resolvedVehicleId || null
      return Promise.all([loadVehicle(resolvedVehicleId), loadInstructionAcknowledgement(), loadInstructionProgress()])
    }).then(function (results) {
      vehicle = results[0]
      if (!assignedVehicleId && vehicle) assignedVehicleId = vehicle.id
      instructionConfirmed = results[1]
      return Promise.all([loadVehicleLog(), loadWarehouse()])
    }).then(function (results) {
      vehicleLog = results[0]
      warehouse = results[1]
      readVehicleConfirmation()
      renderData()
      return loadWeather()
    }).then(function (weather) {
      renderWeather(weather)
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
    vehicle = { id: 6, name: 'Fiat Doblò Cargo', plate: '3BU9736', current_odometer_km: 128318, warehouse_id: 1, active: true, image_path: 'static:../assets/vehicles/fiat-doblo-2012.png' }
    assignedVehicleId = 6
    availableVehicles = [
      vehicle,
      { id: 3, name: 'Fiat Doblo', plate: '5AP9000', current_odometer_km: 318906, warehouse_id: 1, active: true, image_path: 'static:../assets/vehicles/fiat-doblo-modern.png' },
      { id: 1, name: 'Renault Kangoo', plate: '2TX7928', current_odometer_km: 132669, warehouse_id: 1, active: true, image_path: 'static:../assets/vehicles/renault-kangoo-2019.png' },
      { id: 5, name: 'Opel Combo', plate: '7Z71808', current_odometer_km: 106358, warehouse_id: 1, active: true, image_path: 'static:../assets/vehicles/opel-combo-2024-passenger.png' },
      { id: 4, name: 'Opel Movano', plate: '2BN7419', current_odometer_km: 154555, warehouse_id: 1, active: true, image_path: 'static:../assets/vehicles/opel-movano-older.png' }
    ]
    busyVehicles = new Map()
    warehouse = { id: 1, name: 'Hlavní sklad', city: 'Blučina', latitude: 49.0547, longitude: 16.6445 }
    instruction = {
      id: 'preview-instruction',
      title: 'Test PDF a podpisu na PDA',
      message: 'Otevřete přiložený testovací dokument, potvrďte jeho přečtení a podepište se prstem přímo na PDA.',
      requires_acknowledgement: true,
      attachment_url: './assets/instructions/pokyn-dne-test-2026-11-17.pdf',
      attachment_label: 'Ověření PDF a podpisu na PDA',
      instruction_type: 'signed_document',
      instruction_payload: {
        requiresSignature: true,
        documentVersion: '1.0',
        documentSha256: '094f8423393ae1bf1ce51c4d5e18d9b220b98a911793a54eb241114f706bd561',
        previewPages: ['./assets/instructions/pokyn-dne-test-2026-11-17-page-1-hires.png'],
        pageCount: 1,
        warningText: 'Po podpisu se potvrzení uloží do databáze společně s verzí dokumentu a údaji zařízení.'
      }
    }
    attendanceDay = null
    vehicleLog = null
    instructionConfirmed = false
    vehicleConfirmed = false
    startOdometer = null
    vehicleUsage = 'vehicle'
    vehicleStepComplete = false
    renderData()
  }
})()
