import { supabase } from './supabase.js'

const $ = (selector) => document.querySelector(selector)
const money = (value) => `${Number(value || 0).toLocaleString('cs-CZ', { maximumFractionDigits: 2 })} Kč`
const percent = (value) => Number.isFinite(Number(value)) ? `${Number(value).toFixed(1).replace('.', ',')} %` : '—'
const escapeHtml = (value) => String(value ?? '').replace(/[&<>'"]/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' }[char]))
const dateLabel = (value) => value ? new Intl.DateTimeFormat('cs-CZ', { day: 'numeric', month: 'numeric', year: 'numeric' }).format(new Date(`${value}T12:00:00`)) : 'nenaplánována'

const categoryDefaults = [
  { id: 'beverage_ready', name: 'Studené nápoje', note: 'PET, plech, voda', margin: 34, color: '#2572d4' },
  { id: 'snack_ready', name: 'Snacky', note: 'sladké a slané', margin: 38, color: '#a149a8' },
  { id: 'food_ready', name: 'Čerstvé', note: 'bagety a chlazené', margin: 32, color: '#14845a' },
  { id: 'coffee', name: 'Teplé nápoje', note: 'káva, čaj a kakao', margin: 42, color: '#7a4c2c' },
  { id: 'other', name: 'Ostatní', note: 'ostatní prodejní položky', margin: 35, color: '#687386' }
]

const state = {
  machineId: null,
  machine: null,
  products: [],
  categories: categoryDefaults.map((item) => ({ ...item })),
  selected: new Set(),
  prices: new Map(),
  activeProductId: null,
  pendingBatches: [],
  approvedBatch: null,
  loading: false
}

function categoryFor(product) {
  return state.categories.find((item) => item.id === product.category_key) || state.categories.find((item) => item.id === 'other')
}

function marginAt(product, grossPrice) {
  const price = Number(grossPrice || 0)
  const cost = Number(product.purchase_price_czk)
  const vat = Number(product.vat_rate || 0)
  if (!price || !Number.isFinite(cost)) return null
  const net = price / (1 + vat / 100)
  return net > 0 ? ((net - cost) / net) * 100 : null
}

function marketValues(product) {
  return (product.benchmark?.sources || []).map((source) => Number(source.price_czk)).filter((value) => Number.isFinite(value) && value > 0).sort((a, b) => a - b)
}

function marketMedian(product) {
  const values = marketValues(product)
  if (!values.length) return null
  const middle = Math.floor(values.length / 2)
  return values.length % 2 ? values[middle] : (values[middle - 1] + values[middle]) / 2
}

function minimumPrice(product) {
  const cost = Number(product.purchase_price_czk)
  const vat = Number(product.vat_rate || 0)
  const limit = Number(categoryFor(product).margin || 0)
  if (!Number.isFinite(cost) || limit >= 100) return Number(product.current_price_czk || 0)
  return cost / (1 - limit / 100) * (1 + vat / 100)
}

function recommendedPrice(product) {
  const step = Number($('#rounding')?.value || 1)
  const market = marketMedian(product)
  const raw = Math.max(minimumPrice(product), market || 0)
  return Math.ceil(raw / step) * step
}

function proposedPrice(product) {
  return state.prices.has(productKey(product)) ? Number(state.prices.get(productKey(product))) : recommendedPrice(product)
}

function productKey(product) {
  return `${product.target_type}:${product.target_id}`
}

function isChange(product) {
  return Math.abs(proposedPrice(product) - Number(product.current_price_czk || 0)) > 0.009
}

function statusFor(product) {
  if (product.pending_item) return { label: `Čeká sada ${product.pending_item.batch_id.slice(0, 8)}`, cls: 'amber' }
  if (!Number.isFinite(Number(product.purchase_price_czk))) return { label: 'Chybí nákupní cena', cls: 'red' }
  const margin = marginAt(product, proposedPrice(product))
  const limit = Number(categoryFor(product).margin)
  if (margin === null || margin + 0.01 < limit) return { label: `Pod limitem · ${percent(margin)}`, cls: 'red' }
  return isChange(product) ? { label: `Nová marže ${percent(margin)}`, cls: 'green' } : { label: 'Beze změny', cls: '' }
}

function showToast(message, error = false) {
  const toast = $('#toast')
  toast.textContent = message
  toast.style.background = error ? '#b42318' : '#1f2a37'
  toast.classList.add('show')
  clearTimeout(showToast.timer)
  showToast.timer = setTimeout(() => toast.classList.remove('show'), 3200)
}

function setBusy(busy) {
  state.loading = busy
  $('#saveDraft').disabled = busy
  updateSummary()
}

async function loadMachines() {
  const { data, error } = await supabase.from('machines').select('id,name,evidence_number,machine_type,brand,model,location_id,locations(name,city)').eq('active', true).order('evidence_number')
  if (error) throw error
  const select = $('#machineSelect')
  select.innerHTML = (data || []).map((machine) => `<option value="${machine.id}">EV ${escapeHtml(machine.evidence_number || machine.id)} · ${escapeHtml(machine.name || machine.model || 'Automat')}</option>`).join('')
  const requested = Number(new URLSearchParams(location.search).get('machine'))
  const initial = (data || []).some((item) => Number(item.id) === requested) ? requested : Number(data?.[0]?.id)
  if (!initial) throw new Error('V evidenci není žádný aktivní automat.')
  select.value = String(initial)
  await loadMachine(initial)
}

async function loadMachine(machineId) {
  setBusy(true)
  try {
    const { data, error } = await supabase.rpc('get_machine_pricing_context_v55', { p_machine_id: machineId })
    if (error) throw error
    state.machineId = Number(machineId)
    state.machine = data.machine
    state.products = (data.products || []).map((item) => ({ ...item, category_key: categoryDefaults.some((cat) => cat.id === item.category_key) ? item.category_key : 'other' }))
    state.pendingBatches = data.pending_batches || []
    state.categories = categoryDefaults.map((base) => {
      const saved = (data.rules || []).find((rule) => rule.category_key === base.id)
      return { ...base, margin: saved ? Number(saved.minimum_margin_percent) : base.margin }
    })
    const savedStep = Number(data.rules?.[0]?.rounding_step_czk || 1)
    $('#rounding').value = savedStep === 5 ? '5' : '1'
    state.selected = new Set(state.products.filter((item) => !item.pending_item).map(productKey))
    state.prices.clear()
    state.activeProductId = state.products[0] ? productKey(state.products[0]) : null
    state.approvedBatch = state.pendingBatches[0] || null
    history.replaceState(null, '', `machine-pricing.html?machine=${machineId}`)
    renderMachine(data.next_visit_date)
    renderCategories()
    renderRows()
    renderInspector()
    renderPendingBatch()
  } finally {
    setBusy(false)
  }
}

function renderPendingBatch() {
  const batch = state.approvedBatch
  const pendingCount = state.products.filter((item) => item.pending_item).length
  if (!batch) {
    $('#draftStatus').className = 'status-chip draft'; $('#draftStatus').textContent = 'Rozpracovaný návrh'; $('#draftStatus').style.color = ''
    $('#handoffState').className = 'pill'; $('#handoffState').textContent = 'Čeká na schválení'
    $('#routeState').className = 'pill amber'; $('#routeState').textContent = 'Vznikne'
    $('#printState').className = 'pill amber'; $('#printState').textContent = 'Vznikne'
    $('#routeCard').classList.remove('ready'); $('#printCard').classList.remove('ready')
    $('#printLink').href = `price-label-print.html?machine=${state.machineId}`; $('#printLink').setAttribute('aria-disabled', 'true')
    $('#approve').textContent = 'Schválit a vytvořit změnu'; $('#topApprove').textContent = 'Schválit nové ceny'
    return
  }
  $('#draftStatus').className = 'status-chip'; $('#draftStatus').textContent = `Sada ${batch.batch_code} čeká na provedení`; $('#draftStatus').style.color = 'var(--green)'
  $('#handoffState').className = 'pill green'; $('#handoffState').textContent = 'Připraveno k provedení'
  $('#routeState').className = 'pill green'; $('#routeState').textContent = 'Úkol vytvořen'
  $('#printState').className = 'pill green'; $('#printState').textContent = 'Připraveno'
  $('#routeCard').classList.add('ready'); $('#printCard').classList.add('ready')
  $('#printLink').href = `price-label-print.html?batch=${batch.id}`; $('#printLink').removeAttribute('aria-disabled')
  $('#routeDetail').textContent = `${pendingCount} pozic čeká na fyzickou změnu`
  $('#labelDetail').textContent = `${pendingCount} cenových štítků v sadě ${batch.batch_code}`
}

function renderMachine(nextVisitDate) {
  const machine = state.machine
  const ev = machine.evidence_number || machine.id
  const model = [machine.brand, machine.model].filter(Boolean).join(' ') || machine.machine_type || machine.name
  $('#machineIcon').textContent = ev
  $('#machineName').textContent = `EV ${ev} · ${model}`
  $('#machineLocation').textContent = [machine.location_name, machine.location_city, machine.machine_type].filter(Boolean).join(' · ')
  $('#breadcrumbMachine').textContent = `EV ${ev} · ${machine.location_name || machine.name || 'Automat'}`
  $('#activePositionCount').textContent = state.products.length
  $('#nextVisit').textContent = dateLabel(nextVisitDate)
  document.querySelector('.flow-step:first-child small').textContent = `EV ${ev} vybrán`
  document.querySelector('.route-number').textContent = ev
  document.querySelector('#approveDialog .dialog-head h2').textContent = `Schválit nové ceny pro EV ${ev}?`
}

function renderCategories() {
  $('#categoryGrid').innerHTML = state.categories.map((item) => `<article class="category-card" style="--category:${item.color}" data-category-card="${item.id}"><strong>${escapeHtml(item.name)}</strong><small>${escapeHtml(item.note)}</small><div class="margin-control"><input class="margin-input" data-margin="${item.id}" type="number" min="0" max="95" step="0.5" value="${item.margin}" aria-label="Minimální marže ${escapeHtml(item.name)}"><span class="suffix">% marže</span></div></article>`).join('')
  $('#categoryFilter').innerHTML = '<option value="">Všechny kategorie</option>' + state.categories.map((item) => `<option value="${item.id}">${escapeHtml(item.name)}</option>`).join('')
}

function renderRows() {
  const query = $('#search').value.trim().toLocaleLowerCase('cs')
  const category = $('#categoryFilter').value
  const filter = $('#stateFilter').value
  const onlyChanges = $('#onlyChanges').checked
  const visible = state.products.filter((product) => {
    const currentMargin = marginAt(product, product.current_price_czk)
    const limit = Number(categoryFor(product).margin)
    const searchText = `${product.product_name} ${product.slot_code} ${product.product_sku || ''}`.toLocaleLowerCase('cs')
    const matchesState = !filter || (filter === 'below' && currentMargin !== null && currentMargin < limit) || (filter === 'change' && isChange(product)) || (filter === 'ok' && !isChange(product))
    return (!query || searchText.includes(query)) && (!category || product.category_key === category) && matchesState && (!onlyChanges || isChange(product))
  })
  $('#priceRows').innerHTML = visible.map((product) => {
    const key = productKey(product)
    const currentMargin = marginAt(product, product.current_price_czk)
    const result = statusFor(product)
    const values = marketValues(product)
    const selected = state.selected.has(key)
    const categoryItem = categoryFor(product)
    const marketLabel = values.length ? `${money(values[0])}–${money(values.at(-1))}` : 'Bez srovnání'
    const marketSub = values.length ? `medián ${money(marketMedian(product))} · ${values.length} zdrojů` : 'jiný automat se stejným SKU nenalezen'
    return `<tr data-product="${escapeHtml(key)}" class="${selected ? 'selected' : ''}"><td><input class="row-check product-check" type="checkbox" data-key="${escapeHtml(key)}" ${selected ? 'checked' : ''} ${product.pending_item ? 'disabled' : ''}></td><td><div class="product"><strong>${escapeHtml(product.product_name)}</strong><small>Pozice ${escapeHtml(product.slot_code)} · ${escapeHtml(product.product_sku || 'bez SKU')}</small></div></td><td><span class="pill" style="border-color:${categoryItem.color}44;color:${categoryItem.color};background:${categoryItem.color}0d">${escapeHtml(categoryItem.name)}</span></td><td><span class="money"><strong>${Number.isFinite(Number(product.purchase_price_czk)) ? Number(product.purchase_price_czk).toFixed(2).replace('.', ',') + ' Kč' : '—'}</strong><small>DPH ${Number(product.vat_rate || 0)} %</small></span></td><td><span class="money"><strong>${money(product.current_price_czk)}</strong><small>${percent(currentMargin)} marže</small></span></td><td><button class="market-button ${state.activeProductId === key ? 'active' : ''}" data-market="${escapeHtml(key)}" type="button"><strong>${marketLabel}</strong><small>${marketSub}</small></button></td><td><b>${categoryItem.margin} %</b><div class="product"><small>min. ${money(minimumPrice(product))}</small></div></td><td><span class="money"><strong>${money(recommendedPrice(product))}</strong><small>splní limit</small></span></td><td><div class="proposal"><input class="price-input ${result.cls === 'red' ? 'invalid' : ''}" data-price="${escapeHtml(key)}" type="number" min="1" step="1" value="${proposedPrice(product)}" ${product.pending_item ? 'disabled' : ''}><span>Kč</span></div></td><td><span class="pill ${result.cls}">${escapeHtml(result.label)}</span></td></tr>`
  }).join('') || '<tr><td colspan="10" style="padding:28px;text-align:center;color:var(--muted)">Žádná položka neodpovídá filtru.</td></tr>'
  $('#visibleRows').textContent = `${visible.length} ${visible.length === 1 ? 'položka' : visible.length > 1 && visible.length < 5 ? 'položky' : 'položek'}`
  $('#selectAll').checked = state.products.filter((item) => !item.pending_item).every((item) => state.selected.has(productKey(item)))
  updateSummary()
}

function renderInspector() {
  const product = state.products.find((item) => productKey(item) === state.activeProductId) || state.products[0]
  if (!product) {
    $('#marketInspector').innerHTML = '<p>Automat nemá aktivní prodejní pozice.</p>'
    return
  }
  const values = marketValues(product)
  const sources = product.benchmark?.sources || []
  $('#marketInspector').innerHTML = `<div class="inspector-kicker">Interní cenový benchmark</div><h3>${escapeHtml(product.product_name)}</h3><p>Srovnání stejného SKU na ostatních aktivních automatech. Slouží jako informace, cenu samo nepřepisuje.</p><div class="market-summary"><div class="market-metric"><span>Minimum</span><strong>${values.length ? money(values[0]) : '—'}</strong></div><div class="market-metric"><span>Medián</span><strong>${values.length ? money(marketMedian(product)) : '—'}</strong></div><div class="market-metric"><span>Maximum</span><strong>${values.length ? money(values.at(-1)) : '—'}</strong></div><div class="market-metric"><span>Náš návrh</span><strong>${money(proposedPrice(product))}</strong></div></div><div class="source-list">${sources.slice(0, 8).map((source) => `<div class="source"><div><strong>EV ${escapeHtml(source.evidence_number || source.machine_id)} · ${escapeHtml(source.location_name || source.machine_name || 'Automat')}</strong><small>${escapeHtml(source.machine_name || '')}</small></div><span class="source-price">${money(source.price_czk)}</span></div>`).join('') || '<div class="inspector-note">Pro toto SKU zatím není cena na jiném automatu.</div>'}</div><div class="inspector-note"><b>Zdroj:</b> aktuální ceny z evidence vlastních automatů. U schválené sady se ukládá i tento snapshot pro pozdější audit.</div>`
}

function updateSummary() {
  const eligible = state.products.filter((product) => Number.isFinite(Number(product.purchase_price_czk)))
  const changed = state.products.filter((product) => state.selected.has(productKey(product)) && !product.pending_item && isChange(product))
  const currentAverage = eligible.length ? eligible.reduce((sum, product) => sum + Number(marginAt(product, product.current_price_czk) || 0), 0) / eligible.length : null
  const proposedAverage = eligible.length ? eligible.reduce((sum, product) => sum + Number(marginAt(product, proposedPrice(product)) || 0), 0) / eligible.length : null
  const below = eligible.filter((product) => Number(marginAt(product, product.current_price_czk)) + 0.01 < Number(categoryFor(product).margin)).length
  const impact = changed.reduce((sum, product) => sum + (proposedPrice(product) - Number(product.current_price_czk || 0)) * 150, 0)
  $('#currentMargin').textContent = percent(currentAverage)
  $('#overviewCurrentMargin').textContent = percent(currentAverage)
  $('#belowLimitCount').textContent = below
  $('#weightedMargin').textContent = percent(proposedAverage)
  $('#marginDelta').textContent = currentAverage === null || proposedAverage === null ? 'nelze spočítat' : `${proposedAverage >= currentAverage ? '+' : ''}${(proposedAverage - currentAverage).toFixed(1).replace('.', ',')} procentního bodu`
  $('#profitImpact').textContent = `${impact >= 0 ? '+' : ''}${Math.round(impact).toLocaleString('cs-CZ')} Kč`
  $('#changeCount').textContent = `${changed.length} ${changed.length === 1 ? 'cena' : changed.length > 1 && changed.length < 5 ? 'ceny' : 'cen'}`
  $('#unchangedCount').textContent = `${state.products.length - changed.length} položek zůstane beze změny`
  const ev = state.machine?.evidence_number || state.machine?.id || '—'
  $('#approvalSummary').textContent = `Připraveno ke schválení: ${changed.length} nových cen pro EV ${ev}`
  $('#routeDetail').textContent = `${changed.length} pozic · nejbližší jízda ${$('#nextVisit').textContent}`
  $('#labelDetail').textContent = `${changed.length} cenových štítků · pozice zůstávají stejné`
  $('#dialogLead').textContent = `Schvalujete ${changed.length} změn. Aktuální ceny zůstanou platné do fyzického provedení.`
  const invalid = changed.some((product) => statusFor(product).cls === 'red')
  $('#approve').disabled = $('#topApprove').disabled = state.loading || changed.length === 0 || invalid || Boolean(state.approvedBatch)
}

function rulesPayload() {
  const step = Number($('#rounding').value || 1)
  return state.categories.map((item) => ({ category_key: item.id, minimum_margin_percent: item.margin, rounding_step_czk: step }))
}

async function saveRules(showConfirmation = true) {
  const { error } = await supabase.rpc('save_machine_pricing_rules_v55', { p_machine_id: state.machineId, p_rules: rulesPayload() })
  if (error) throw error
  document.querySelectorAll('.category-card.changed').forEach((card) => card.classList.remove('changed'))
  if (showConfirmation) showToast('Pravidla marží pro automat byla uložena.')
}

function changedProducts() {
  return state.products.filter((product) => state.selected.has(productKey(product)) && !product.pending_item && isChange(product))
}

function openApproval() {
  const changed = changedProducts()
  if (!changed.length) return showToast('Není vybraná žádná změna ceny.', true)
  if (changed.some((product) => statusFor(product).cls === 'red')) return showToast('Některá vybraná cena nesplňuje minimální marži nebo nemá nákupní cenu.', true)
  $('#approveDialog').showModal()
}

async function approve() {
  setBusy(true)
  $('#confirmApprove').disabled = true
  try {
    const items = changedProducts().map((product) => ({
      target_type: product.target_type,
      target_id: product.target_id,
      category_key: product.category_key,
      purchase_price_czk: product.purchase_price_czk,
      vat_rate: product.vat_rate,
      minimum_margin_percent: categoryFor(product).margin,
      recommended_price_czk: recommendedPrice(product),
      new_price_czk: proposedPrice(product),
      benchmark_snapshot: product.benchmark || {}
    }))
    const { data, error } = await supabase.rpc('approve_machine_price_change_v55', { p_machine_id: state.machineId, p_items: items, p_rules: rulesPayload(), p_note: null })
    if (error) throw error
    state.approvedBatch = data
    $('#approveDialog').close()
    $('#draftStatus').className = 'status-chip'
    $('#draftStatus').textContent = `Sada ${data.batch_code} schválena`
    $('#draftStatus').style.color = 'var(--green)'
    $('#handoffState').className = 'pill green'; $('#handoffState').textContent = 'Připraveno k provedení'
    $('#routeState').className = 'pill green'; $('#routeState').textContent = 'Úkol vytvořen'
    $('#printState').className = 'pill green'; $('#printState').textContent = 'Připraveno'
    $('#routeCard').classList.add('ready'); $('#printCard').classList.add('ready')
    $('#printLink').href = data.print_url; $('#printLink').removeAttribute('aria-disabled')
    $('#approve').textContent = 'Ceny schváleny'; $('#topApprove').textContent = 'Ceny schváleny'
    document.querySelectorAll('.flow-step').forEach((step, index) => { step.classList.toggle('done', index < 3); step.classList.toggle('active', index === 3) })
    showToast(`Sada ${data.batch_code} je schválená. Úkol v jízdě i cenovky jsou připravené.`)
    await loadMachine(state.machineId)
  } finally {
    $('#confirmApprove').disabled = false
    setBusy(false)
  }
}

document.addEventListener('input', (event) => {
  if (event.target.matches('#search')) renderRows()
  if (event.target.matches('[data-margin]')) {
    const category = state.categories.find((item) => item.id === event.target.dataset.margin)
    category.margin = Math.max(0, Math.min(95, Number(event.target.value) || 0))
    event.target.closest('.category-card').classList.add('changed')
    updateSummary()
  }
  if (event.target.matches('[data-price]')) {
    state.prices.set(event.target.dataset.price, Number(event.target.value) || 0)
    renderInspector(); updateSummary()
  }
})

document.addEventListener('change', async (event) => {
  if (event.target.matches('#machineSelect')) {
    try { await loadMachine(Number(event.target.value)) } catch (error) { showToast(error.message, true) }
  }
  if (event.target.matches('[data-margin]')) { renderRows(); renderInspector() }
  if (event.target.matches('[data-price]')) { renderRows(); renderInspector() }
  if (event.target.matches('.product-check')) {
    event.target.checked ? state.selected.add(event.target.dataset.key) : state.selected.delete(event.target.dataset.key)
    renderRows()
  }
  if (event.target.matches('#selectAll')) {
    state.products.filter((item) => !item.pending_item).forEach((item) => event.target.checked ? state.selected.add(productKey(item)) : state.selected.delete(productKey(item)))
    renderRows()
  }
  if (event.target.matches('#categoryFilter,#stateFilter,#onlyChanges')) renderRows()
  if (event.target.matches('#rounding')) { state.prices.clear(); renderRows(); renderInspector() }
})

document.addEventListener('click', (event) => {
  const market = event.target.closest('[data-market]')
  if (market) { state.activeProductId = market.dataset.market; renderRows(); renderInspector() }
})

$('#applyRecommendations').addEventListener('click', () => { state.products.filter((item) => !item.pending_item).forEach((item) => state.prices.set(productKey(item), recommendedPrice(item))); renderRows(); renderInspector(); showToast('Doporučené ceny byly použity.') })
$('#resetPrices').addEventListener('click', () => { state.prices.clear(); renderRows(); renderInspector(); showToast('Ruční úpravy byly vráceny na doporučení.') })
$('#saveDraft').addEventListener('click', async () => { try { setBusy(true); await saveRules(true) } catch (error) { showToast(error.message, true) } finally { setBusy(false) } })
$('#approve').addEventListener('click', openApproval)
$('#topApprove').addEventListener('click', openApproval)
$('#cancelApprove').addEventListener('click', () => $('#approveDialog').close())
$('#confirmApprove').addEventListener('click', async () => { try { await approve() } catch (error) { showToast(error.message, true) } })
$('#reviewRoute').addEventListener('click', () => { $('#routeCard').scrollIntoView({ behavior: 'smooth', block: 'center' }); $('#routeCard').classList.add('changed-price'); setTimeout(() => $('#routeCard').classList.remove('changed-price'), 1100) })
$('#printLink').addEventListener('click', (event) => { if (!state.approvedBatch && !state.pendingBatches.length) { event.preventDefault(); showToast('Cenovky se zpřístupní po schválení nové sady cen.', true) } })

loadMachines().catch((error) => {
  console.error(error)
  $('#machineName').textContent = 'Cenotvorbu se nepodařilo načíst'
  $('#machineLocation').textContent = error.message
  showToast(error.message, true)
})
