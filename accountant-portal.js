import { supabase } from './supabase.js'
import { mailApiDownload } from './mail-api.js'

const $ = (id) => document.getElementById(id)
const preview = new URL(location.href).searchParams.get('preview') === '1'
const money = (value) => new Intl.NumberFormat('cs-CZ', { style: 'currency', currency: 'CZK', maximumFractionDigits: 2 }).format(Number(value || 0))
const formatDate = (value) => value ? new Intl.DateTimeFormat('cs-CZ').format(new Date(`${value}T12:00:00`)) : '—'
const escapeHtml = (value) => String(value ?? '').replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]))

const demoPackages = [
  { id: 'demo-1', package_number: 'UCT-2026-11-01', period_start: '2026-11-01', period_end: '2026-11-30', document_count: 4, net_total: 94320, vat_total: 9059.40, gross_total: 103379.40, status: 'ready', storage_path: 'demo.zip' },
  { id: 'demo-2', package_number: 'UCT-2026-10-01', period_start: '2026-10-01', period_end: '2026-10-31', document_count: 48, net_total: 1061925.62, vat_total: 223004.38, gross_total: 1284930, status: 'accepted', storage_path: 'demo.zip' }
]
const demoDocuments = [
  { id: 1, number: 'FP260572', supplier: 'Microsoft Ireland Operations Ltd.', documentNumber: 'E0400P9N8K', taxable: '2026-11-16', net: 12980, vat: 0, total: 12980, payment: 'Uhrazeno' },
  { id: 2, number: 'FP260571', supplier: 'T-Mobile Czech Republic a.s.', documentNumber: '9211008844', taxable: '2026-11-14', net: 18460, vat: 3876.60, total: 22336.60, payment: 'Uhrazeno' },
  { id: 3, number: 'FP260570', supplier: 'ALZA.cz a.s.', documentNumber: 'FV-12688421', taxable: '2026-11-10', net: 24680, vat: 5182.80, total: 29862.80, payment: 'Neuhrazeno' },
  { id: 4, number: 'FP260569', supplier: 'UNIQA pojišťovna, a.s.', documentNumber: 'P-2026-4811', taxable: '2026-11-08', net: 38200, vat: 0, total: 38200, payment: 'Neuhrazeno' }
]

let packages = []
let packageData = null
let documents = []

function setStatus(text, type = '') {
  $('statusText').textContent = text
  $('statusStrip').className = `accountant-status ${type}`.trim()
}

function statusLabel(status) {
  if (status === 'accepted') return 'Převzato'
  if (status === 'ready') return 'Připraveno'
  return 'Předáno'
}

function periodLabel(row) {
  if (!row?.period_start || !row?.period_end) return 'Bez určeného období'
  const start = new Date(`${row.period_start}T12:00:00`)
  const end = new Date(`${row.period_end}T12:00:00`)
  if (start.getMonth() === end.getMonth() && start.getFullYear() === end.getFullYear()) {
    return new Intl.DateTimeFormat('cs-CZ', { month: 'long', year: 'numeric' }).format(end)
  }
  return `${formatDate(row.period_start)} – ${formatDate(row.period_end)}`
}

function renderPackages() {
  $('packageCount').textContent = packages.length
  $('packageList').innerHTML = packages.length ? packages.map((row) => `
    <button class="package-card ${row.id === packageData?.id ? 'active' : ''}" data-package-id="${escapeHtml(row.id)}" type="button">
      <span class="package-card-top"><strong>${escapeHtml(row.package_number || 'Účetní balíček')}</strong><span class="package-status ${row.status === 'accepted' ? 'accepted' : ''}">${statusLabel(row.status)}</span></span>
      <span class="package-period">${escapeHtml(periodLabel(row))}</span>
      <span class="package-card-bottom"><span>${Number(row.document_count || 0)} faktur</span><strong>${money(row.gross_total || (Number(row.net_total || 0) + Number(row.vat_total || 0)))}</strong></span>
    </button>`).join('') : '<div class="empty-package"><strong>Zatím tu nic není</strong><span>Jakmile OLVEND připraví faktury pro účetní, objeví se zde balíček ke stažení.</span></div>'
  document.querySelectorAll('.package-card').forEach((button) => button.addEventListener('click', () => selectPackage(button.dataset.packageId).catch((error) => setStatus(error.message, 'error'))))
}

function renderDocuments() {
  const net = documents.reduce((sum, row) => sum + Number(row.net || 0), 0)
  const vat = documents.reduce((sum, row) => sum + Number(row.vat || 0), 0)
  const total = documents.reduce((sum, row) => sum + Number(row.total || 0), 0)
  $('packageTitle').textContent = packageData?.package_number || 'Připravené faktury'
  $('packageDescription').textContent = packageData ? `${periodLabel(packageData)} · balíček obsahuje originální doklady a přehled evidence z OLVENDU.` : 'Vyberte předaný balíček a stáhněte si všechny podklady najednou nebo jednotlivé faktury.'
  $('metricReady').textContent = packageData?.document_count ?? documents.length
  $('metricPeriod').textContent = packageData ? periodLabel(packageData) : '—'
  $('metricNet').textContent = packageData ? money(packageData.net_total ?? net) : '—'
  $('metricVat').textContent = packageData ? money(packageData.vat_total ?? vat) : '—'
  $('metricTotal').textContent = packageData ? money(packageData.gross_total ?? total) : '—'
  $('accountantVisibleCount').textContent = documents.length
  $('accountantVisibleTotal').textContent = packageData ? money(packageData.gross_total ?? total) : '—'
  $('downloadReadyBtn').disabled = !packageData?.storage_path
  $('downloadHint').textContent = packageData?.storage_path ? 'ZIP s fakturami a evidencí' : 'Souhrnný ZIP se ještě připravuje'
  $('documentBody').innerHTML = documents.length ? documents.map((row) => `
    <tr>
      <td><strong class="invoice-number">${escapeHtml(row.number || '—')}</strong></td>
      <td><strong>${escapeHtml(row.supplier || '—')}</strong></td>
      <td>${escapeHtml(row.documentNumber || '—')}</td>
      <td>${formatDate(row.taxable)}</td>
      <td class="money"><strong>${money(row.total)}</strong></td>
      <td><span class="payment-status ${row.payment === 'Uhrazeno' ? 'paid' : ''}">${escapeHtml(row.payment)}</span></td>
      <td class="download-column"><button class="invoice-download" data-invoice-id="${row.id}" type="button"><span aria-hidden="true">↓</span> PDF</button></td>
    </tr>`).join('') : '<tr><td colspan="7"><div class="empty-state"><strong>V tomto balíčku nejsou žádné faktury.</strong><span>Pokud je to neočekávané, kontaktujte správce OLVENDU.</span></div></td></tr>'
  document.querySelectorAll('.invoice-download').forEach((button) => button.addEventListener('click', () => downloadStampedInvoice(Number(button.dataset.invoiceId)).catch((error) => setStatus(error.message, 'error'))))
  renderPackages()
}

function mapDocument(row) {
  return {
    id: row.id,
    number: row.internal_number,
    supplier: row.supplier_name,
    documentNumber: row.document_number || row.variable_symbol,
    taxable: row.taxable_date,
    net: Number(row.net_amount || 0),
    vat: Number(row.vat_amount || 0),
    total: Number(row.total_amount || 0),
    payment: row.payment_status === 'paid' ? 'Uhrazeno' : row.payment_status === 'partially_paid' ? 'Částečně uhrazeno' : 'Neuhrazeno'
  }
}

async function selectPackage(packageId) {
  const selected = packages.find((row) => String(row.id) === String(packageId))
  if (!selected) return
  packageData = selected
  documents = []
  renderDocuments()
  setStatus(`Načítám faktury z balíčku ${selected.package_number || ''}…`)
  if (preview) {
    documents = selected.id === 'demo-1' ? [...demoDocuments] : []
    renderDocuments()
    setStatus('Podklady jsou připravené ke stažení.', 'success')
    return
  }
  const { data: payload, error } = await supabase.rpc('finance_get_accounting_package_v1', { p_package_id: selected.id })
  if (error) throw error
  packageData = { ...selected, ...(payload?.package || {}) }
  documents = (payload?.documents || []).map(mapDocument)
  renderDocuments()
  setStatus('Podklady jsou připravené ke stažení.', 'success')
}

async function downloadStampedInvoice(invoiceId) {
  const row = documents.find((item) => item.id === invoiceId)
  if (preview) {
    setStatus(`Náhled: PDF ${row?.number || ''} by se nyní stáhlo.`, 'success')
    return
  }
  setStatus(`Připravuji PDF ${row?.number || ''}…`)
  const { blob, fileName } = await mailApiDownload(`/finance/invoice-stamped?id=${encodeURIComponent(invoiceId)}`)
  const href = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = href
  link.download = fileName
  document.body.appendChild(link)
  link.click()
  link.remove()
  window.setTimeout(() => URL.revokeObjectURL(href), 30000)
  setStatus(`PDF ${row?.number || ''} bylo staženo.`, 'success')
}

async function downloadBatch() {
  if (preview) {
    setStatus(`Náhled: balíček ${packageData?.package_number || ''} by se nyní stáhl jako ZIP.`, 'success')
    return
  }
  if (!packageData?.storage_path) throw new Error('Souhrnný ZIP pro tento balíček zatím není připravený.')
  setStatus('Připravuji stažení celého balíčku…')
  const { data, error } = await supabase.storage.from('finance-private').createSignedUrl(packageData.storage_path, 300)
  if (error) throw error
  if (!data?.signedUrl) throw new Error('Odkaz ke stažení se nepodařilo vytvořit.')
  location.href = data.signedUrl
}

async function logout() {
  $('logoutBtn').disabled = true
  await supabase.auth.signOut({ scope: 'local' })
  location.replace('accountant-login.html')
}

async function initialize() {
  if (preview) {
    $('accountantUserEmail').textContent = 'ucetni@firma.cz · ukázka'
    packages = [...demoPackages]
    renderPackages()
    await selectPackage(packages[0].id)
    return
  }
  const { data: sessionData } = await supabase.auth.getSession()
  $('accountantUserEmail').textContent = sessionData?.session?.user?.email || 'Přihlášený uživatel'
  const { data: scope, error: scopeError } = await supabase.rpc('finance_portal_scope_v1')
  if (scopeError || !['accountant', 'internal'].includes(scope)) throw new Error('Pro tento účet není přístup k podkladům aktivní.')
  const { data, error } = await supabase.from('finance_accounting_packages').select('*').neq('status', 'draft').order('period_end', { ascending: false }).limit(24)
  if (error) throw error
  packages = data || []
  renderPackages()
  if (packages.length) await selectPackage(packages[0].id)
  else {
    packageData = null
    documents = []
    renderDocuments()
    setStatus('Zatím nebyl předán žádný účetní balíček.')
  }
}

$('downloadReadyBtn').addEventListener('click', () => downloadBatch().catch((error) => setStatus(error.message, 'error')))
$('logoutBtn').addEventListener('click', () => logout().catch((error) => setStatus(error.message, 'error')))

initialize().catch((error) => {
  packages = []
  packageData = null
  documents = []
  renderPackages()
  renderDocuments()
  setStatus(`Portál se nepodařilo načíst: ${error.message}`, 'error')
})
