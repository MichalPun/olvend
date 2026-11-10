(function () {
  'use strict'

  var supabaseUrl = 'https://rerjlkrhiytgscjerqgs.supabase.co'
  var supabaseKey = 'sb_publishable_A8OxCcapdNXAzQLjLsW5iA_XtGvBZ0S'
  var root = document.getElementById('operator-profile')
  var session = null
  var employee = null
  var attendanceDays = []
  var requests = []
  var shifts = []
  var territoryRows = []
  var payslips = []
  var bonusSummaries = []
  var inventories = []
  var currentView = 'overview'
  var territoryMaps = {}
  var territoryBounds = null

  function apiHeaders(extra) {
    return Object.assign({
      apikey: supabaseKey,
      Authorization: 'Bearer ' + session.access_token,
      'Content-Type': 'application/json'
    }, extra || {})
  }

  function requestJson(url, options) {
    var opts = Object.assign({}, options || {})
    opts.headers = apiHeaders(opts.headers)
    return fetch(url, opts).then(function (response) {
      if (!response.ok) return response.text().then(function (text) {
        var detail = ''
        try { detail = JSON.parse(text).message || JSON.parse(text).details || '' } catch (_) {}
        throw new Error(detail || 'Data se nepodařilo načíst (HTTP ' + response.status + ').')
      })
      if (response.status === 204) return null
      return response.text().then(function (text) { return text ? JSON.parse(text) : null })
    })
  }

  function todayIso(date) {
    var value = date || new Date()
    try { return new Intl.DateTimeFormat('sv-SE', { timeZone: 'Europe/Prague' }).format(value) }
    catch (_) { return value.toISOString().slice(0, 10) }
  }

  function weekRange() {
    var now = new Date()
    var day = now.getDay() || 7
    var from = new Date(now)
    from.setHours(12, 0, 0, 0)
    from.setDate(from.getDate() - day + 1)
    var to = new Date(from)
    to.setDate(to.getDate() + 6)
    return { from: todayIso(from), to: todayIso(to) }
  }

  function initials(person) {
    return ((String(person && person.name || '').charAt(0) + String(person && person.surname || '').charAt(0)).toUpperCase() || 'OP')
  }

  function roleLabel(role) {
    var map = { operator: 'Operátor', technician: 'Technik', manager: 'Manažer', admin: 'Administrátor' }
    return map[String(role || '').toLowerCase()] || role || 'Operátor'
  }

  function employmentLabel(value) {
    var map = { hpp: 'HPP', dpp: 'DPP', dpc: 'DPČ', external: 'Externí spolupráce' }
    return map[String(value || '').toLowerCase()] || 'Pracovní poměr neuveden'
  }

  function requestTypeLabel(type) {
    var map = { vacation: 'Dovolená', doctor: 'Doktor', personal: 'Osobní volno', sick: 'Nemoc / překážka', other: 'Jiná žádost' }
    return map[String(type || '').toLowerCase()] || 'Žádost'
  }

  function requestStatus(status) {
    var map = {
      pending: { label: 'Čeká na schválení', cls: 'pending' },
      approved: { label: 'Schváleno', cls: 'approved' },
      rejected: { label: 'Zamítnuto', cls: 'rejected' },
      cancelled: { label: 'Zrušeno', cls: '' }
    }
    return map[String(status || '').toLowerCase()] || map.pending
  }

  function shiftTypeLabel(type) {
    var map = {
      operator: 'Operátor v provozu', technician_field: 'Technik v terénu', technician_workshop: 'Technik na dílně',
      manager_office: 'Manažer v kanceláři', manager_field: 'Manažer v provozu', vacation: 'Dovolená',
      sick: 'Nemoc', holiday: 'Svátek', day_off: 'Volno'
    }
    return map[type] || 'Plánovaná směna'
  }

  function formatDate(value, withWeekday) {
    if (!value) return '—'
    var date = new Date(String(value).slice(0, 10) + 'T12:00:00')
    return date.toLocaleDateString('cs-CZ', withWeekday ? { weekday: 'short', day: 'numeric', month: 'numeric' } : { day: 'numeric', month: 'numeric', year: 'numeric' })
  }

  function formatRange(row) {
    var dates = row.date_to && row.date_to !== row.date_from ? formatDate(row.date_from) + ' – ' + formatDate(row.date_to) : formatDate(row.date_from)
    var times = row.start_time && row.end_time ? String(row.start_time).slice(0, 5) + ' – ' + String(row.end_time).slice(0, 5) : ''
    return [dates, times].filter(Boolean).join(' · ')
  }

  function countWeekdays(fromValue, toValue) {
    if (!fromValue) return 0
    var from = new Date(fromValue + 'T12:00:00')
    var to = new Date((toValue || fromValue) + 'T12:00:00')
    var total = 0
    while (from <= to) {
      if (from.getDay() !== 0 && from.getDay() !== 6) total += 1
      from.setDate(from.getDate() + 1)
    }
    return total
  }

  function vacationMeta() {
    var year = String(new Date().getFullYear())
    var total = Number(employee.vacation_allowance_days || 0) + Number(employee.vacation_carryover_days || 0)
    var approved = requests.filter(function (row) { return row.request_type === 'vacation' && row.status === 'approved' && String(row.date_from || '').indexOf(year) === 0 })
      .reduce(function (sum, row) { return sum + countWeekdays(row.date_from, row.date_to) }, 0)
    return { total: total, approved: approved, remaining: Math.max(0, total - approved) }
  }

  function showBusy(active, label) {
    root.querySelector('#op-busy-label').textContent = label || 'Načítám…'
    root.querySelector('#op-busy').hidden = !active
  }

  function toast(message, isError) {
    var item = root.querySelector('#op-toast')
    item.textContent = message
    item.classList.toggle('error', Boolean(isError))
    item.hidden = false
    window.clearTimeout(toast.timer)
    toast.timer = window.setTimeout(function () { item.hidden = true }, 3600)
  }

  function openView(name) {
    currentView = name
    Array.prototype.forEach.call(root.querySelectorAll('.op-view'), function (view) { view.hidden = view.getAttribute('data-view') !== name })
    window.scrollTo(0, 0)
    if (name === 'territory' && territoryMaps.detail) {
      window.setTimeout(function () {
        territoryMaps.detail.invalidateSize()
        fitTerritoryMap(territoryMaps.detail, 12)
      }, 30)
    }
  }

  function addEmpty(parent, message) {
    var empty = document.createElement('div')
    empty.className = 'op-empty'
    empty.textContent = message
    parent.appendChild(empty)
  }

  function addDataRow(parent, label, value) {
    var row = document.createElement('div')
    row.className = 'op-data-row'
    var small = document.createElement('span')
    var strong = document.createElement('strong')
    small.textContent = label
    strong.textContent = value || 'Neuvedeno'
    row.appendChild(small)
    row.appendChild(strong)
    parent.appendChild(row)
  }

  function loadEmployee() {
    var fields = 'id,name,surname,role,email,phone,contracted_weekly_hours,employment_type,vacation_allowance_days,vacation_carryover_days,auth_user_id'
    var identityFilter = session && session.user && session.user.id
      ? '&auth_user_id=eq.' + encodeURIComponent(session.user.id)
      : '&id=eq.' + encodeURIComponent(employee.id)
    var url = supabaseUrl + '/rest/v1/employees?select=' + encodeURIComponent(fields) + identityFilter + '&limit=1'
    return requestJson(url).catch(function (error) {
      if (!/phone|vacation_allowance_days|vacation_carryover_days/i.test(String(error.message || ''))) throw error
      fields = 'id,name,surname,role,email,contracted_weekly_hours,employment_type,auth_user_id'
      return requestJson(supabaseUrl + '/rest/v1/employees?select=' + encodeURIComponent(fields) + identityFilter + '&limit=1')
    }).then(function (rows) {
      if (Array.isArray(rows) && rows[0]) employee = Object.assign({}, employee, rows[0])
    })
  }

  function loadAttendance() {
    var range = weekRange()
    var fields = 'attendance_date,payable_minutes,actual_start,actual_end,status'
    var url = supabaseUrl + '/rest/v1/attendance_days?select=' + encodeURIComponent(fields) + '&employee_id=eq.' + encodeURIComponent(employee.id)
      + '&attendance_date=gte.' + range.from + '&attendance_date=lte.' + range.to + '&order=attendance_date.asc'
    return requestJson(url).then(function (rows) { attendanceDays = Array.isArray(rows) ? rows : [] })
  }

  function loadRequests() {
    var fields = 'id,employee_id,request_type,status,date_from,date_to,start_time,end_time,reason,manager_note,approved_at,created_at,updated_at'
    var url = supabaseUrl + '/rest/v1/hr_requests?select=' + encodeURIComponent(fields) + '&employee_id=eq.' + encodeURIComponent(employee.id) + '&order=created_at.desc'
    return requestJson(url).then(function (rows) { requests = Array.isArray(rows) ? rows : [] })
  }

  function loadShifts() {
    var now = new Date()
    var periods = [0, 1].map(function (offset) {
      var date = new Date(now.getFullYear(), now.getMonth() + offset, 1)
      return { year: date.getFullYear(), month: date.getMonth() + 1 }
    })
    return Promise.all(periods.map(function (period) {
      var url = supabaseUrl + '/rest/v1/shift_plans?select=id&period_type=eq.month&period_year=eq.' + period.year + '&period_month=eq.' + period.month + '&status=eq.published&order=published_at.desc&limit=1'
      return requestJson(url).catch(function () { return [] })
    })).then(function (results) {
      var ids = results.map(function (rows) { return rows && rows[0] && rows[0].id }).filter(Boolean)
      if (!ids.length) { shifts = []; return }
      var end = new Date(now)
      end.setDate(end.getDate() + 27)
      var fields = 'id,shift_type,planned_start,planned_end,warehouse_id,vehicle_id,location_type,note,status,shift_plan_id,plan_date'
      var url = supabaseUrl + '/rest/v1/shift_plan_days?select=' + encodeURIComponent(fields)
        + '&shift_plan_id=in.(' + ids.map(encodeURIComponent).join(',') + ')&employee_id=eq.' + encodeURIComponent(employee.id)
        + '&plan_date=gte.' + todayIso(now) + '&plan_date=lte.' + todayIso(end) + '&order=plan_date.asc,planned_start.asc'
      return requestJson(url).then(function (rows) { shifts = Array.isArray(rows) ? rows : [] })
    })
  }

  function loadTerritory() {
    var filter = '?or=(primary_employee_id.eq.' + encodeURIComponent(employee.id) + ',backup_employee_id.eq.' + encodeURIComponent(employee.id) + ')&order=effective_from.desc'
    var url = supabaseUrl + '/rest/v1/rpc/get_operator_territories_v51' + filter
    return requestJson(url, { method: 'POST', body: JSON.stringify({ p_date: todayIso() }) }).then(function (assignments) {
      assignments = Array.isArray(assignments) ? assignments : []
      var locationIds = assignments.map(function (row) { return row.location_id }).filter(Boolean).filter(function (value, index, all) { return all.indexOf(value) === index })
      if (!locationIds.length) { territoryRows = []; return }
      var idFilter = 'in.(' + locationIds.map(encodeURIComponent).join(',') + ')'
      var locationsUrl = supabaseUrl + '/rest/v1/locations?select=' + encodeURIComponent('id,name,city,address,latitude,longitude,active') + '&id=' + idFilter
      var machinesUrl = supabaseUrl + '/rest/v1/machines?select=' + encodeURIComponent('id,location_id,active,status') + '&location_id=' + idFilter + '&active=eq.true'
      return Promise.all([requestJson(locationsUrl), requestJson(machinesUrl)]).then(function (results) {
        var locations = Array.isArray(results[0]) ? results[0] : []
        var machines = Array.isArray(results[1]) ? results[1] : []
        var locationById = {}
        var machinesByLocation = {}
        locations.forEach(function (location) { if (location.active !== false) locationById[String(location.id)] = location })
        machines.filter(function (machine) { return !/warehouse|sklad|reserve|rezerv/i.test(String(machine.status || '')) }).forEach(function (machine) {
          var key = String(machine.location_id)
          if (!machinesByLocation[key]) machinesByLocation[key] = []
          machinesByLocation[key].push(machine)
        })
        territoryRows = assignments.map(function (assignment) {
          var location = locationById[String(assignment.location_id)]
          if (!location) return null
          var allMachines = machinesByLocation[String(location.id)] || []
          var selected = Array.isArray(assignment.selected_machine_ids) ? assignment.selected_machine_ids.map(String) : []
          var machineCount = assignment.assignment_scope === 'machines'
            ? allMachines.filter(function (machine) { return selected.indexOf(String(machine.id)) !== -1 }).length
            : allMachines.length
          return { assignment: assignment, location: location, machineCount: machineCount, role: String(assignment.primary_employee_id) === String(employee.id) ? 'primary' : 'backup' }
        }).filter(Boolean).sort(function (a, b) {
          if (a.role !== b.role) return a.role === 'primary' ? -1 : 1
          return String(a.location.city || a.location.name || '').localeCompare(String(b.location.city || b.location.name || ''), 'cs')
        })
      })
    })
  }

  function loadPayslips() {
    var fields = 'id,employee_id,period_month,file_path,file_name,general_message,status,published_at,read_at'
    var url = supabaseUrl + '/rest/v1/payroll_payslips?select=' + encodeURIComponent(fields)
      + '&employee_id=eq.' + encodeURIComponent(employee.id) + '&status=eq.published&order=period_month.desc'
    return requestJson(url).then(function (rows) { payslips = Array.isArray(rows) ? rows : [] })
  }

  function monthStart(offset) {
    var date = new Date()
    date = new Date(date.getFullYear(), date.getMonth() - Number(offset || 0), 1)
    return date.getFullYear() + '-' + String(date.getMonth() + 1).padStart(2, '0') + '-01'
  }

  function loadBonuses() {
    var offsets = [0, 1, 2, 3, 4, 5].filter(function (offset) { return monthStart(offset) >= '2026-08-01' })
    return Promise.all(offsets.map(function (offset) {
      return requestJson(supabaseUrl + '/rest/v1/rpc/my_bonus_summary', { method: 'POST', body: JSON.stringify({ p_period: monthStart(offset) }) })
    })).then(function (rows) { bonusSummaries = rows.filter(Boolean) })
  }

  function loadInventories() {
    var fields = 'id,audit_date,scope_type,assigned_employee_id,status,difference_quantity_total,difference_value_total,evaluated_at,closed_at,responsibility_status,responsibility_decision_note,bonus_impact_amount,bonus_period,created_at,audit_origin'
    var url = supabaseUrl + '/rest/v1/inventory_audits?select=' + encodeURIComponent(fields)
      + '&assigned_employee_id=eq.' + encodeURIComponent(employee.id) + '&scope_type=eq.vehicle&order=created_at.desc&limit=30'
    return requestJson(url).then(function (rows) { inventories = Array.isArray(rows) ? rows : [] })
  }

  function locationPoint(location) {
    var lat = Number(location && location.latitude)
    var lng = Number(location && location.longitude)
    if (!isFinite(lat) || !isFinite(lng) || lat < 48.3 || lat > 51.2 || lng < 11.8 || lng > 19.2) return null
    return [lat, lng]
  }

  function fitTerritoryMap(map, maxZoom) {
    if (!map || !territoryBounds || !territoryBounds.isValid()) return
    if (territoryBounds.getNorthEast().equals(territoryBounds.getSouthWest())) {
      map.setView(territoryBounds.getCenter(), Math.min(maxZoom || 13, 13))
      return
    }
    map.fitBounds(territoryBounds, { paddingTopLeft: [26, 26], paddingBottomRight: [26, 54], maxZoom: maxZoom || 13 })
  }

  function cross(origin, a, b) {
    return (a[1] - origin[1]) * (b[0] - origin[0]) - (a[0] - origin[0]) * (b[1] - origin[1])
  }

  function convexHull(points) {
    if (points.length < 3) return points
    var sorted = points.slice().sort(function (a, b) { return a[1] === b[1] ? a[0] - b[0] : a[1] - b[1] })
    var lower = []
    sorted.forEach(function (point) {
      while (lower.length >= 2 && cross(lower[lower.length - 2], lower[lower.length - 1], point) <= 0) lower.pop()
      lower.push(point)
    })
    var upper = []
    sorted.slice().reverse().forEach(function (point) {
      while (upper.length >= 2 && cross(upper[upper.length - 2], upper[upper.length - 1], point) <= 0) upper.pop()
      upper.push(point)
    })
    lower.pop(); upper.pop()
    return lower.concat(upper)
  }

  function fallbackMap(container, message) {
    container.innerHTML = ''
    var fallback = document.createElement('div')
    fallback.className = 'op-map-fallback'
    fallback.textContent = message
    container.appendChild(fallback)
  }

  function renderLeafletMap(container, key, interactive) {
    if (!container) return
    if (territoryMaps[key]) {
      territoryMaps[key].remove()
      territoryMaps[key] = null
    }
    var visible = territoryRows.map(function (row, index) {
      var point = locationPoint(row.location)
      return point ? { row: row, point: point, index: index + 1 } : null
    }).filter(Boolean)
    if (!visible.length) {
      fallbackMap(container, 'U přidělených lokalit zatím nejsou uložené souřadnice.')
      return
    }
    if (!window.L) {
      fallbackMap(container, 'Mapový podklad se nepodařilo načíst. Seznam lokalit je dostupný pod mapou.')
      return
    }
    container.innerHTML = ''
    var map = window.L.map(container, {
      attributionControl: true,
      zoomControl: interactive,
      dragging: interactive,
      touchZoom: interactive,
      doubleClickZoom: interactive,
      boxZoom: interactive,
      keyboard: interactive,
      scrollWheelZoom: false,
      tap: interactive,
      zoomSnap: 0.5
    })
    territoryMaps[key] = map
    window.L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">OpenStreetMap</a>',
      maxZoom: 18
    }).addTo(map)
    var primaryPoints = []
    visible.forEach(function (item) {
      if (item.row.role === 'primary') primaryPoints.push(item.point)
      var icon = window.L.divIcon({
        className: '',
        html: '<span class="op-map-pin' + (item.row.role === 'backup' ? ' backup' : '') + '">' + item.index + '</span>',
        iconSize: [27, 27],
        iconAnchor: [14, 14]
      })
      var marker = window.L.marker(item.point, { icon: icon, keyboard: interactive, title: item.row.location.name || 'Lokalita' }).addTo(map)
      var label = item.row.location.name || item.row.location.city || 'Lokalita'
      marker.bindTooltip(label, { className: 'op-map-label', direction: 'top', offset: [0, -11], opacity: 1, permanent: interactive })
      if (interactive) marker.bindPopup('<strong>' + escapeHtml(label) + '</strong><br>' + escapeHtml([item.row.location.city, item.row.location.address].filter(Boolean).join(', ')) + '<br><small>' + item.row.machineCount + (item.row.machineCount === 1 ? ' automat' : ' automatů') + '</small>')
    })
    if (primaryPoints.length >= 3) {
      window.L.polygon(convexHull(primaryPoints), { color: '#087746', weight: 2, opacity: .55, fillColor: '#087746', fillOpacity: .08, interactive: false, dashArray: '6 6' }).addTo(map)
    }
    territoryBounds = window.L.latLngBounds(visible.map(function (item) { return item.point }))
    fitTerritoryMap(map, interactive ? 12 : 10)
  }

  function escapeHtml(value) {
    return String(value || '').replace(/[&<>'"]/g, function (character) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' }[character]
    })
  }

  function renderTerritory() {
    var primary = territoryRows.filter(function (row) { return row.role === 'primary' })
    var backup = territoryRows.filter(function (row) { return row.role === 'backup' })
    var machineCount = primary.reduce(function (sum, row) { return sum + Number(row.machineCount || 0) }, 0)
    root.querySelector('#op-territory-locations').textContent = String(primary.length)
    root.querySelector('#op-territory-machines').textContent = String(machineCount)
    root.querySelector('#op-territory-backups').textContent = String(backup.length)
    root.querySelector('#op-primary-legend').textContent = primary.length + ' hlavních'
    root.querySelector('#op-backup-legend').textContent = backup.length + '× náhradník'
    root.querySelector('#op-detail-locations').textContent = String(primary.length)
    root.querySelector('#op-detail-machines').textContent = String(machineCount)
    root.querySelector('#op-detail-backups').textContent = String(backup.length)
    root.querySelector('#op-territory-total').textContent = territoryRows.length + ' záznamů'
    var cities = primary.map(function (row) { return row.location.city }).filter(Boolean).filter(function (value, index, all) { return all.indexOf(value) === index })
    root.querySelector('#op-territory-cities').textContent = cities.length ? cities.slice(0, 6).join(' · ') : 'Zatím bez přidělené hlavní oblasti'
    var validFrom = primary.map(function (row) { return row.assignment.effective_from }).filter(Boolean).sort()[0]
    root.querySelector('#op-territory-validity').textContent = validFrom ? 'Aktuální rozdělení platné od ' + formatDate(validFrom) : 'Aktuální rozdělení'
    renderLeafletMap(root.querySelector('#op-territory-map-overview'), 'overview', false)
    renderLeafletMap(root.querySelector('#op-territory-map-detail'), 'detail', true)
    var list = root.querySelector('#op-territory-list')
    list.innerHTML = ''
    if (!territoryRows.length) { addEmpty(list, 'Zatím nemáte přidělený rajón.'); return }
    territoryRows.forEach(function (row, index) {
      var item = document.createElement('div')
      item.className = 'op-location' + (row.role === 'backup' ? ' backup' : '')
      var number = document.createElement('span')
      number.className = 'op-location-index'
      number.textContent = String(index + 1)
      var copy = document.createElement('span')
      copy.className = 'op-location-copy'
      var title = document.createElement('strong')
      var address = document.createElement('span')
      var value = document.createElement('b')
      title.textContent = row.location.name || 'Lokalita'
      address.textContent = [row.location.city, row.location.address].filter(Boolean).join(' · ')
      value.textContent = row.role === 'backup' ? 'Náhradník' : row.machineCount + (row.machineCount === 1 ? ' automat' : row.machineCount > 1 && row.machineCount < 5 ? ' automaty' : ' automatů')
      copy.appendChild(title); copy.appendChild(address); item.appendChild(number); item.appendChild(copy); item.appendChild(value); list.appendChild(item)
    })
  }

  function formatPayslipMonth(value) {
    if (!value) return 'Výplatnice'
    return new Date(String(value).slice(0, 10) + 'T12:00:00').toLocaleDateString('cs-CZ', { month: 'long', year: 'numeric' })
  }

  function renderPayslips() {
    var unread = payslips.filter(function (item) { return !item.read_at }).length
    root.querySelector('#op-payslip-count').textContent = String(payslips.length)
    root.querySelector('#op-payslip-note').textContent = unread ? unread + (unread === 1 ? ' nová' : ' nové') : (payslips.length === 1 ? 'nahraná' : 'nahrané')
    var list = root.querySelector('#op-payslip-list')
    list.innerHTML = ''
    if (!payslips.length) { addEmpty(list, 'Zatím zde není žádná zveřejněná výplatnice.'); return }
    payslips.forEach(function (payslip) {
      var card = document.createElement('article')
      card.className = 'op-card' + (payslip.read_at ? '' : ' unread')
      var head = document.createElement('div')
      head.className = 'op-card-head'
      var copy = document.createElement('div')
      var title = document.createElement('strong')
      var file = document.createElement('p')
      var status = document.createElement('span')
      status.className = 'op-status ' + (payslip.read_at ? 'approved' : 'pending')
      title.textContent = formatPayslipMonth(payslip.period_month)
      file.textContent = payslip.file_name || 'Výplatnice PDF'
      status.textContent = payslip.read_at ? 'Přečteno' : 'Nové'
      copy.appendChild(title); copy.appendChild(file); head.appendChild(copy); head.appendChild(status); card.appendChild(head)
      if (payslip.general_message) { var message = document.createElement('p'); message.textContent = payslip.general_message; card.appendChild(message) }
      var actions = document.createElement('div')
      actions.className = 'op-payslip-actions'
      var open = document.createElement('button')
      open.type = 'button'; open.className = 'op-primary'; open.textContent = 'Otevřít PDF'
      open.addEventListener('click', function () { openPayslip(payslip) })
      actions.appendChild(open)
      if (!payslip.read_at) {
        var acknowledge = document.createElement('button')
        acknowledge.type = 'button'; acknowledge.className = 'op-secondary'; acknowledge.textContent = 'Potvrdit přečtení'
        acknowledge.addEventListener('click', function () { acknowledgePayslip(payslip) })
        actions.appendChild(acknowledge)
      } else {
        var placeholder = document.createElement('span')
        actions.appendChild(placeholder)
      }
      card.appendChild(actions); list.appendChild(card)
    })
  }

  function openPayslip(payslip) {
    if (!payslip.file_path) { toast('PDF dokument není dostupný.', true); return }
    showBusy(true, 'Otevírám výplatnici…')
    var path = payslip.file_path.split('/').map(encodeURIComponent).join('/')
    requestJson(supabaseUrl + '/storage/v1/object/sign/payroll-payslips/' + path, { method: 'POST', body: JSON.stringify({ expiresIn: 120 }) })
      .then(function (data) {
        var signed = data && (data.signedURL || data.signedUrl)
        if (!signed) throw new Error('Odkaz na PDF se nepodařilo vytvořit.')
        window.open(signed.indexOf('http') === 0 ? signed : supabaseUrl + '/storage/v1' + signed, '_blank', 'noopener')
      }).catch(function (error) { toast(error.message || 'Výplatnici se nepodařilo otevřít.', true) })
      .then(function () { showBusy(false) })
  }

  function acknowledgePayslip(payslip) {
    showBusy(true, 'Ukládám potvrzení…')
    requestJson(supabaseUrl + '/rest/v1/rpc/acknowledge_my_payslip', { method: 'POST', body: JSON.stringify({ p_payslip_id: Number(payslip.id) }) })
      .then(function () { payslip.read_at = new Date().toISOString(); renderPayslips(); toast('Přečtení výplatnice bylo potvrzeno.') })
      .catch(function (error) { toast(error.message || 'Potvrzení se nepodařilo uložit.', true) })
      .then(function () { showBusy(false) })
  }

  function formatMoney(value) {
    return new Intl.NumberFormat('cs-CZ', { style: 'currency', currency: 'CZK', maximumFractionDigits: 0 }).format(Number(value || 0))
  }

  function formatMonth(value) {
    if (!value) return '—'
    return new Date(String(value).slice(0, 10) + 'T12:00:00').toLocaleDateString('cs-CZ', { month: 'long', year: 'numeric' })
  }

  function renderBonuses() {
    var current = bonusSummaries[0] || null
    root.querySelector('#op-bonus-amount').textContent = current ? formatMoney(current.total) : '—'
    root.querySelector('#op-bonus-note').textContent = current && current.is_final ? 'uzavřená částka' : 'průběžný odhad'
    root.querySelector('#op-bonus-period').textContent = current ? formatMonth(current.period) : 'Aktuální měsíc'
    root.querySelector('#op-bonus-state').textContent = current && current.is_final ? 'Uzavřeno' : 'Průběžný odhad'
    root.querySelector('#op-bonus-total').textContent = current ? formatMoney(current.total) : 'Údaj není dostupný'
    root.querySelector('#op-bonus-before').textContent = current ? formatMoney(current.bonus_before_adjustments) : '—'
    root.querySelector('#op-bonus-deductions').textContent = current ? '−' + formatMoney(current.deductions) : '—'
    root.querySelector('#op-bonus-visits').textContent = current ? String(current.visits || 0) : '—'
    root.querySelector('#op-bonus-machines').textContent = current ? String(current.machines || 0) : '—'
    root.querySelector('#op-bonus-updated').textContent = current && current.updated_at
      ? 'Aktualizováno ' + new Date(current.updated_at).toLocaleString('cs-CZ', { day: 'numeric', month: 'numeric', hour: '2-digit', minute: '2-digit' })
      : 'Vyhodnocení se nepodařilo načíst.'
    var history = root.querySelector('#op-bonus-history')
    root.querySelector('#op-bonus-history-label').textContent = bonusSummaries.length === 1 ? '1 měsíc' : bonusSummaries.length + ' měsíců'
    history.innerHTML = ''
    if (!bonusSummaries.length) { addEmpty(history, 'Přehled prémií nyní není dostupný.'); return }
    bonusSummaries.forEach(function (item) {
      var row = document.createElement('div')
      row.className = 'op-history-row'
      var copy = document.createElement('span')
      var title = document.createElement('strong')
      var detail = document.createElement('span')
      var amount = document.createElement('b')
      title.textContent = formatMonth(item.period)
      detail.textContent = (item.visits || 0) + ' návštěv · ' + (item.machines || 0) + ' automatů' + (Number(item.deductions || 0) ? ' · úpravy −' + formatMoney(item.deductions) : '')
      amount.textContent = formatMoney(item.total)
      copy.appendChild(title); copy.appendChild(detail); row.appendChild(copy); row.appendChild(amount); history.appendChild(row)
    })
  }

  function inventoryKind(item) {
    if (item.status === 'assigned') return 'action'
    if (['counted', 'transfer_ready', 'evaluated'].indexOf(item.status) !== -1) return 'review'
    return 'closed'
  }

  function inventoryStatus(item) {
    var kind = inventoryKind(item)
    if (kind === 'action') return { label: 'K dokončení', cls: 'pending' }
    if (kind === 'review') return { label: 'Prověřuje se', cls: '' }
    if (item.responsibility_status === 'not_operator') return { label: 'Bez odpovědnosti', cls: 'approved' }
    if (item.responsibility_status === 'operator') return { label: 'Uzavřeno', cls: 'rejected' }
    return { label: 'Uzavřeno', cls: 'approved' }
  }

  function renderInventories() {
    var action = inventories.filter(function (item) { return inventoryKind(item) === 'action' })
    var review = inventories.filter(function (item) { return inventoryKind(item) === 'review' })
    var closed = inventories.filter(function (item) { return inventoryKind(item) === 'closed' })
    var attention = action.length
    root.querySelector('#op-inventory-action').textContent = String(action.length)
    root.querySelector('#op-inventory-review').textContent = String(review.length)
    root.querySelector('#op-inventory-closed').textContent = String(closed.length)
    root.querySelector('#op-inventory-total').textContent = inventories.length + (inventories.length === 1 ? ' záznam' : inventories.length > 1 && inventories.length < 5 ? ' záznamy' : ' záznamů')
    root.querySelector('#op-inventory-summary').textContent = attention
      ? (attention === 1 ? '1 inventura čeká na dokončení' : attention + ' inventury čekají na dokončení')
      : review.length ? review.length + (review.length === 1 ? ' kontrola se prověřuje' : ' kontroly se prověřují') : 'Výsledky a případné rozdíly'
    var badge = root.querySelector('#op-inventory-badge')
    badge.textContent = attention ? String(attention) : '✓'
    badge.classList.toggle('ok', !attention)
    var list = root.querySelector('#op-inventory-list')
    list.innerHTML = ''
    if (!inventories.length) { addEmpty(list, 'Zatím zde není žádná inventura.'); return }
    inventories.forEach(function (item) {
      var status = inventoryStatus(item)
      var card = document.createElement('article')
      card.className = 'op-inventory-card' + (inventoryKind(item) === 'action' ? ' attention' : '')
      var head = document.createElement('div')
      head.className = 'op-inventory-head'
      var copy = document.createElement('div')
      var title = document.createElement('strong')
      var meta = document.createElement('span')
      var chip = document.createElement('b')
      chip.className = 'op-status ' + status.cls
      title.textContent = 'Inventura auta #' + item.id
      meta.textContent = formatDate(item.audit_date || item.created_at) + (item.audit_origin === 'post_route_exception' ? ' · po trase' : '')
      chip.textContent = status.label
      copy.appendChild(title); copy.appendChild(meta); head.appendChild(copy); head.appendChild(chip); card.appendChild(head)
      var impact = document.createElement('div')
      impact.className = 'op-inventory-impact' + (item.responsibility_status === 'not_operator' ? ' ok' : '')
      if (inventoryKind(item) === 'action') impact.textContent = 'Čeká na fyzické přepočítání položek.'
      else if (inventoryKind(item) === 'review') impact.textContent = 'Výsledek čeká na vyhodnocení vedoucím.'
      else if (item.responsibility_status === 'not_operator') impact.textContent = 'Uzavřeno bez odpovědnosti operátora.'
      else if (item.bonus_impact_amount != null) impact.textContent = 'Schválený dopad do prémie: ' + formatMoney(item.bonus_impact_amount) + ' · ' + formatMonth(item.bonus_period)
      else impact.textContent = 'Uzavřeno bez schváleného dopadu do prémie.'
      card.appendChild(impact); list.appendChild(card)
    })
  }

  function renderOverview() {
    var fullName = [employee.name, employee.surname].filter(Boolean).join(' ') || 'Můj profil'
    var mark = initials(employee)
    root.querySelector('#op-name').textContent = fullName
    root.querySelector('#op-role').textContent = roleLabel(employee.role) + ' · ' + employmentLabel(employee.employment_type)
    root.querySelector('#op-avatar').textContent = mark
    root.querySelector('.op-user').textContent = mark

    var minutes = attendanceDays.reduce(function (sum, row) {
      var stored = Number(row.payable_minutes || 0)
      if (!stored && row.actual_start && !row.actual_end) stored = Math.max(0, Math.round((Date.now() - new Date(row.actual_start).getTime()) / 60000))
      return sum + stored
    }, 0)
    var contracted = Number(employee.contracted_weekly_hours || 0)
    root.querySelector('#op-week-hours').textContent = (minutes / 60).toLocaleString('cs-CZ', { minimumFractionDigits: 0, maximumFractionDigits: 1 }) + (contracted ? ' / ' + contracted.toLocaleString('cs-CZ') : '') + ' h'

    var vacation = vacationMeta()
    root.querySelector('#op-vacation').textContent = vacation.total ? vacation.remaining + ' / ' + vacation.total + ' dní' : vacation.approved + ' dní'
    root.querySelector('#op-vacation-note').textContent = vacation.total ? 'zbývá z nároku' : 'schváleno letos'
    root.querySelector('#op-today-label').textContent = new Date().toLocaleDateString('cs-CZ', { weekday: 'long', day: 'numeric', month: 'long' })
    root.querySelector('#op-next-shift').textContent = shifts.length ? formatDate(shifts[0].plan_date, true) + ' · ' + shiftTime(shifts[0]) : 'Žádná publikovaná směna na dalších 28 dní'
  }

  function shiftTime(row) {
    if (!row.planned_start || !row.planned_end) return 'Bez času'
    return String(row.planned_start).slice(0, 5) + '–' + String(row.planned_end).slice(0, 5)
  }

  function renderShifts() {
    var list = root.querySelector('#op-shift-list')
    list.innerHTML = ''
    if (!shifts.length) { addEmpty(list, 'Na dalších 28 dní není zveřejněná žádná směna. Jakmile HR plán publikuje, objeví se tady.'); return }
    shifts.forEach(function (row) {
      var card = document.createElement('article')
      card.className = 'op-card'
      var head = document.createElement('div')
      head.className = 'op-card-head'
      var copy = document.createElement('div')
      var title = document.createElement('strong')
      var meta = document.createElement('p')
      var badge = document.createElement('span')
      badge.className = 'op-status'
      title.textContent = formatDate(row.plan_date, true) + ' · ' + shiftTime(row)
      meta.textContent = [shiftTypeLabel(row.shift_type), row.note].filter(Boolean).join(' · ')
      badge.textContent = row.status === 'cancelled' ? 'Zrušeno' : 'Naplánováno'
      copy.appendChild(title); copy.appendChild(meta); head.appendChild(copy); head.appendChild(badge); card.appendChild(head); list.appendChild(card)
    })
  }

  function renderRequests() {
    var list = root.querySelector('#op-request-list')
    list.innerHTML = ''
    if (!requests.length) { addEmpty(list, 'Zatím nemáte žádnou žádost. Novou můžete odeslat tlačítkem nahoře.'); return }
    requests.forEach(function (row) {
      var status = requestStatus(row.status)
      var card = document.createElement('article')
      card.className = 'op-card'
      var head = document.createElement('div')
      head.className = 'op-card-head'
      var copy = document.createElement('div')
      var title = document.createElement('strong')
      var range = document.createElement('p')
      var badge = document.createElement('span')
      badge.className = 'op-status ' + status.cls
      title.textContent = requestTypeLabel(row.request_type)
      range.textContent = formatRange(row)
      badge.textContent = status.label
      copy.appendChild(title); copy.appendChild(range); head.appendChild(copy); head.appendChild(badge); card.appendChild(head)
      if (row.reason) { var reason = document.createElement('p'); reason.textContent = row.reason; card.appendChild(reason) }
      if (row.manager_note) { var note = document.createElement('p'); note.textContent = 'Poznámka HR: ' + row.manager_note; card.appendChild(note) }
      if (row.status === 'pending') {
        var cancel = document.createElement('button')
        cancel.type = 'button'; cancel.className = 'op-secondary'; cancel.textContent = 'Zrušit žádost'
        cancel.addEventListener('click', function () { cancelRequest(row.id) })
        card.appendChild(cancel)
      }
      list.appendChild(card)
    })
  }

  function renderPersonal() {
    var data = root.querySelector('#op-personal-data')
    data.innerHTML = ''
    addDataRow(data, 'Jméno a příjmení', [employee.name, employee.surname].filter(Boolean).join(' '))
    addDataRow(data, 'Pracovní role', roleLabel(employee.role))
    addDataRow(data, 'Pracovní poměr', employmentLabel(employee.employment_type))
    addDataRow(data, 'Týdenní fond', employee.contracted_weekly_hours ? Number(employee.contracted_weekly_hours).toLocaleString('cs-CZ') + ' hodin' : 'Neuvedeno')
    addDataRow(data, 'E-mail', employee.email)
    if (employee.phone) addDataRow(data, 'Telefon', employee.phone)
  }

  function renderWorktime() {
    var data = root.querySelector('#op-worktime-data')
    data.innerHTML = ''
    var minutes = attendanceDays.reduce(function (sum, row) {
      var stored = Number(row.payable_minutes || 0)
      if (!stored && row.actual_start && !row.actual_end) stored = Math.max(0, Math.round((Date.now() - new Date(row.actual_start).getTime()) / 60000))
      return sum + stored
    }, 0)
    var contracted = Number(employee.contracted_weekly_hours || 0)
    addDataRow(data, 'Odpracováno tento týden', (minutes / 60).toLocaleString('cs-CZ', { minimumFractionDigits: 0, maximumFractionDigits: 1 }) + ' hodin')
    addDataRow(data, 'Týdenní fond', contracted ? contracted.toLocaleString('cs-CZ') + ' hodin' : 'Neuvedeno')
    addDataRow(data, 'Zbývá do fondu', contracted ? Math.max(0, contracted - minutes / 60).toLocaleString('cs-CZ', { maximumFractionDigits: 1 }) + ' hodin' : 'Nelze vypočítat')
  }

  function renderAll() {
    renderOverview()
    renderTerritory()
    renderBonuses()
    renderInventories()
    renderPayslips()
    renderShifts()
    renderRequests()
    renderWorktime()
    renderPersonal()
  }

  function resetForm() {
    var today = todayIso()
    root.querySelector('#op-request-type').value = 'vacation'
    root.querySelector('#op-date-from').value = today
    root.querySelector('#op-date-to').value = today
    root.querySelector('#op-duration').value = 'full_day'
    root.querySelector('#op-time-from').value = ''
    root.querySelector('#op-time-to').value = ''
    root.querySelector('#op-time-row').hidden = true
    root.querySelector('#op-reason').value = ''
  }

  function saveRequest(event) {
    event.preventDefault()
    var dateFrom = root.querySelector('#op-date-from').value
    var dateTo = root.querySelector('#op-date-to').value
    var timed = root.querySelector('#op-duration').value === 'time_range'
    var timeFrom = timed ? root.querySelector('#op-time-from').value : null
    var timeTo = timed ? root.querySelector('#op-time-to').value : null
    var reason = root.querySelector('#op-reason').value.trim()
    if (!dateFrom || !dateTo || dateTo < dateFrom) { toast('Zkontrolujte datum od a do.', true); return }
    if (timed && (!timeFrom || !timeTo || timeTo <= timeFrom)) { toast('Zkontrolujte čas od a do.', true); return }
    if (!reason) { toast('Doplňte stručný důvod žádosti.', true); return }
    var payload = {
      employee_id: employee.id, request_type: root.querySelector('#op-request-type').value, status: 'pending',
      date_from: dateFrom, date_to: dateTo, start_time: timeFrom, end_time: timeTo, reason: reason,
      manager_note: null, created_by_employee_id: employee.id, approved_by_employee_id: null, approved_at: null
    }
    showBusy(true, 'Odesílám žádost…')
    requestJson(supabaseUrl + '/rest/v1/hr_requests', { method: 'POST', headers: { Prefer: 'return=representation' }, body: JSON.stringify(payload) })
      .then(function () { return loadRequests() })
      .then(function () { renderAll(); resetForm(); openView('requests'); toast('Žádost byla odeslána ke schválení.') })
      .catch(function (error) { toast(error.message || 'Žádost se nepodařilo odeslat.', true) })
      .then(function () { showBusy(false) })
  }

  function cancelRequest(id) {
    if (!window.confirm('Opravdu chcete tuto čekající žádost zrušit?')) return
    showBusy(true, 'Ruším žádost…')
    var url = supabaseUrl + '/rest/v1/hr_requests?id=eq.' + encodeURIComponent(id) + '&employee_id=eq.' + encodeURIComponent(employee.id) + '&status=eq.pending'
    requestJson(url, { method: 'PATCH', headers: { Prefer: 'return=minimal' }, body: JSON.stringify({ status: 'cancelled', approved_by_employee_id: null, approved_at: null, updated_at: new Date().toISOString() }) })
      .then(function () { return loadRequests() })
      .then(function () { renderAll(); toast('Žádost byla zrušena.') })
      .catch(function (error) { toast(error.message || 'Žádost se nepodařilo zrušit.', true) })
      .then(function () { showBusy(false) })
  }

  function bind() {
    root.querySelector('#op-home').addEventListener('click', function () { window.location.href = './uvod.html' })
    root.querySelector('.op-user').addEventListener('click', function () { openView('overview') })
    Array.prototype.forEach.call(root.querySelectorAll('[data-open-view]'), function (button) {
      button.addEventListener('click', function () { openView(button.getAttribute('data-open-view')) })
    })
    root.querySelector('#op-new-request').addEventListener('click', function () { resetForm(); openView('request-form') })
    root.querySelector('#op-duration').addEventListener('change', function (event) { root.querySelector('#op-time-row').hidden = event.target.value !== 'time_range' })
    root.querySelector('#op-date-from').addEventListener('change', function (event) {
      var to = root.querySelector('#op-date-to')
      if (!to.value || to.value < event.target.value) to.value = event.target.value
    })
    root.querySelector('#op-request-form').addEventListener('submit', saveRequest)
    root.querySelector('#op-map-fit').addEventListener('click', function () { fitTerritoryMap(territoryMaps.detail, 12) })
  }

  bind()
  resetForm()

  window.operatorProfileStart = function (activeSession, activeEmployee) {
    session = activeSession
    employee = activeEmployee || {}
    if (!employee.id && !(session && session.user && session.user.id)) { showBusy(false); toast('Profil zaměstnance se nepodařilo načíst.', true); return }
    loadEmployee().then(function () {
      return Promise.allSettled([loadAttendance(), loadRequests(), loadShifts(), loadTerritory(), loadPayslips(), loadBonuses(), loadInventories()])
    }).then(function (results) {
      var failed = results.filter(function (result) { return result.status === 'rejected' })
      renderAll()
      showBusy(false)
      if (failed.length) toast('Část údajů se nepodařilo načíst. Zkuste profil obnovit.', true)
    }).catch(function (error) {
      showBusy(false)
      toast(error && error.message ? error.message : 'Profil zaměstnance se nepodařilo načíst.', true)
    })
  }
})()
