import { supabase } from './supabase.js?v=20261115accounting1'
import {
  parseMoneyS3AccountingXml,
  validateMoneyAccountingPayload,
} from './accounting-money-import-core.mjs'

const $ = (id) => document.getElementById(id)
const localPreview = ['127.0.0.1', 'localhost'].includes(location.hostname) && new URL(location.href).searchParams.get('preview') === '1'
const state = {
  periods: [],
  activePeriodId: null,
  summary: null,
  accounts: [],
  preaccountings: [],
  imports: [],
  journal: [],
  trialBalance: [],
  importPreview: null,
  importFile: null,
  importHash: null,
}

const money = (value) => new Intl.NumberFormat('cs-CZ', {
  style: 'currency', currency: 'CZK', maximumFractionDigits: 2,
}).format(Number(value || 0))
const integer = (value) => new Intl.NumberFormat('cs-CZ').format(Number(value || 0))
const date = (value) => value ? new Intl.DateTimeFormat('cs-CZ').format(new Date(`${String(value).slice(0, 10)}T12:00:00`)) : '—'
const dateTime = (value) => value ? new Intl.DateTimeFormat('cs-CZ', { dateStyle:'short', timeStyle:'short' }).format(new Date(value)) : '—'
const escapeHtml = (value) => String(value ?? '').replace(/[&<>"']/g, (char) => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' }[char]))

function setStatus(message, type = '', meta = 'Bez zápisu do Money S3') {
  $('statusText').textContent = message
  $('statusMeta').textContent = meta
  $('statusStrip').className = `status-strip ${type}`.trim()
}

function missingSchema(error) {
  return /accounting_|schema cache|relation .* does not exist|could not find the table/i.test(String(error?.message || error || ''))
}

function statusBadge(status) {
  const definitions = {
    completed: ['Hotovo', 'good'],
    shadow_balanced: ['MD = Dal', 'good'],
    duplicate: ['Duplicitní', 'info'],
    imported: ['Importováno', 'info'],
    needs_review: ['Zkontrolovat', 'warn'],
    failed: ['Chyba', 'bad'],
    processing: ['Zpracovává se', 'info'],
    posted: ['Zaúčtováno', 'good'],
    reversed: ['Stornováno', 'warn'],
  }
  const [label, className] = definitions[status] || [status || '—', '']
  return `<span class="badge ${className}">${escapeHtml(label)}</span>`
}

function sourceLabel(value) {
  return ({
    received_invoice:'Přijatá faktura', issued_invoice:'Vydaná faktura', internal_document:'Interní doklad',
    bank_document:'Banka', cash_document:'Pokladna', liability:'Závazek', receivable:'Pohledávka',
  })[value] || value || '—'
}

function accountKind(value) {
  return ({ balance:'Rozvahový', profit_loss:'Výsledkový', closing:'Závěrkový', off_balance:'Podrozvahový', unspecified:'Neurčený' })[value] || value
}

function accountType(value) {
  return ({ asset:'Aktivní', liability:'Pasivní', expense:'Nákladový', revenue:'Výnosový', unspecified:'Neurčený' })[value] || value
}

function switchView(name) {
  document.querySelectorAll('[data-view]').forEach((button) => button.classList.toggle('active', button.dataset.view === name))
  document.querySelectorAll('[data-view-panel]').forEach((panel) => panel.classList.toggle('active', panel.dataset.viewPanel === name))
  const url = new URL(location.href)
  url.searchParams.set('view', name)
  history.replaceState(null, '', url)
}

function emptyRow(columns, message) {
  return `<tr><td colspan="${columns}"><div class="empty">${escapeHtml(message)}</div></td></tr>`
}

function renderPeriodSelect() {
  if (!state.periods.length) {
    $('periodSelect').innerHTML = '<option value="">Bez účetního období</option>'
    $('periodSelect').disabled = true
    return
  }
  $('periodSelect').disabled = false
  $('periodSelect').innerHTML = state.periods.map((period) => `<option value="${period.id}" ${String(period.id) === String(state.activePeriodId) ? 'selected' : ''}>${escapeHtml(period.code)} · ${escapeHtml(date(period.starts_on))}–${escapeHtml(date(period.ends_on))}</option>`).join('')
}

function renderMetrics() {
  const summary = state.summary || {}
  const debit = Number(summary.debit_total || 0)
  const credit = Number(summary.credit_total || 0)
  const difference = debit - credit
  const reviewCount = Number(summary.review_entry_count || 0) + state.accounts.filter((row) => row.source_incomplete).length
  $('metricAccounts').textContent = integer(summary.account_count ?? state.accounts.length)
  $('metricPreaccountings').textContent = integer(summary.preaccounting_count ?? state.preaccountings.length)
  $('metricEntries').textContent = integer(summary.entry_count ?? state.journal.length)
  $('metricBalance').textContent = Math.abs(difference) <= .01 ? 'Souhlasí' : money(difference)
  $('metricBalanceNote').textContent = state.journal.length ? `${money(debit)} MD · ${money(credit)} Dal` : 'Čekám na účetní deník'
  $('metricBalanceCard').className = `metric ${Math.abs(difference) <= .01 ? 'good' : 'bad'}`
  $('metricReview').textContent = integer(reviewCount + state.imports.reduce((sum, row) => sum + Number(row.warning_count || 0), 0))
  $('metricReviewCard').className = `metric ${reviewCount ? 'warn' : 'good'}`
}

function importRows(rows, compact = false) {
  if (!rows.length) return emptyRow(compact ? 7 : 9, 'Zatím nebyl načten žádný Money XML soubor.')
  return rows.map((row) => `<tr>
    <td><strong>${escapeHtml(row.source_file_name)}</strong><div class="metric-note">${escapeHtml(String(row.source_file_sha256 || '').slice(0, 12))}…</div></td>
    <td>${escapeHtml(dateTime(row.imported_at))}</td>
    <td>${statusBadge(row.status)}</td>
    <td>${integer(row.account_count)}</td>
    <td>${integer(row.preaccounting_count)}</td>
    <td>${integer(row.entry_count)}</td>
    ${compact ? '' : `<td class="money">${escapeHtml(money(row.debit_total))}</td><td class="money">${escapeHtml(money(row.credit_total))}</td>`}
    <td>${Number(row.warning_count || 0) ? `<span class="badge warn">${integer(row.warning_count)}</span>` : '<span class="badge good">0</span>'}</td>
  </tr>`).join('')
}

function renderImports() {
  $('overviewImportsBody').innerHTML = importRows(state.imports.slice(0, 5), true)
  $('importsBody').innerHTML = importRows(state.imports)
}

function renderAccounts() {
  const query = $('accountSearch').value.trim().toLowerCase()
  const rows = state.accounts.filter((row) => !query || `${row.code} ${row.name}`.toLowerCase().includes(query))
  $('accountsBody').innerHTML = rows.length ? rows.map((row) => `<tr>
    <td><strong>${escapeHtml(row.code)}</strong></td>
    <td>${escapeHtml(row.name)}</td>
    <td>${escapeHtml(accountKind(row.kind))}</td>
    <td>${escapeHtml(accountType(row.account_type))}</td>
    <td>${row.tracks_balance ? '<span class="badge info">Sledovat</span>' : '—'}</td>
    <td>${row.affects_income_tax ? '<span class="badge good">Ovlivňuje</span>' : '—'}</td>
    <td>${row.source_incomplete ? '<span class="badge warn">Doplnit</span>' : '<span class="badge good">Money S3</span>'}</td>
  </tr>`).join('') : emptyRow(7, 'Účtový rozvrh pro toto období zatím není načtený.')
}

function renderJournal() {
  const query = $('journalSearch').value.trim().toLowerCase()
  const rows = state.journal.filter((row) => !query || `${row.source_document_number} ${row.description} ${row.variable_symbol}`.toLowerCase().includes(query))
  $('journalBody').innerHTML = rows.length ? rows.map((row) => `<tr>
    <td>${escapeHtml(date(row.entry_date))}</td>
    <td><strong>${escapeHtml(row.source_document_number || '—')}</strong><div class="metric-note">VS ${escapeHtml(row.variable_symbol || '—')}</div></td>
    <td>${escapeHtml(row.description)}</td>
    <td>${escapeHtml(sourceLabel(row.source_type))}</td>
    <td>${escapeHtml(row.preaccounting_code || '—')}</td>
    <td class="money">${escapeHtml(money(row.debit_total))}</td>
    <td class="money">${escapeHtml(money(row.credit_total))}</td>
    <td>${statusBadge(row.status)}</td>
  </tr>`).join('') : emptyRow(8, 'Účetní deník pro toto období zatím není načtený.')
}

function renderControls() {
  $('trialBalanceBody').innerHTML = state.trialBalance.length ? state.trialBalance.map((row) => `<tr>
    <td><strong>${escapeHtml(row.account_code)}</strong></td><td>${escapeHtml(row.account_name)}</td>
    <td class="money">${escapeHtml(money(row.debit_turnover))}</td><td class="money">${escapeHtml(money(row.credit_turnover))}</td>
    <td class="money">${escapeHtml(money(row.balance))}</td><td>${row.source_incomplete ? '<span class="badge warn">Doplnit účet</span>' : '<span class="badge good">OK</span>'}</td>
  </tr>`).join('') : emptyRow(6, 'Obratová předvaha se zobrazí po importu účetního deníku.')

  const missingAccounts = state.accounts.filter((row) => row.source_incomplete).length
  const reviewEntries = state.journal.filter((row) => row.status === 'needs_review').length
  const importWarnings = state.imports.reduce((sum, row) => sum + Number(row.warning_count || 0), 0)
  const controls = [
    { title:'Nevyrovnané nebo problematické zápisy', value:reviewEntries, note:'Doklady označené ke kontrole', bad:reviewEntries > 0 },
    { title:'Neúplné účty', value:missingAccounts, note:'Účty použité v deníku bez načtené osnovy', bad:missingAccounts > 0 },
    { title:'Varování importů', value:importWarnings, note:'Součet varování ze všech dávek období', bad:importWarnings > 0 },
  ]
  $('exceptionsList').innerHTML = controls.map((item) => `<div class="control"><div><strong>${escapeHtml(item.title)}</strong><span>${escapeHtml(item.note)}</span></div><span class="badge ${item.bad ? 'warn' : 'good'}">${integer(item.value)}</span></div>`).join('')
}

function renderAll() {
  renderPeriodSelect()
  renderMetrics()
  renderImports()
  renderAccounts()
  renderJournal()
  renderControls()
}

async function loadPeriods() {
  const { data, error } = await supabase.from('accounting_periods').select('id,entity_id,code,starts_on,ends_on,status').order('starts_on', { ascending:false })
  if (error) throw error
  state.periods = data || []
  if (!state.periods.some((row) => String(row.id) === String(state.activePeriodId))) state.activePeriodId = state.periods[0]?.id || null
}

async function loadPeriodData() {
  if (!state.activePeriodId) {
    Object.assign(state, { summary:null, accounts:[], preaccountings:[], imports:[], journal:[], trialBalance:[] })
    renderAll()
    setStatus('Účetní jádro je připravené. První období vznikne při načtení Money XML.', 'success')
    return
  }
  setStatus('Načítám účetní období…')
  const periodId = state.activePeriodId
  const [summary, accounts, preaccountings, imports, journal, trialBalance] = await Promise.all([
    supabase.from('accounting_control_summary_v1').select('*').eq('period_id', periodId).maybeSingle(),
    supabase.from('accounting_accounts').select('*').eq('period_id', periodId).eq('active', true).order('code'),
    supabase.from('accounting_preaccountings').select('id,code,document_type,description').eq('period_id', periodId).eq('active', true).order('code'),
    supabase.from('accounting_import_batches').select('*').eq('period_id', periodId).order('imported_at', { ascending:false }).limit(100),
    supabase.from('accounting_journal_overview_v1').select('*').eq('period_id', periodId).order('entry_date', { ascending:false }).limit(1000),
    supabase.from('accounting_trial_balance_v1').select('*').eq('period_id', periodId).order('account_code'),
  ])
  for (const result of [summary, accounts, preaccountings, imports, journal, trialBalance]) if (result.error) throw result.error
  state.summary = summary.data
  state.accounts = accounts.data || []
  state.preaccountings = preaccountings.data || []
  state.imports = imports.data || []
  state.journal = journal.data || []
  state.trialBalance = trialBalance.data || []
  renderAll()
  const period = state.periods.find((row) => String(row.id) === String(periodId))
  setStatus(`Účetní období ${period?.code || ''} je načtené ve stínovém režimu.`, 'success', `${integer(state.journal.length)} zápisů · bez zápisu do Money S3`)
}

async function loadPage() {
  try {
    if (localPreview) {
      state.periods = [{ id:'preview', code:'2026', starts_on:'2026-01-01', ends_on:'2026-12-31', status:'open' }]
      state.activePeriodId = 'preview'
      state.summary = { account_count:126, preaccounting_count:38, entry_count:1842, review_entry_count:2, debit_total:14823640.52, credit_total:14823640.52 }
      state.accounts = [
        { code:'211000', name:'Pokladna', kind:'balance', account_type:'asset', tracks_balance:true, affects_income_tax:false, source_incomplete:false },
        { code:'321000', name:'Dodavatelé', kind:'balance', account_type:'liability', tracks_balance:true, affects_income_tax:false, source_incomplete:false },
        { code:'501000', name:'Spotřeba materiálu', kind:'profit_loss', account_type:'expense', tracks_balance:false, affects_income_tax:true, source_incomplete:false },
      ]
      state.preaccountings = Array.from({ length:38 }, (_, index) => ({ id:index + 1 }))
      state.imports = [{ source_file_name:'money-ucetnictvi-2026-10.xml', source_file_sha256:'5d87d46c9dcb7e9b', imported_at:'2026-11-15T21:42:00Z', status:'completed', account_count:126, preaccounting_count:38, entry_count:1842, debit_total:14823640.52, credit_total:14823640.52, warning_count:0 }]
      state.journal = [
        { entry_date:'2026-10-31', source_document_number:'PF260418', description:'Nákup surovin', source_type:'received_invoice', preaccounting_code:'PF001', debit_total:21450, credit_total:21450, variable_symbol:'260418', status:'shadow_balanced' },
        { entry_date:'2026-10-31', source_document_number:'BV260093', description:'Úhrady dodavatelům', source_type:'bank_document', preaccounting_code:'VU001', debit_total:128940, credit_total:128940, variable_symbol:null, status:'shadow_balanced' },
      ]
      state.trialBalance = state.accounts.map((account, index) => ({ account_code:account.code, account_name:account.name, debit_turnover:(index + 1) * 125000, credit_turnover:index * 83000, balance:(index + 1) * 125000 - index * 83000, source_incomplete:false }))
      renderAll()
      setStatus('Vývojový náhled účetního jádra je připravený.', 'success', 'Ukázková data · bez zápisu')
      return
    }
    const { data } = await supabase.auth.getSession()
    if (!data?.session?.user) {
      location.href = 'index.html'
      return
    }
    await loadPeriods()
    await loadPeriodData()
  } catch (error) {
    console.error(error)
    if (missingSchema(error)) {
      setStatus('Účetní obrazovka je připravená, ale databázové jádro ještě není nasazené.', 'error', 'Spusťte database/accounting_core_v1.sql')
    } else {
      setStatus(`Účetnictví se nepodařilo načíst: ${error.message}`, 'error')
    }
    renderAll()
  }
}

async function sha256(buffer) {
  const digest = await crypto.subtle.digest('SHA-256', buffer)
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('')
}

function decodeMoneyXml(buffer) {
  const bytes = new Uint8Array(buffer)
  const header = new TextDecoder('latin1').decode(bytes.slice(0, 200))
  const encoding = header.match(/encoding=["']([^"']+)/i)?.[1]?.toLowerCase() || 'utf-8'
  const decoderName = /1250|windows-1250|cp1250/.test(encoding) ? 'windows-1250' : 'utf-8'
  return new TextDecoder(decoderName).decode(bytes)
}

function renderImportPreview(errors = []) {
  const parsed = state.importPreview
  $('importPreview').classList.toggle('show', Boolean(parsed || errors.length))
  if (!parsed) {
    $('runImportBtn').disabled = true
    return
  }
  $('previewFileName').textContent = state.importFile?.name || 'Money XML'
  $('previewPeriod').textContent = parsed.accounting_year_start && parsed.accounting_year_end
    ? `Účetní období ${date(parsed.accounting_year_start)}–${date(parsed.accounting_year_end)}` : 'Účetní období se nepodařilo určit'
  $('previewAccounts').textContent = integer(parsed.summary.accounts)
  $('previewPreaccountings').textContent = integer(parsed.summary.preaccountings)
  $('previewEntries').textContent = integer(parsed.summary.entries)
  $('previewLines').textContent = integer(parsed.summary.lines)
  $('previewDifference').textContent = money(Number(parsed.summary.debit) - Number(parsed.summary.credit))
  const messages = [...errors.map((message) => `CHYBA: ${message}`), ...(parsed.warnings || [])]
  $('previewWarnings').innerHTML = messages.length ? messages.map((message) => `<li>${escapeHtml(message)}</li>`).join('') : '<li style="color:var(--green)">Struktura XML prošla základní kontrolou.</li>'
  $('runImportBtn').disabled = errors.length > 0
}

async function selectMoneyFile(file) {
  state.importFile = file || null
  state.importPreview = null
  state.importHash = null
  if (!file) return renderImportPreview()
  if (!/\.xml$/i.test(file.name)) throw new Error('Vyberte XML soubor exportovaný z Money S3.')
  if (file.size > 25 * 1024 * 1024) throw new Error('XML je větší než 25 MB. Rozdělte export po jednotlivých měsících nebo agendách.')
  setStatus(`Kontroluji ${file.name}…`)
  const buffer = await file.arrayBuffer()
  state.importHash = await sha256(buffer)
  state.importPreview = parseMoneyS3AccountingXml(decodeMoneyXml(buffer))
  const errors = validateMoneyAccountingPayload(state.importPreview)
  renderImportPreview(errors)
  setStatus(errors.length ? `Soubor má ${errors.length} blokující kontroly.` : 'Money XML je připravené k bezpečnému importu.', errors.length ? 'error' : 'success')
}

async function runImport() {
  if (!state.importPreview || !state.importFile || !state.importHash) return
  const errors = validateMoneyAccountingPayload(state.importPreview)
  if (errors.length) throw new Error(errors[0])
  $('runImportBtn').disabled = true
  $('runImportBtn').textContent = 'Načítám…'
  setStatus('Načítám účetní struktury do stínového deníku OLVEND…')
  const { data, error } = await supabase.rpc('import_money_s3_accounting_v1', {
    p_payload: state.importPreview,
    p_file_name: state.importFile.name,
    p_file_sha256: state.importHash,
  })
  if (error) throw error
  state.importFile = null
  state.importPreview = null
  state.importHash = null
  $('moneyXmlFile').value = ''
  $('importPreview').classList.remove('show')
  $('runImportBtn').textContent = 'Načíst do stínového účetnictví'
  await loadPeriods()
  if (data?.period_id) state.activePeriodId = data.period_id
  await loadPeriodData()
  setStatus(data?.message || 'Money XML bylo načtené.', data?.status === 'needs_review' ? '' : 'success', `${integer(data?.entry_count)} zápisů · ${integer(data?.warning_count)} varování`)
}

document.querySelectorAll('[data-view]').forEach((button) => button.addEventListener('click', () => switchView(button.dataset.view)))
document.querySelectorAll('[data-go-view]').forEach((button) => button.addEventListener('click', () => switchView(button.dataset.goView)))
$('refreshBtn').addEventListener('click', loadPage)
$('periodSelect').addEventListener('change', async () => { state.activePeriodId = $('periodSelect').value || null; await loadPeriodData() })
$('accountSearch').addEventListener('input', renderAccounts)
$('journalSearch').addEventListener('input', renderJournal)
$('chooseFileBtn').addEventListener('click', () => $('moneyXmlFile').click())
$('moneyXmlFile').addEventListener('change', async () => {
  try { await selectMoneyFile($('moneyXmlFile').files?.[0]) }
  catch (error) { console.error(error); setStatus(error.message, 'error'); state.importPreview = null; renderImportPreview([error.message]) }
})
$('runImportBtn').addEventListener('click', async () => {
  try { await runImport() }
  catch (error) { console.error(error); setStatus(`Import se nepodařil: ${error.message}`, 'error'); $('runImportBtn').disabled = false; $('runImportBtn').textContent = 'Načíst do stínového účetnictví' }
})

if (window.OlvendSidebar) {
  window.OlvendSidebar.initMobileNav($('mobileNavShell'))
  window.OlvendSidebar.setActive('accounting')
}

const requestedView = new URL(location.href).searchParams.get('view')
if (['overview', 'imports', 'chart', 'journal', 'controls'].includes(requestedView)) switchView(requestedView)
loadPage()
