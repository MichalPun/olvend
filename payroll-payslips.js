import { supabase } from './supabase.js'

const el = {
  sourceTab: document.getElementById('payrollSourceTab'),
  payslipsTab: document.getElementById('payrollPayslipsTab'),
  openButton: document.getElementById('openPayslipsBtn'),
  view: document.getElementById('payslipsView'),
  list: document.getElementById('payslipEmployeeList'),
  detail: document.getElementById('payslipDetail'),
  preview: document.getElementById('payslipPreview'),
  period: document.getElementById('payslipPeriodLabel'),
  summary: document.getElementById('payslipSummary'),
  reload: document.getElementById('payslipReloadBtn')
}

const state = {
  context: window.olvendPayrollContext || null,
  payslips: [],
  items: [],
  selectedEmployeeId: null,
  inventory: [],
  busy: false
}

const esc = (value) => String(value ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')
const money = (value) => new Intl.NumberFormat('cs-CZ', { style: 'currency', currency: 'CZK', maximumFractionDigits: 2 }).format(Number(value || 0))
const monthLabel = (period) => period ? new Date(`${period}T00:00:00`).toLocaleDateString('cs-CZ', { month: 'long', year: 'numeric' }) : '—'
const payslipFor = (employeeId) => state.payslips.find((row) => String(row.employee_id) === String(employeeId)) || null
const itemsFor = (payslipId) => state.items.filter((item) => String(item.payslip_id) === String(payslipId))
const selectedEmployee = () => state.context?.rows?.find((row) => String(row.id) === String(state.selectedEmployeeId)) || null

function setView(name) {
  const payslips = name === 'payslips'
  document.querySelectorAll('[data-payroll-source]').forEach((node) => { node.hidden = payslips })
  el.view.hidden = !payslips
  el.sourceTab.classList.toggle('active', !payslips)
  el.payslipsTab.classList.toggle('active', payslips)
  if (payslips) refresh().catch(showFatal)
}

function showFatal(error) {
  console.error(error)
  const unavailable = error?.code === 'PGRST205' || String(error?.message || '').includes("payroll_payslips")
  el.detail.innerHTML = `<div class="payslip-empty"><strong>${unavailable ? 'Databázová část výplatnic ještě není nasazená.' : 'Výplatnice se nepodařilo načíst.'}</strong><br>${unavailable ? 'Po nasazení zabezpečeného úložiště bude tato část automaticky připravená.' : esc(error?.message || error)}</div>`
  if (el.preview) el.preview.innerHTML = '<div class="payslip-empty">Náhled není dostupný.</div>'
}

function statusLabel(row) {
  if (!row) return ['Nenahráno', 'missing']
  return row.status === 'published' ? ['Publikováno', 'published'] : ['Rozpracováno', 'draft']
}

function renderList() {
  const rows = state.context?.rows || []
  const published = rows.filter((row) => payslipFor(row.id)?.status === 'published').length
  el.period.textContent = `Období ${monthLabel(state.context?.period)}`
  el.summary.textContent = `${published} z ${rows.length} publikováno`
  el.list.innerHTML = rows.map((employee) => {
    const payslip = payslipFor(employee.id)
    const [label, kind] = statusLabel(payslip)
    return `<button class="payslip-employee ${String(employee.id) === String(state.selectedEmployeeId) ? 'active' : ''}" type="button" data-payslip-employee="${esc(employee.id)}"><span><strong>${esc(employee.name)}</strong><small>${esc(employee.email || employee.employment_type || 'Bez e-mailu')}</small></span><span class="payslip-state ${kind}">${label}</span></button>`
  }).join('') || '<div class="payslip-empty">Nejsou načteni žádní zaměstnanci.</div>'
}

async function refresh() {
  if (!state.context?.period) {
    el.detail.innerHTML = '<div class="payslip-empty">Nejprve načtěte mzdové podklady pro vybraný měsíc.</div>'
    return
  }
  el.reload.disabled = true
  try {
    const { data: payslips, error } = await supabase.from('payroll_payslips').select('*').eq('period_month', state.context.period).order('employee_id')
    if (error) throw error
    state.payslips = payslips || []
    const ids = state.payslips.map((row) => row.id)
    if (ids.length) {
      const { data: items, error: itemError } = await supabase.from('payroll_payslip_items').select('*').in('payslip_id', ids).order('display_order')
      if (itemError) throw itemError
      state.items = items || []
    } else state.items = []
    if (!state.selectedEmployeeId && state.context.rows?.length) state.selectedEmployeeId = state.context.rows[0].id
    renderList()
    if (state.selectedEmployeeId) await selectEmployee(state.selectedEmployeeId)
  } finally {
    el.reload.disabled = false
  }
}

async function loadInventory(employeeId) {
  const { data, error } = await supabase.from('inventory_audits')
    .select('id,audit_date,note,difference_value_total,bonus_impact_amount,bonus_period,resolution_status,resolution_protocol,responsibility_status')
    .eq('assigned_employee_id', employeeId)
    .in('resolution_status', ['sent', 'acknowledged'])
    .order('audit_date', { ascending: false })
    .limit(50)
  if (error) throw error
  const period = state.context.period.slice(0, 7)
  state.inventory = (data || []).filter((audit) => String(audit.bonus_period || audit.audit_date || '').slice(0, 7) === period)
}

function auditAmount(audit) {
  const protocol = audit.resolution_protocol || {}
  return Math.max(0, Number(audit.bonus_impact_amount ?? protocol.charge_total ?? 0))
}

function draftItems(employee, payslip) {
  const stored = payslip ? itemsFor(payslip.id) : []
  const bonus = stored.find((item) => item.item_type === 'bonus') || {
    item_type: 'bonus', title: 'Prémie za období', amount: Number(employee.bonus || 0), explanation: '', included: Number(employee.bonus || 0) > 0, agreement_confirmed: false, display_order: 10
  }
  const storedByAudit = new Map(stored.filter((item) => item.source_type === 'inventory_audit').map((item) => [String(item.source_id), item]))
  const deductions = state.inventory.map((audit, index) => storedByAudit.get(String(audit.id)) || {
    item_type: 'deduction',
    title: `Inventurní rozdíl #${audit.id}`,
    amount: auditAmount(audit),
    explanation: audit.resolution_protocol?.manager_note || audit.note || '',
    source_type: 'inventory_audit',
    source_id: String(audit.id),
    source_label: `Inventura ${new Date(`${audit.audit_date}T00:00:00`).toLocaleDateString('cs-CZ')}`,
    included: false,
    agreement_confirmed: false,
    display_order: 100 + index
  })
  stored.filter((item) => item.item_type === 'deduction' && item.source_type !== 'inventory_audit').forEach((item) => deductions.push(item))
  return { bonus, deductions }
}

async function selectEmployee(employeeId) {
  state.selectedEmployeeId = employeeId
  renderList()
  el.detail.innerHTML = '<div class="payslip-empty">Načítám podklady zaměstnance…</div>'
  await loadInventory(employeeId)
  renderDetail()
}

function renderDetail(notice = '') {
  const employee = selectedEmployee()
  if (!employee) return
  const payslip = payslipFor(employee.id)
  const { bonus, deductions } = draftItems(employee, payslip)
  const locked = payslip?.status === 'published'
  const disabled = locked ? 'disabled' : ''
  const fileText = payslip?.file_name ? `<span class="payslip-file-current">${esc(payslip.file_name)}</span>` : '<span class="payslip-file-current">PDF zatím není nahrané</span>'
  el.detail.innerHTML = `
    <header class="payslip-editor-head"><div><h2>${esc(employee.name)}</h2><p>Výplatnice za ${esc(monthLabel(state.context.period))}</p></div><span class="payslip-state ${statusLabel(payslip)[1]}">${statusLabel(payslip)[0]}</span></header>
    <div class="payslip-editor">
      ${notice ? `<div class="payslip-notice ${notice.startsWith('Chyba:') ? 'error' : 'success'}">${esc(notice)}</div>` : ''}
      ${locked ? '<div class="payslip-notice">Výplatnice je zveřejněná zaměstnanci. Pro změnu ji nejprve vraťte do rozpracovaného stavu.</div>' : ''}
      <section class="payslip-block"><h3>1. Soubor výplatnice</h3><p>Nahrajte finální PDF od účetní. Dokument je uložený v soukromém úložišti.</p><div class="payslip-file-row">${fileText}<input id="payslipFile" type="file" accept="application/pdf,.pdf" ${disabled}>${payslip?.file_path ? '<button class="btn" id="previewPayslipBtn" type="button">Otevřít PDF</button>' : ''}</div></section>
      <div class="payslip-grid">
        <section class="payslip-block"><h3>2. Prémie</h3><label class="payslip-check"><input id="bonusIncluded" type="checkbox" ${bonus.included ? 'checked' : ''} ${disabled}> Zobrazit zaměstnanci rozpis prémie</label><div class="payslip-item-controls"><label class="payslip-field"><span>Částka</span><input id="bonusAmount" type="number" min="0" step="0.01" value="${esc(bonus.amount)}" ${disabled}></label><label class="payslip-field"><span>Název</span><input id="bonusTitle" value="${esc(bonus.title)}" ${disabled}></label></div><label class="payslip-field"><span>Vysvětlení / přenesení prémie</span><textarea id="bonusExplanation" placeholder="Např. část prémie převedena z minulého období…" ${disabled}>${esc(bonus.explanation || '')}</textarea></label></section>
        <section class="payslip-block"><h3>3. Komentář k výplatě</h3><p>Soukromá zpráva, kterou zaměstnanec uvidí vedle PDF.</p><label class="payslip-field"><span>Komentář</span><textarea id="generalMessage" placeholder="Např. vysvětlení mimořádné odměny nebo změny…" ${disabled}>${esc(payslip?.general_message || '')}</textarea></label></section>
      </div>
      <section class="payslip-block"><div class="payslip-block-heading"><div><h3>4. Srážky a inventurní rozdíly</h3><p>Uzavřené inventury se načtou automaticky. Další doloženou srážku můžete přidat ručně.</p></div>${locked ? '' : '<button class="btn" id="addManualDeductionBtn" type="button">+ Přidat ruční srážku</button>'}</div><div class="payslip-item-list">${deductions.length ? deductions.map((item, index) => `
        <article class="payslip-item" data-deduction-index="${index}" data-source-id="${esc(item.source_id || '')}" data-source-type="${esc(item.source_type || '')}" data-source-label="${esc(item.source_label || '')}">
          <div class="payslip-item-head"><div><strong>${esc(item.title)}</strong><small class="sub">${esc(item.source_label || 'Ruční položka')}</small></div><div class="payslip-item-head-actions"><span>${money(item.amount)}</span>${item.source_type !== 'inventory_audit' && !locked ? '<button type="button" data-remove-deduction>Odebrat</button>' : ''}</div></div>
          <label class="payslip-check"><input data-deduction-included type="checkbox" ${item.included ? 'checked' : ''} ${disabled}> Zahrnout do výplatnice</label>
          ${item.source_type !== 'inventory_audit' ? `<label class="payslip-field payslip-manual-title"><span>Název srážky</span><input data-deduction-title value="${esc(item.title)}" placeholder="Např. Dohodnutá náhrada škody" ${disabled}></label>` : ''}
          <div class="payslip-item-controls"><label class="payslip-field"><span>Částka</span><input data-deduction-amount type="number" min="0" step="0.01" value="${esc(item.amount)}" ${disabled}></label><label class="payslip-field"><span>Vysvětlení</span><input data-deduction-explanation value="${esc(item.explanation || '')}" placeholder="Důvod a způsob výpočtu" ${disabled}></label></div>
          <label class="payslip-check payslip-agreement"><input data-deduction-agreement type="checkbox" ${item.agreement_confirmed ? 'checked' : ''} ${disabled}> Potvrzuji, že je evidována dohoda / právní podklad pro tuto srážku.</label>
        </article>`).join('') : '<div class="payslip-empty" data-deduction-empty>Pro tento měsíc zatím nejsou zadané žádné srážky.</div>'}</div></section>
      <div class="payslip-actions">${locked ? '<button class="btn" id="reopenPayslipBtn" type="button">Vrátit k úpravě</button>' : '<button class="btn" id="savePayslipBtn" type="button">Uložit rozpracované</button><button class="btn red" id="publishPayslipBtn" type="button">Publikovat zaměstnanci</button>'}</div>
    </div>`
  bindDetailEvents()
  renderEmployeePreview()
}

function renderEmployeePreview() {
  if (!el.preview) return
  const employee = selectedEmployee()
  if (!employee) {
    el.preview.innerHTML = '<div class="payslip-empty">Vyberte zaměstnance pro náhled.</div>'
    return
  }
  const payslip = payslipFor(employee.id)
  const file = document.getElementById('payslipFile')?.files?.[0]
  const fileName = file?.name || payslip?.file_name || 'PDF zatím není nahrané'
  const message = document.getElementById('generalMessage')?.value?.trim() || ''
  const items = collectItems()
  const status = payslip?.status === 'published' ? 'Publikováno' : 'Náhled'
  el.preview.innerHTML = `<div class="payslip-preview-head"><strong>Náhled zaměstnance</strong><span>Mění se živě podle zadaných údajů. Zaměstnanec uvidí pouze vlastní publikovaný dokument.</span></div>
    <div class="employee-preview-shell"><div class="employee-preview-screen">
      <header class="employee-preview-top"><div><strong>Výplatnice</strong><small>${esc(monthLabel(state.context?.period))} · ${esc(employee.name)}</small></div><span class="employee-preview-new">${esc(status)}</span></header>
      <div class="employee-preview-body">
        ${message ? `<div class="employee-preview-message">${esc(message)}</div>` : ''}
        <div class="employee-preview-file"><b>PDF</b><div><strong>${esc(fileName)}</strong><small>${file || payslip?.file_path ? 'Dokument připravený k otevření' : 'Soubor bude dostupný po nahrání'}</small></div></div>
        ${items.length ? `<div class="employee-preview-items">${items.map((item) => `<div class="employee-preview-item ${item.item_type}"><div><strong>${esc(item.title)}</strong>${item.explanation ? `<small>${esc(item.explanation)}</small>` : ''}${item.source_label ? `<small>${esc(item.source_label)}</small>` : ''}</div><b>${item.item_type === 'deduction' ? '−' : '+'}${esc(money(item.amount))}</b></div>`).join('')}</div>` : '<div class="employee-preview-empty">Bez samostatně zobrazené prémie nebo srážky.</div>'}
      </div><footer class="employee-preview-foot">Moje → Dokumenty → Výplatnice</footer>
    </div></div>`
}

function collectItems(includeExcluded = false) {
  const items = []
  const bonusIncluded = Boolean(document.getElementById('bonusIncluded')?.checked)
  if (bonusIncluded || includeExcluded) items.push({
    item_type: 'bonus', title: document.getElementById('bonusTitle').value.trim() || 'Prémie za období', amount: Number(document.getElementById('bonusAmount').value || 0), explanation: document.getElementById('bonusExplanation').value.trim() || null, included: bonusIncluded, agreement_confirmed: false, display_order: 10
  })
  document.querySelectorAll('[data-deduction-index]').forEach((node, index) => {
    const included = node.querySelector('[data-deduction-included]').checked
    if (!included && !includeExcluded) return
    items.push({ item_type: 'deduction', title: node.querySelector('[data-deduction-title]')?.value.trim() || node.querySelector('.payslip-item-head strong').textContent.trim() || 'Ruční srážka', amount: Number(node.querySelector('[data-deduction-amount]').value || 0), explanation: node.querySelector('[data-deduction-explanation]').value.trim() || null, source_type: node.dataset.sourceType || null, source_id: node.dataset.sourceId || null, source_label: node.dataset.sourceLabel || null, agreement_confirmed: node.querySelector('[data-deduction-agreement]').checked, included, display_order: 100 + index })
  })
  return items
}

async function uploadPdf(employeeId, period, file) {
  if (!file) return null
  if (file.type !== 'application/pdf' && !file.name.toLowerCase().endsWith('.pdf')) throw new Error('Výplatnice musí být PDF.')
  if (file.size > 10 * 1024 * 1024) throw new Error('PDF může mít nejvýše 10 MB.')
  const safe = file.name.replace(/[^a-zA-Z0-9._-]+/g, '-').replace(/^-+|-+$/g, '') || 'vyplatnice.pdf'
  const token = crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-${Math.random().toString(16).slice(2)}`
  const path = `${employeeId}/${period.slice(0, 7)}/${token}-${safe}`
  const { error } = await supabase.storage.from('payroll-payslips').upload(path, file, { contentType: 'application/pdf', upsert: false })
  if (error) throw error
  return { path, name: file.name, size: file.size, type: 'application/pdf' }
}

async function save(status) {
  if (state.busy) return
  const employee = selectedEmployee()
  const existing = payslipFor(employee.id)
  const file = document.getElementById('payslipFile')?.files?.[0] || null
  const items = collectItems(true)
  if (status === 'published') {
    if (!state.context.currentEmployeeId) throw new Error('Přihlášený účet není propojený se zaměstnancem a nemůže dokument publikovat.')
    if (!file && !existing?.file_path) throw new Error('Nejprve nahrajte PDF výplatnice.')
    const invalid = items.find((item) => item.item_type === 'deduction' && item.included && (!item.agreement_confirmed || item.amount <= 0))
    if (invalid) throw new Error(`Srážku „${invalid.title}“ nelze publikovat bez evidované dohody a platné částky.`)
  }
  state.busy = true
  let uploaded = null
  try {
    uploaded = await uploadPdf(employee.id, state.context.period, file)
    const payload = {
      employee_id: employee.id,
      period_month: state.context.period,
      general_message: document.getElementById('generalMessage').value.trim() || null,
      status: 'draft',
      created_by: existing?.created_by || state.context.currentEmployeeId,
      published_at: null,
      published_by: null,
      read_at: null,
      ...(uploaded ? { file_path: uploaded.path, file_name: uploaded.name, file_size_bytes: uploaded.size, mime_type: uploaded.type } : {})
    }
    const { data: saved, error } = await supabase.from('payroll_payslips').upsert(payload, { onConflict: 'employee_id,period_month' }).select('*').single()
    if (error) throw error
    const { error: deleteError } = await supabase.from('payroll_payslip_items').delete().eq('payslip_id', saved.id)
    if (deleteError) throw deleteError
    if (items.length) {
      const { error: itemError } = await supabase.from('payroll_payslip_items').insert(items.map((item) => ({ ...item, payslip_id: saved.id })))
      if (itemError) throw itemError
    }
    if (status === 'published') {
      const { error: publishError } = await supabase.from('payroll_payslips').update({ status: 'published', published_at: new Date().toISOString(), published_by: state.context.currentEmployeeId, read_at: null }).eq('id', saved.id)
      if (publishError) throw publishError
    }
    if (uploaded && existing?.file_path && existing.file_path !== uploaded.path) await supabase.storage.from('payroll-payslips').remove([existing.file_path])
    await refresh()
    renderDetail(status === 'published' ? 'Výplatnice byla publikována zaměstnanci.' : 'Rozpracovaná výplatnice byla uložena.')
  } catch (error) {
    if (uploaded?.path) await supabase.storage.from('payroll-payslips').remove([uploaded.path])
    renderDetail(`Chyba: ${error.message}`)
  } finally {
    state.busy = false
  }
}

async function preview() {
  const payslip = payslipFor(state.selectedEmployeeId)
  if (!payslip?.file_path) return
  const { data, error } = await supabase.storage.from('payroll-payslips').createSignedUrl(payslip.file_path, 120)
  if (error) throw error
  window.open(data.signedUrl, '_blank', 'noopener')
}

async function reopen() {
  const payslip = payslipFor(state.selectedEmployeeId)
  if (!payslip) return
  const { error } = await supabase.from('payroll_payslips').update({ status: 'draft', published_at: null, published_by: null }).eq('id', payslip.id)
  if (error) throw error
  await refresh()
  renderDetail('Výplatnice byla vrácena k úpravě.')
}

function bindDetailEvents() {
  document.getElementById('savePayslipBtn')?.addEventListener('click', () => save('draft').catch((error) => renderDetail(`Chyba: ${error.message}`)))
  document.getElementById('publishPayslipBtn')?.addEventListener('click', () => save('published').catch((error) => renderDetail(`Chyba: ${error.message}`)))
  document.getElementById('previewPayslipBtn')?.addEventListener('click', () => preview().catch((error) => renderDetail(`Chyba: ${error.message}`)))
  document.getElementById('reopenPayslipBtn')?.addEventListener('click', () => reopen().catch((error) => renderDetail(`Chyba: ${error.message}`)))
  const bindPreviewInputs = (root) => root.querySelectorAll('input, textarea, select').forEach((input) => {
    input.addEventListener('input', () => {
      const item = input.closest('[data-deduction-index]')
      if (item && input.matches('[data-deduction-amount]')) item.querySelector('.payslip-item-head-actions span').textContent = money(input.value)
      if (item && input.matches('[data-deduction-title]')) item.querySelector('.payslip-item-head strong').textContent = input.value.trim() || 'Ruční srážka'
      renderEmployeePreview()
    })
    input.addEventListener('change', renderEmployeePreview)
  })
  bindPreviewInputs(el.detail)
  const list = el.detail.querySelector('.payslip-item-list')
  document.getElementById('addManualDeductionBtn')?.addEventListener('click', () => {
    list?.querySelector('[data-deduction-empty]')?.remove()
    const token = `manual-${Date.now()}`
    list?.insertAdjacentHTML('beforeend', `<article class="payslip-item" data-deduction-index="${token}" data-source-type="manual" data-source-label="Ručně zadaná položka"><div class="payslip-item-head"><div><strong>Ruční srážka</strong><small class="sub">Ručně zadaná položka</small></div><div class="payslip-item-head-actions"><span>0 Kč</span><button type="button" data-remove-deduction>Odebrat</button></div></div><label class="payslip-check"><input data-deduction-included type="checkbox"> Zahrnout do výplatnice</label><label class="payslip-field payslip-manual-title"><span>Název srážky</span><input data-deduction-title value="Ruční srážka" placeholder="Např. Dohodnutá náhrada škody"></label><div class="payslip-item-controls"><label class="payslip-field"><span>Částka</span><input data-deduction-amount type="number" min="0" step="0.01" value="0"></label><label class="payslip-field"><span>Vysvětlení</span><input data-deduction-explanation placeholder="Důvod a způsob výpočtu"></label></div><label class="payslip-check payslip-agreement"><input data-deduction-agreement type="checkbox"> Potvrzuji, že je evidována dohoda / právní podklad pro tuto srážku.</label></article>`)
    const added = list?.lastElementChild
    if (added) bindPreviewInputs(added)
    renderEmployeePreview()
  })
  list?.addEventListener('click', (event) => {
    const remove = event.target.closest('[data-remove-deduction]')
    if (!remove) return
    remove.closest('[data-deduction-index]')?.remove()
    if (!list.querySelector('[data-deduction-index]')) list.innerHTML = '<div class="payslip-empty" data-deduction-empty>Pro tento měsíc zatím nejsou zadané žádné srážky.</div>'
    renderEmployeePreview()
  })
}

document.addEventListener('olvend-payroll-loaded', (event) => {
  state.context = event.detail
  state.selectedEmployeeId = null
  if (!el.view.hidden) refresh().catch(showFatal)
})
el.sourceTab.addEventListener('click', () => setView('source'))
el.payslipsTab.addEventListener('click', () => setView('payslips'))
el.openButton.addEventListener('click', () => setView('payslips'))
el.reload.addEventListener('click', () => refresh().catch(showFatal))
el.list.addEventListener('click', (event) => {
  const button = event.target.closest('[data-payslip-employee]')
  if (button) selectEmployee(button.dataset.payslipEmployee).catch(showFatal)
})
