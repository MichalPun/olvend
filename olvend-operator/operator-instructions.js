(function () {
  'use strict'

  var supabaseUrl = 'https://rerjlkrhiytgscjerqgs.supabase.co'
  var supabaseKey = 'sb_publishable_A8OxCcapdNXAzQLjLsW5iA_XtGvBZ0S'
  var root = document.getElementById('operator-instructions')
  var session = null
  var employee = null
  var instructions = []
  var acknowledgements = []

  function apiHeaders(extra) {
    return Object.assign({ apikey: supabaseKey, Authorization: 'Bearer ' + session.access_token, 'Content-Type': 'application/json' }, extra || {})
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

  function todayIso() {
    try { return new Intl.DateTimeFormat('sv-SE', { timeZone: 'Europe/Prague' }).format(new Date()) }
    catch (_) { return new Date().toISOString().slice(0, 10) }
  }

  function formatDate(value) {
    if (!value) return ''
    return new Date(String(value).slice(0, 10) + 'T12:00:00').toLocaleDateString('cs-CZ', { day: 'numeric', month: 'numeric', year: 'numeric' })
  }

  function isActive(item) {
    var today = todayIso()
    var starts = item.is_persistent || !item.valid_from || String(item.valid_from).slice(0, 10) <= today
    var ends = item.is_persistent || !item.valid_to || String(item.valid_to).slice(0, 10) >= today
    var target = item.target_type === 'company'
      || (item.target_type === 'role' && String(item.target_role || '').toLowerCase() === String(employee.role || '').toLowerCase())
      || (item.target_type === 'employee' && String(item.target_employee_id || '') === String(employee.id || ''))
    return item.is_active !== false && starts && ends && target
  }

  function acknowledged(item) {
    return acknowledgements.some(function (row) { return String(row.instruction_id) === String(item.id) })
  }

  function pendingRequired() {
    return instructions.filter(function (item) { return item.requires_acknowledgement && !acknowledged(item) })
  }

  function loadInstructions() {
    var fields = 'id,title,message,target_type,target_employee_id,target_role,valid_from,valid_to,is_persistent,priority,requires_acknowledgement,is_active,attachment_url,attachment_label,created_at'
    var url = supabaseUrl + '/rest/v1/daily_instructions?select=' + encodeURIComponent(fields) + '&is_active=eq.true&order=created_at.desc&limit=100'
    return requestJson(url).catch(function (error) {
      if (!/attachment_url|attachment_label/i.test(String(error.message || ''))) throw error
      fields = 'id,title,message,target_type,target_employee_id,target_role,valid_from,valid_to,is_persistent,priority,requires_acknowledgement,is_active,created_at'
      return requestJson(supabaseUrl + '/rest/v1/daily_instructions?select=' + encodeURIComponent(fields) + '&is_active=eq.true&order=created_at.desc&limit=100')
    }).then(function (rows) {
      instructions = (Array.isArray(rows) ? rows : []).filter(isActive).sort(function (a, b) {
        var order = { critical: 0, important: 1, info: 2 }
        var priority = Number(order[a.priority] == null ? 3 : order[a.priority]) - Number(order[b.priority] == null ? 3 : order[b.priority])
        if (priority) return priority
        if (Boolean(a.requires_acknowledgement) !== Boolean(b.requires_acknowledgement)) return a.requires_acknowledgement ? -1 : 1
        return String(b.created_at || '').localeCompare(String(a.created_at || ''))
      })
    })
  }

  function loadAcknowledgements() {
    var ids = instructions.filter(function (item) { return item.requires_acknowledgement }).map(function (item) { return item.id })
    if (!ids.length) { acknowledgements = []; return Promise.resolve() }
    var url = supabaseUrl + '/rest/v1/instruction_acknowledgements?select=id,instruction_id,acknowledged_at&employee_id=eq.' + encodeURIComponent(employee.id)
      + '&instruction_id=in.(' + ids.map(encodeURIComponent).join(',') + ')'
    return requestJson(url).then(function (rows) { acknowledgements = Array.isArray(rows) ? rows : [] })
  }

  function priorityMeta(item) {
    if (item.priority === 'critical') return { label: 'Kritické', cls: 'critical' }
    if (item.priority === 'important') return { label: 'Důležité', cls: 'important' }
    return { label: 'Informace', cls: '' }
  }

  function validityLabel(item) {
    if (item.is_persistent) return 'Trvalý pokyn'
    if (item.valid_to && item.valid_to !== item.valid_from) return 'Platí ' + formatDate(item.valid_from) + '–' + formatDate(item.valid_to)
    return 'Platí ' + formatDate(item.valid_from)
  }

  function toast(message, isError) {
    var item = root.querySelector('#oi-toast')
    item.textContent = message
    item.classList.toggle('error', Boolean(isError))
    item.hidden = false
    window.clearTimeout(toast.timer)
    toast.timer = window.setTimeout(function () { item.hidden = true }, 3200)
  }

  function setBusy(active, label) {
    root.querySelector('#oi-busy-label').textContent = label || 'Načítám…'
    root.querySelector('#oi-busy').hidden = !active
  }

  function render() {
    var pending = pendingRequired()
    var completed = instructions.filter(function (item) { return item.requires_acknowledgement && acknowledged(item) })
    var other = instructions.filter(function (item) { return !item.requires_acknowledgement || acknowledged(item) })
    var summary = root.querySelector('#oi-summary')
    summary.classList.toggle('pending', Boolean(pending.length))
    root.querySelector('#oi-pending-count').textContent = String(pending.length)
    root.querySelector('#oi-summary-kicker').textContent = pending.length ? 'Před zahájením směny' : 'Aktuální stav'
    root.querySelector('#oi-summary-title').textContent = pending.length
      ? (pending.length === 1 ? 'Čeká 1 povinný pokyn' : 'Čekají ' + pending.length + ' povinné pokyny')
      : instructions.length ? 'Vše potřebné je potvrzené' : 'Dnes bez nových pokynů'
    root.querySelector('#oi-summary-copy').textContent = pending.length
      ? 'Otevřete pokyn a potvrďte, že jste se s ním seznámili.'
      : instructions.length ? 'Aktivní informace zůstávají dostupné níže.' : 'Můžete pokračovat k přípravě vozidla a zahájení směny.'
    root.querySelector('#oi-stat-pending').textContent = String(pending.length)
    root.querySelector('#oi-stat-active').textContent = String(instructions.length)
    root.querySelector('#oi-stat-done').textContent = String(completed.length)
    root.querySelector('#oi-pending-section').hidden = !pending.length
    root.querySelector('#oi-pending-label').textContent = pending.length === 1 ? '1 pokyn čeká' : pending.length + ' pokyny čekají'
    root.querySelector('#oi-active-count').textContent = other.length + (other.length === 1 ? ' položka' : other.length > 1 && other.length < 5 ? ' položky' : ' položek')

    var pendingList = root.querySelector('#oi-pending-list')
    var otherList = root.querySelector('#oi-other-list')
    pendingList.innerHTML = ''
    otherList.innerHTML = ''
    if (!instructions.length) {
      var empty = document.createElement('div')
      empty.className = 'oi-empty'
      var title = document.createElement('strong')
      var copy = document.createElement('span')
      title.textContent = 'Žádný aktivní pokyn'
      copy.textContent = 'Pokud vedoucí přidá nový pokyn, objeví se tady.'
      empty.appendChild(title); empty.appendChild(copy); otherList.appendChild(empty)
      return
    }

    instructions.forEach(function (item) {
      var done = acknowledged(item)
      var priority = priorityMeta(item)
      var card = document.createElement('article')
      card.className = 'oi-card' + (item.requires_acknowledgement && !done ? ' required' : '') + (item.priority === 'critical' ? ' critical' : '') + (done ? ' acknowledged' : '')
      var top = document.createElement('div')
      top.className = 'oi-card-top'
      var chip = document.createElement('span')
      chip.className = 'oi-chip ' + priority.cls
      chip.textContent = priority.label
      var state = document.createElement('span')
      state.className = 'oi-state ' + (item.requires_acknowledgement ? done ? 'done' : 'pending' : '')
      state.textContent = item.requires_acknowledgement ? done ? 'Potvrzeno' : 'Čeká na potvrzení' : 'Jen ke čtení'
      top.appendChild(chip); top.appendChild(state)
      var title = document.createElement('h3')
      title.textContent = item.title || 'Pokyn dne'
      var message = document.createElement('p')
      message.className = 'oi-message'
      message.textContent = item.message || ''
      var meta = document.createElement('div')
      meta.className = 'oi-meta'
      var validity = document.createElement('span')
      validity.textContent = validityLabel(item)
      meta.appendChild(validity)
      if (item.requires_acknowledgement) {
        var required = document.createElement('span')
        required.textContent = 'Vyžaduje potvrzení'
        meta.appendChild(required)
      }
      card.appendChild(top); card.appendChild(title); card.appendChild(message); card.appendChild(meta)

      if ((item.requires_acknowledgement && !done) || item.attachment_url) {
        var actions = document.createElement('div')
        actions.className = 'oi-actions' + (((item.requires_acknowledgement && !done) && item.attachment_url) ? '' : ' single')
        if (item.attachment_url) {
          var attachment = document.createElement('a')
          attachment.className = 'oi-secondary'
          attachment.href = item.attachment_url
          attachment.target = '_blank'
          attachment.rel = 'noopener noreferrer'
          attachment.textContent = item.attachment_label || 'Otevřít dokument'
          actions.appendChild(attachment)
        }
        if (item.requires_acknowledgement && !done) {
          var confirm = document.createElement('button')
          confirm.type = 'button'
          confirm.className = 'oi-primary'
          confirm.textContent = 'Přečetl jsem a potvrzuji'
          confirm.addEventListener('click', function () { acknowledge(item, confirm) })
          actions.appendChild(confirm)
        }
        card.appendChild(actions)
      }
      if (item.requires_acknowledgement && !done) pendingList.appendChild(card)
      else otherList.appendChild(card)
    })
  }

  function acknowledge(item, button) {
    button.disabled = true
    button.textContent = 'Ukládám potvrzení…'
    requestJson(supabaseUrl + '/rest/v1/instruction_acknowledgements?on_conflict=instruction_id,employee_id', {
      method: 'POST', headers: { Prefer: 'resolution=merge-duplicates,return=representation' },
      body: JSON.stringify({ instruction_id: item.id, employee_id: employee.id, acknowledged_at: new Date().toISOString() })
    }).then(function (rows) {
      var saved = Array.isArray(rows) && rows[0] ? rows[0] : { instruction_id: item.id, acknowledged_at: new Date().toISOString() }
      acknowledgements = acknowledgements.filter(function (row) { return String(row.instruction_id) !== String(item.id) })
      acknowledgements.push(saved)
      render()
      toast('Pokyn byl potvrzen.')
    }).catch(function (error) {
      button.disabled = false
      button.textContent = 'Přečetl jsem a potvrzuji'
      toast(error.message || 'Potvrzení se nepodařilo uložit.', true)
    })
  }

  root.querySelector('.oi-user').addEventListener('click', function () { window.location.href = './profil.html' })

  window.operatorInstructionsStart = function (activeSession, activeEmployee) {
    session = activeSession
    employee = activeEmployee || {}
    root.querySelector('.oi-user').textContent = String((employee.name || employee.first_name || 'O').charAt(0) + (employee.surname || employee.last_name || 'P').charAt(0)).toUpperCase()
    if (!employee.id) { toast('Profil zaměstnance se nepodařilo načíst.', true); setBusy(false); return }
    loadInstructions().then(loadAcknowledgements).then(function () { render(); setBusy(false) }).catch(function (error) {
      setBusy(false)
      toast(error.message || 'Pokyny se nepodařilo načíst.', true)
    })
  }
})()
