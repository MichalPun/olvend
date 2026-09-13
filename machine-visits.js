const rows = value => Array.isArray(value) ? value : value ? [value] : []
const statuses = { completed:'Dokončeno', arrived:'Na místě', skipped:'Přeskočeno', draft:'Rozpracováno', sync_error:'Chyba synchronizace' }
const date = value => value ? new Date(value).toLocaleString('cs-CZ', { dateStyle:'medium', timeStyle:'short' }) : 'Bez času'
const quantity = value => value == null ? '—' : Number(value).toLocaleString('cs-CZ', { maximumFractionDigits:3 })
const node = (tag, className, text) => {
  const element = document.createElement(tag)
  if (className) element.className = className
  if (text != null) element.textContent = text
  return element
}

export function renderVisitDetails(container, visit) {
  container.replaceChildren()
  container.append(node('p', '', `Příjezd: ${date(visit.arrived_at)} · Dokončení: ${date(visit.completed_at)}`))
  if (visit.skip_reason) container.append(node('p', '', `Důvod přeskočení: ${visit.skip_reason}`))
  if (visit.operator_note) container.append(node('p', '', visit.operator_note))
  const items = rows(visit.route_machine_visit_items)
  const fills = rows(visit.route_machine_visit_food_fills)
  const list = node('div', 'machine-visit-items')
  for (const item of items) {
    const card = node('div', 'machine-visit-item')
    card.append(node('strong', '', [item.physical_position_label || item.telemetry_key, item.actual_product_name || item.planned_product_name || 'Bez produktu'].filter(Boolean).join(' · ')))
    const unit = item.unit || 'ks'
    card.append(node('small', '', `Před: ${quantity(item.actual_before_quantity)} ${unit} · Doplněno: ${quantity(item.actual_add_quantity)} ${unit} · Odebráno: ${quantity(item.removed_quantity)} ${unit} · Po: ${quantity(item.final_quantity)} ${unit}`))
    for (const fill of fills.filter(fill => String(fill.visit_item_id) === String(item.id))) {
      card.append(node('small', '', `${fill.product_name || fill.product_sku || 'Produkt'} · ${quantity(fill.quantity)} ks${fill.expiry_date ? ` · expirace ${new Date(fill.expiry_date + 'T12:00:00').toLocaleDateString('cs-CZ')}` : ''}`))
    }
    if (item.operator_note) card.append(node('small', '', item.operator_note))
    if (item.substitution_reason) card.append(node('small', '', `Náhrada: ${item.substitution_reason}`))
    list.append(card)
  }
  if (items.length) container.append(node('strong', '', 'Doplnění a odebrané zboží'), list)
  else container.append(node('p', '', 'Bez zapsaných položek doplnění.'))
  for (const cash of rows(visit.route_machine_cash_reports)) {
    const card = node('div', 'machine-visit-item')
    card.append(node('strong', '', 'Hotovost'), node('small', '', `Výběr: ${cash.operator_collected_confirmed ? 'potvrzen' : 'nepotvrzen'} · Sáček: ${cash.operator_bag_label || '—'} · Přepočítáno: ${quantity(cash.supervisor_counted_cash_czk)} Kč`))
    if (cash.note) card.append(node('small', '', cash.note))
    container.append(card)
  }
  const checks = rows(visit.route_machine_visit_checks)
  if (checks.length) {
    const list = node('ul', '')
    for (const check of checks) list.append(node('li', '', `${check.label || check.check_key}: ${{done:'Hotovo', completed:'Hotovo', ok:'V pořádku', pending:'Čeká', skipped:'Přeskočeno', failed:'Nesplněno'}[check.status] || check.status || 'Bez stavu'}${check.operator_note ? ` · ${check.operator_note}` : ''}`))
    container.append(node('strong', '', 'Kontrola automatu'), list)
  }
  if (visit.route_plan_id) {
    const link = node('a', 'mini-btn', 'Otevřít trasu')
    link.href = `./routes-detail.html?id=${encodeURIComponent(visit.route_plan_id)}`
    container.append(link)
  }
}

export function initMachineVisits(container, supabase, machineId) {
  const list = node('div', 'machine-visits-list')
  const message = node('div', 'machine-visits-message', 'Načítám návštěvy…')
  message.setAttribute('aria-live', 'polite')
  const more = node('button', 'mini-btn machine-visits-more', 'Načíst starší návštěvy')
  more.type = 'button'
  more.hidden = true
  container.replaceChildren(list, message, more)
  let offset = 0, busy = false
  async function load() {
    if (busy) return
    busy = true; more.disabled = true
    message.textContent = 'Načítám návštěvy…'
    try {
      const {data, error} = await supabase.from('route_machine_visits')
        .select('id, employee_id, route_plan_id, status, visit_date, arrived_at, completed_at, created_at')
        .eq('machine_id', machineId).order('visit_date', {ascending:false, nullsFirst:false}).order('created_at', {ascending:false}).order('id', {ascending:false}).range(offset, offset + 4)
      if (error) throw error
      const visits = data || []
      const ids = [...new Set(visits.map(v => v.employee_id).filter(Boolean))]
      let employees = []
      if (ids.length) {
        const result = await supabase.from('employees').select('id,name,surname').in('id', ids)
        if (result.error) throw result.error
        employees = result.data || []
      }
      for (const visit of visits) {
        const employee = employees.find(e => String(e.id) === String(visit.employee_id))
        const detail = node('details', 'machine-visit')
        const summary = node('summary', '', date(visit.completed_at || visit.arrived_at || visit.created_at || visit.visit_date))
        summary.append(node('span', '', [employee ? [employee.name,employee.surname].filter(Boolean).join(' ') : 'Operátor neuveden', statuses[visit.status] || visit.status || 'Bez stavu'].join(' · ')))
        const body = node('div', 'machine-visit-body')
        detail.append(summary, body)
        let loaded = false, loading = false
        async function loadDetail() {
          if (loaded || loading) return
          loading = true
          body.replaceChildren(node('p', '', 'Načítám záznam návštěvy…'))
          try {
            const result = await supabase.from('route_machine_visits')
              .select('id,route_plan_id,arrived_at,completed_at,skip_reason,operator_note,route_machine_visit_items(id,physical_position_label,telemetry_key,planned_product_name,actual_product_name,actual_before_quantity,actual_add_quantity,removed_quantity,final_quantity,unit,operator_note,substitution_reason),route_machine_visit_food_fills(visit_item_id,product_name,product_sku,quantity,expiry_date),route_machine_cash_reports(operator_bag_label,operator_collected_confirmed,supervisor_counted_cash_czk,note),route_machine_visit_checks(check_key,label,status,operator_note)')
              .eq('machine_id', machineId).eq('id', visit.id).single()
            if (result.error) throw result.error
            renderVisitDetails(body, result.data)
            loaded = true
          } catch (error) {
            body.replaceChildren(node('p', '', `Návštěvu se nepodařilo načíst: ${error.message}`))
            const retry = node('button', 'mini-btn', 'Zkusit znovu'); retry.type = 'button'; retry.onclick = loadDetail; body.append(retry)
          } finally { loading = false }
        }
        detail.addEventListener('toggle', () => { if (detail.open) loadDetail() })
        list.append(detail)
      }
      offset += visits.length
      message.textContent = offset ? `Zobrazeno návštěv: ${offset}` : 'U tohoto automatu zatím není zapsaná žádná návštěva.'
      more.hidden = visits.length < 5
      more.textContent = 'Načíst starší návštěvy'
    } catch (error) {
      message.textContent = `Návštěvy se nepodařilo načíst: ${error.message}`
      more.hidden = false; more.textContent = 'Zkusit znovu'
    } finally { busy = false; more.disabled = false }
  }
  more.onclick = load
  return load()
}
