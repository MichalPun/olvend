import { ensureWarehouseSession, getOfflineRequestCount, supabase, syncOfflineRequests } from './supabase-zebra.js?zebra=20261102-v4'
import {
  escapeHtml,
  formatQuantity,
  getItemBaseQuantity,
  getPickingCategory,
  getPickingPackage,
  getStoragePosition,
  isHandledItem,
  isSkippedItem,
  normalizeText,
  parseQuantity,
  pluralizeItems,
  quantityFromBase,
  sortPickingItems
} from './warehouse-picking-core.mjs'

const app = document.getElementById('warehousePickingApp')
const elements = Object.fromEntries([...app.querySelectorAll('[id]')].map((element) => [element.id, element]))
const views = ['loadingView', 'requestsView', 'pickingView', 'summaryView', 'successView', 'emptyView', 'errorView']
const SNAPSHOT_KEY = 'olvendWarehousePickingSnapshotV1'
const QUEUE_KEY = 'olvendWarehousePickingQueueV1'
const PRODUCT_IMAGE_BUCKET = 'product-images'
const SNAPSHOT_FIELDS = ['me', 'warehouses', 'requests', 'items', 'products', 'packages', 'locations', 'balances', 'employees', 'vehicles', 'routes']

const state = {
  me: null,
  authUserId: null,
  warehouses: [],
  requests: [],
  items: [],
  products: [],
  packages: [],
  locations: [],
  balances: [],
  employees: [],
  vehicles: [],
  routes: [],
  activeRequest: null,
  activeItems: [],
  currentIndex: 0,
  unitMode: 'piece',
  quantityPieces: 0,
  deferredInstallPrompt: null,
  busy: false,
  syncing: false
}

function readJson(key, fallback) {
  try { return JSON.parse(localStorage.getItem(key) || JSON.stringify(fallback)) }
  catch (_) { return fallback }
}

function readQueue() { return readJson(QUEUE_KEY, []) }

function pendingCount() { return readQueue().length + getOfflineRequestCount() }

function writeQueue(queue) {
  localStorage.setItem(QUEUE_KEY, JSON.stringify(queue))
  updateConnection()
}

function saveSnapshot() {
  const snapshot = Object.fromEntries(SNAPSHOT_FIELDS.map((field) => [field, state[field]]))
  localStorage.setItem(SNAPSHOT_KEY, JSON.stringify({ ...snapshot, savedAt: new Date().toISOString() }))
}

function loadSnapshot() {
  const snapshot = readJson(SNAPSHOT_KEY, null)
  if (!snapshot?.savedAt) return false
  SNAPSHOT_FIELDS.forEach((field) => { state[field] = snapshot[field] || (field === 'me' ? null : []) })
  state.activeRequest = null
  state.activeItems = []
  return true
}

function updateLocalRow(table, id, payload) {
  const collection = table === 'mobile_stock_requests' ? state.requests : state.items
  const row = collection.find((candidate) => String(candidate.id) === String(id))
  if (row) Object.assign(row, payload)
  const activeItem = table === 'mobile_stock_request_items'
    ? state.activeItems.find((candidate) => String(candidate.id) === String(id))
    : null
  if (activeItem) Object.assign(activeItem, payload)
  if (table === 'mobile_stock_requests' && String(state.activeRequest?.id) === String(id)) Object.assign(state.activeRequest, payload)
  saveSnapshot()
}

function queueUpdate(table, id, payload) {
  const queue = readQueue()
  queue.push({ id: crypto.randomUUID(), table, rowId: id, payload, queuedAt: new Date().toISOString() })
  writeQueue(queue)
  updateLocalRow(table, id, payload)
}

function applyQueuedUpdates() {
  for (const action of readQueue()) updateLocalRow(action.table, action.rowId, action.payload)
}

function isNetworkError(error) {
  const text = String(error?.message || error || '').toLowerCase()
  return !navigator.onLine || error?.name === 'AbortError' || /fetch|network|offline|abort|failed to send/.test(text)
}

async function updateOrQueue(table, id, payload) {
  if (!navigator.onLine) {
    queueUpdate(table, id, payload)
    return { ...payload, __queued: true }
  }
  try {
    const sharedPendingBefore = getOfflineRequestCount()
    const { error } = await supabase.from(table).update(payload).eq('id', id)
    if (error) throw error
    updateLocalRow(table, id, payload)
    updateConnection()
    return getOfflineRequestCount() > sharedPendingBefore ? { ...payload, __queued: true } : payload
  } catch (error) {
    if (!isNetworkError(error)) throw error
    queueUpdate(table, id, payload)
    return { ...payload, __queued: true }
  }
}

async function syncQueue() {
  if (!navigator.onLine || state.syncing) return { synced: 0, pending: pendingCount() }
  state.syncing = true
  updateConnection()
  try {
    const queue = readQueue()
    const sharedResult = await syncOfflineRequests()
    if (sharedResult.pending) return { synced: sharedResult.synced, pending: pendingCount() }
    if (!queue.length) return { synced: sharedResult.synced, pending: 0 }
    let synced = 0
    const remaining = []
    for (let index = 0; index < queue.length; index += 1) {
      const action = queue[index]
      try {
        const { error } = await supabase.from(action.table).update(action.payload).eq('id', action.rowId)
        if (error) throw error
        updateLocalRow(action.table, action.rowId, action.payload)
        synced += 1
      } catch (error) {
        remaining.push(...queue.slice(index))
        if (!isNetworkError(error)) console.error('Offline frontu se nepodařilo synchronizovat:', error)
        break
      }
    }
    writeQueue(remaining)
    return { synced: synced + sharedResult.synced, pending: remaining.length }
  } finally {
    state.syncing = false
    updateConnection()
  }
}

function showView(id) {
  if (id !== 'loadingView') window.__warehousePickingReady = true
  views.forEach((viewId) => { elements[viewId].hidden = viewId !== id })
  if (elements.dashboardTiles) elements.dashboardTiles.hidden = !['requestsView', 'emptyView'].includes(id)
  window.scrollTo({ top: 0, behavior: 'instant' })
}

function setBootStage(message) {
  if (typeof window.__warehouseSetBootStage === 'function') window.__warehouseSetBootStage(message)
}

function showToast(message, type = '') {
  elements.toast.textContent = message
  elements.toast.className = `toast${type ? ` ${type}` : ''}`
  elements.toast.hidden = false
  window.clearTimeout(showToast.timer)
  showToast.timer = window.setTimeout(() => { elements.toast.hidden = true }, 3200)
}

function setBusy(busy) {
  state.busy = busy
  ;[elements.readyItemBtn, elements.finishRequestBtn, elements.skipItemBtn].forEach((button) => {
    if (button) button.disabled = busy
  })
}

function setSkipPanelOpen(open) {
  elements.skipPanel.hidden = !open
  elements.skipItemBtn.setAttribute('aria-expanded', String(open))
  if (open) {
    window.setTimeout(() => {
      if (typeof elements.skipPanel.scrollIntoView === 'function') elements.skipPanel.scrollIntoView(false)
    }, 0)
  }
}

function updateConnection() {
  const online = navigator.onLine
  const pending = pendingCount()
  elements.connectionState.textContent = state.syncing
    ? `Synchronizuji · ${pending}`
    : online
      ? (pending ? `Online · čeká ${pending}` : 'Online')
      : (pending ? `Offline · čeká ${pending}` : 'Offline')
  elements.connectionState.classList.toggle('offline', !online)
  renderDashboardTiles()
}

function renderDashboardTiles() {
  if (!elements.dashboardTiles) return
  const counts = state.requests.reduce((result, request) => {
    if (request.status === 'requested') result.waiting += 1
    if (request.status === 'picking') result.picking += 1
    if (request.status === 'ready') result.ready += 1
    return result
  }, { waiting: 0, picking: 0, ready: 0 })
  elements.waitingRequestCount.textContent = String(counts.waiting)
  elements.pickingRequestCount.textContent = String(counts.picking)
  elements.readyRequestCount.textContent = String(counts.ready)
  elements.pendingSyncCount.textContent = String(pendingCount())
}

function employeeName(id) {
  const employee = state.employees.find((row) => String(row.id) === String(id))
  return employee ? [employee.name, employee.surname].filter(Boolean).join(' ') || employee.email || 'Operátor' : 'Bez operátora'
}

function renderIdentity() {
  const employee = state.me
  if (!employee) return
  const fullName = [employee.name, employee.surname].filter(Boolean).join(' ') || employee.email || 'Pracovník OLVEND'
  const initials = [employee.name, employee.surname]
    .filter(Boolean)
    .map((part) => String(part).trim().charAt(0))
    .join('')
    .slice(0, 2)
    .toUpperCase() || 'OL'
  if (elements.currentUserInitials) elements.currentUserInitials.textContent = initials
  if (elements.logoutBtn) elements.logoutBtn.setAttribute('aria-label', `Přihlášený pracovník: ${fullName}. Klepnutím odhlásit.`)
}

function activeWarehouse() {
  const requestWarehouseIds = [...new Set(state.requests.map((request) => request.warehouse_id).filter(Boolean).map(String))]
  const selectedWarehouseId = state.activeRequest?.warehouse_id || (requestWarehouseIds.length === 1 ? requestWarehouseIds[0] : null)
  const selectedWarehouse = selectedWarehouseId
    ? state.warehouses.find((warehouse) => String(warehouse.id) === String(selectedWarehouseId))
    : null
  if (selectedWarehouse) return selectedWarehouse
  return state.warehouses.find((warehouse) => normalizeText(warehouse.code) === 'hlavni')
    || state.warehouses.find((warehouse) => normalizeText(warehouse.code) !== 'automaty')
    || state.warehouses[0]
    || null
}

function renderWarehouseContext() {
  if (!elements.brandUserLabel) return
  const warehouse = activeWarehouse()
  if (!warehouse) {
    elements.brandUserLabel.textContent = 'Skladové vychystávání'
    return
  }
  const prefix = normalizeText(warehouse.code) === 'hlavni' ? 'Hlavní sklad' : 'Sklad'
  elements.brandUserLabel.textContent = `${prefix} · ${warehouse.name || warehouse.code}`
}

function vehicleName(id) {
  const vehicle = state.vehicles.find((row) => String(row.id) === String(id))
  if (!vehicle) return 'Bez vozidla'
  return [vehicle.name || [vehicle.brand, vehicle.model].filter(Boolean).join(' '), vehicle.plate].filter(Boolean).join(' · ')
}

function routeName(request) {
  const route = state.routes.find((row) => String(row.id) === String(request?.route_plan_id))
  const title = route?.title || route?.name || 'Trasa'
  return request?.route_plan_id ? `${title} · #${request.route_plan_id}` : title
}

function requestItems(requestId) {
  return state.items.filter((item) => String(item.request_id) === String(requestId))
}

function productById(productId) {
  return state.products.find((product) => String(product.id) === String(productId)) || null
}

function locationForRequest(request, type) {
  const explicitId = type === 'warehouse' ? request.source_stock_location_id : request.target_stock_location_id
  if (explicitId) return state.locations.find((location) => String(location.id) === String(explicitId)) || null
  if (type === 'warehouse') {
    return state.locations.find((location) => location.location_type === 'warehouse' && String(location.warehouse_id) === String(request.warehouse_id)) || null
  }
  return state.locations.find((location) => location.location_type === 'vehicle' && String(location.vehicle_id) === String(request.vehicle_id)) || null
}

function stockAt(location, productId) {
  if (!location) return 0
  return state.balances
    .filter((balance) => String(balance.stock_location_id) === String(location.id) && String(balance.product_id) === String(productId))
    .reduce((total, balance) => total + Number(balance.quantity_on_hand || 0), 0)
}

function itemBaseQuantity(item, field = 'prepared_quantity') {
  return getItemBaseQuantity(item, productById(item.product_id), state.packages, field)
}

function otherReservations(request, item) {
  return state.requests
    .filter((candidate) => String(candidate.id) !== String(request.id)
      && ['requested', 'picking', 'ready'].includes(candidate.status)
      && String(candidate.warehouse_id || '') === String(request.warehouse_id || ''))
    .flatMap((candidate) => requestItems(candidate.id))
    .filter((candidateItem) => String(candidateItem.product_id) === String(item.product_id) && !isSkippedItem(candidateItem))
    .reduce((total, candidateItem) => total + itemBaseQuantity(candidateItem), 0)
}

function formatInMode(baseQuantity, item, product, pack) {
  if (state.unitMode === 'package' && pack) {
    return `${formatQuantity(quantityFromBase(baseQuantity, 'package', product, pack))} ${pack.package_name || 'bal.'}`
  }
  return `${formatQuantity(baseQuantity)} ${product?.base_unit || item?.unit || 'ks'}`
}

function productFallback(product, item) {
  const source = String(product?.name || item?.product_name || item?.sku || '?').trim()
  const words = source.split(/\s+/).filter(Boolean)
  return words.slice(0, 2).map((word) => word[0]).join('').toUpperCase() || '?'
}

function storagePositionLabel(product) {
  const position = getStoragePosition(product)
  if (!position) return 'Pozice ve skladu není uvedena'
  return /^[a-záčďéěíňóřšťúůýž]$/i.test(position) ? `Regál ${position.toUpperCase()}` : position
}

function productImageUrl(product) {
  const resolvedUrl = product?.image_url || (() => {
    const path = String(product?.image_path || '').trim()
    if (!path) return ''
    return path.startsWith('static:') ? path.slice('static:'.length) : ''
  })()
  if (!resolvedUrl) return ''
  const imageVersion = String(product?.image_updated_at || '').trim()
  if (!imageVersion) return resolvedUrl
  const separator = resolvedUrl.includes('?') ? '&' : '?'
  return `${resolvedUrl}${separator}olvend_image_v=${encodeURIComponent(imageVersion)}`
}

async function hydrateProductImages(products) {
  const remotePaths = [...new Set((products || [])
    .map((product) => String(product?.image_path || '').trim())
    .filter((path) => path && !path.startsWith('static:')))]
  const signedByPath = new Map()
  await Promise.all(remotePaths.map(async (path) => {
    const { data, error } = await supabase.storage.from(PRODUCT_IMAGE_BUCKET).createSignedUrl(path, 12 * 60 * 60)
    if (!error && data?.signedUrl) signedByPath.set(path, data.signedUrl)
  }))
  return (products || []).map((product) => ({
    ...product,
    image_url: String(product?.image_path || '').startsWith('static:')
      ? String(product.image_path).slice('static:'.length)
      : signedByPath.get(String(product?.image_path || '').trim()) || ''
  }))
}

function renderRequests() {
  renderIdentity()
  renderWarehouseContext()
  renderDashboardTiles()
  if (elements.lastRefreshLabel) {
    elements.lastRefreshLabel.textContent = new Date().toLocaleTimeString('cs-CZ', { hour: '2-digit', minute: '2-digit' })
  }
  const rows = [...state.requests].sort((left, right) => {
    const readyDifference = Number(left.status === 'ready') - Number(right.status === 'ready')
    if (readyDifference) return readyDifference
    return String(right.created_at || '').localeCompare(String(left.created_at || ''))
  })
  if (!rows.length) {
    showView('emptyView')
    return
  }
  elements.requestList.innerHTML = rows.map((request) => {
    const items = requestItems(request.id)
    const handled = items.filter(isHandledItem).length
    const ready = request.status === 'ready'
    const status = ready ? 'Čeká na převzetí' : request.status === 'picking' ? 'Vychystává se' : 'Čeká na sklad'
    return `<button class="request-card${ready ? ' ready' : ''}" type="button" data-request-id="${escapeHtml(request.id)}">
      <span class="request-head"><strong>${escapeHtml(vehicleName(request.vehicle_id))}</strong><span class="status-pill">${escapeHtml(status)}</span></span>
      <p>${escapeHtml(routeName(request))} · ${escapeHtml(employeeName(request.employee_id))}</p>
      <span class="request-foot"><span>Požadavek #${escapeHtml(request.id)}</span><b>${escapeHtml(`${handled}/${items.length}`)}</b></span>
    </button>`
  }).join('')
  showView('requestsView')
}

function renderRouteHeader() {
  const request = state.activeRequest
  elements.vehicleLabel.textContent = vehicleName(request.vehicle_id)
  elements.routeLabel.textContent = routeName(request)
  elements.employeeLabel.textContent = employeeName(request.employee_id)
  elements.requestLabel.textContent = `#${request.id}`
}

function renderProgress() {
  const handled = state.activeItems.filter(isHandledItem).length
  const total = state.activeItems.length
  const percent = total ? Math.round((handled / total) * 100) : 0
  elements.progressBar.style.width = `${percent}%`
  elements.progressLabel.textContent = `${handled}/${total}`
  const progress = elements.progressBar.parentElement
  progress.setAttribute('aria-valuemax', String(total))
  progress.setAttribute('aria-valuenow', String(handled))
}

function renderCategories(activeCategory) {
  const order = ['ingredients', 'waters', 'snacks']
  const activeIndex = order.indexOf(activeCategory)
  app.querySelectorAll('[data-category-step]').forEach((step) => {
    const index = order.indexOf(step.dataset.categoryStep)
    step.classList.toggle('active', index === activeIndex)
    step.classList.toggle('done', index < activeIndex)
  })
}

function setQuantityFromInput() {
  const item = state.activeItems[state.currentIndex]
  const product = productById(item?.product_id)
  const pack = getPickingPackage(item, product, state.packages)
  const raw = parseQuantity(elements.quantityInput.value, 0)
  state.quantityPieces = state.unitMode === 'package' && pack
    ? Number((raw * Number(pack.units_per_package || 1)).toFixed(3))
    : raw
}

function renderQuantityAndStock() {
  const request = state.activeRequest
  const item = state.activeItems[state.currentIndex]
  const product = productById(item.product_id)
  const pack = getPickingPackage(item, product, state.packages)
  const hasPack = Boolean(pack && Number(pack.units_per_package || 0) > 1)
  if (!hasPack && state.unitMode === 'package') state.unitMode = 'piece'

  elements.packageModeBtn.disabled = !hasPack
  elements.packageModeBtn.classList.toggle('active', state.unitMode === 'package')
  elements.pieceModeBtn.classList.toggle('active', state.unitMode === 'piece')

  const inputValue = state.unitMode === 'package' && pack
    ? quantityFromBase(state.quantityPieces, 'package', product, pack)
    : state.quantityPieces
  elements.quantityInput.value = String(Number(inputValue.toFixed(3)))
  elements.quantityInput.step = state.unitMode === 'package' ? '0.001' : '1'
  elements.quantityUnit.textContent = state.unitMode === 'package' ? (pack?.package_name || 'bal.') : (product?.base_unit || 'ks')
  elements.quantitySecondary.textContent = state.unitMode === 'package'
    ? `${formatQuantity(state.quantityPieces)} ${product?.base_unit || 'ks'}`
    : hasPack
      ? `${formatQuantity(quantityFromBase(state.quantityPieces, 'package', product, pack))} ${pack.package_name}`
      : `${formatQuantity(state.quantityPieces)} ${product?.base_unit || 'ks'}`
  elements.packageNote.textContent = hasPack
    ? `1 ${pack.package_name} = ${formatQuantity(pack.units_per_package)} ${product?.base_unit || 'ks'}`
    : 'Základní jednotka položky'

  const warehouseLocation = locationForRequest(request, 'warehouse')
  const vehicleLocation = locationForRequest(request, 'vehicle')
  const warehouse = stockAt(warehouseLocation, item.product_id)
  const vehicle = stockAt(vehicleLocation, item.product_id)
  const reserved = otherReservations(request, item)
  const free = warehouse - reserved - state.quantityPieces
  elements.warehouseStock.textContent = formatInMode(warehouse, item, product, pack)
  elements.vehicleStock.textContent = formatInMode(vehicle, item, product, pack)
  elements.otherReserved.textContent = formatInMode(reserved, item, product, pack)
  elements.freeAfterRequests.textContent = formatInMode(free, item, product, pack)
  elements.freeAfterRequests.parentElement.style.background = free < 0 ? 'var(--danger-soft)' : 'var(--green-soft)'
  elements.freeAfterRequests.style.color = free < 0 ? 'var(--danger)' : 'var(--green)'
}

function renderCurrentItem() {
  if (!state.activeItems.length) {
    renderSummary()
    return
  }
  const item = state.activeItems[state.currentIndex]
  const product = productById(item.product_id) || {}
  const category = getPickingCategory(product)
  renderRouteHeader()
  renderProgress()
  renderCategories(category.key)

  elements.itemCounter.textContent = `Položka ${state.currentIndex + 1} z ${state.activeItems.length}`
  elements.itemCategory.textContent = category.label
  elements.productName.textContent = item.product_name || product.name || 'Produkt'
  elements.productSku.textContent = [item.sku || product.sku ? `SKU ${item.sku || product.sku}` : '', product.base_unit ? `základ ${product.base_unit}` : ''].filter(Boolean).join(' · ') || 'Bez kódu'
  elements.productPosition.textContent = storagePositionLabel(product)
  elements.productFallback.textContent = productFallback(product, item)
  elements.productFallback.hidden = false
  elements.productPhoto.hidden = true
  elements.productPhoto.alt = `Fotografie ${item.product_name || product.name || 'produktu'}`
  const imageUrl = productImageUrl(product)
  if (imageUrl) {
    elements.productPhoto.src = imageUrl
    window.setTimeout(() => {
      if (elements.productPhoto.complete && elements.productPhoto.naturalWidth > 0) {
        elements.productPhoto.hidden = false
        elements.productFallback.hidden = true
      }
    }, 0)
  } else {
    elements.productPhoto.removeAttribute('src')
  }
  setSkipPanelOpen(false)
  renderQuantityAndStock()
  showView('pickingView')
}

function pickNextUnhandled(startAt = 0) {
  const nextIndex = state.activeItems.findIndex((item, index) => index >= startAt && !isHandledItem(item))
  if (nextIndex >= 0) return nextIndex
  return state.activeItems.findIndex((item) => !isHandledItem(item))
}

function resetCurrentQuantity() {
  const item = state.activeItems[state.currentIndex]
  const product = productById(item?.product_id)
  const pack = getPickingPackage(item, product, state.packages)
  state.quantityPieces = item ? itemBaseQuantity(item) : 0
  state.unitMode = pack && Number(pack.units_per_package || 0) > 1 ? 'package' : 'piece'
}

function advanceAfterItem() {
  const next = pickNextUnhandled(state.currentIndex + 1)
  if (next < 0) {
    renderSummary()
    return
  }
  state.currentIndex = next
  resetCurrentQuantity()
  renderCurrentItem()
}

function renderSummary() {
  const picked = state.activeItems.filter((item) => Boolean(item.warehouse_picked_at)).length
  const skipped = state.activeItems.filter(isSkippedItem).length
  elements.summaryRoute.textContent = `${vehicleName(state.activeRequest.vehicle_id)} · ${employeeName(state.activeRequest.employee_id)}`
  elements.summaryTotal.textContent = pluralizeItems(state.activeItems.length)
  elements.summaryPicked.textContent = pluralizeItems(picked)
  elements.summarySkipped.textContent = pluralizeItems(skipped)
  showView('summaryView')
}

function renderSuccess(request = state.activeRequest) {
  elements.successRoute.textContent = `${vehicleName(request.vehicle_id)} · ${employeeName(request.employee_id)}`
  elements.successPreparer.textContent = employeeName(request.prepared_by || state.me?.id)
  elements.successTime.textContent = request.prepared_at
    ? new Date(request.prepared_at).toLocaleTimeString('cs-CZ', { hour: '2-digit', minute: '2-digit' })
    : new Date().toLocaleTimeString('cs-CZ', { hour: '2-digit', minute: '2-digit' })
  showView('successView')
}

async function openRequest(requestId) {
  const request = state.requests.find((row) => String(row.id) === String(requestId))
  if (!request) throw new Error('Požadavek už není v načteném seznamu.')
  state.activeRequest = request
  renderWarehouseContext()
  state.activeItems = sortPickingItems(requestItems(request.id), new Map(state.products.map((product) => [String(product.id), product])))
  if (request.status === 'ready') {
    renderSuccess(request)
    return
  }
  if (!state.activeItems.length) throw new Error('Požadavek nemá žádné položky.')
  if (request.status === 'requested') {
    await updateOrQueue('mobile_stock_requests', request.id, { status: 'picking', prepared_at: null })
  }
  const next = pickNextUnhandled(0)
  if (next < 0) {
    renderSummary()
    return
  }
  state.currentIndex = next
  resetCurrentQuantity()
  renderCurrentItem()
}

async function saveCurrentItem() {
  setQuantityFromInput()
  if (state.quantityPieces <= 0) throw new Error('Pro nulové množství použij tlačítko Nevychystat.')
  const item = state.activeItems[state.currentIndex]
  const product = productById(item.product_id) || {}
  const pack = getPickingPackage(item, product, state.packages)
  const requestedBase = itemBaseQuantity(item, 'requested_quantity')
  const usePackage = state.unitMode === 'package' && pack
  const unit = usePackage ? pack.package_name : (product.base_unit || 'ks')
  const factor = usePackage ? Number(pack.units_per_package || 1) : 1
  const now = new Date().toISOString()
  const cleanNote = String(item.note || '').replace(/\s*\[Nevychystáno:[^\]]+\]/gi, '').trim() || null
  const payload = {
    unit,
    requested_quantity: Number((requestedBase / factor).toFixed(3)),
    prepared_quantity: Number((state.quantityPieces / factor).toFixed(3)),
    note: cleanNote,
    warehouse_picked_at: now,
    warehouse_picked_by: state.me?.id || null
  }
  const data = await updateOrQueue('mobile_stock_request_items', item.id, payload)
  showToast(`${item.product_name || product.name}: připraveno${data.__queued ? ' offline' : ''}.`)
  advanceAfterItem()
}

async function skipCurrentItem(reason) {
  const item = state.activeItems[state.currentIndex]
  const cleanNote = String(item.note || '').replace(/\s*\[Nevychystáno:[^\]]+\]/gi, '').trim()
  const payload = {
    prepared_quantity: 0,
    note: [cleanNote, `[Nevychystáno: ${reason}]`].filter(Boolean).join(' '),
    warehouse_picked_at: null,
    warehouse_picked_by: null
  }
  const data = await updateOrQueue('mobile_stock_request_items', item.id, payload)
  showToast(`${item.product_name || 'Položka'}: nevychystáno · ${reason}${data.__queued ? ' · uloženo offline' : ''}`)
  advanceAfterItem()
}

async function finishRequest() {
  let checkedItems = state.activeItems
  if (navigator.onLine && !pendingCount()) {
    const { data: freshItems, error: itemsError } = await supabase
      .from('mobile_stock_request_items')
      .select('*')
      .eq('request_id', state.activeRequest.id)
      .order('id', { ascending: true })
    if (itemsError) throw itemsError
    checkedItems = freshItems || []
  }
  const unhandled = checkedItems.filter((item) => !isHandledItem(item))
  if (unhandled.length) throw new Error(`Ještě zbývá zkontrolovat ${pluralizeItems(unhandled.length)}.`)
  const now = new Date().toISOString()
  const payload = { status: 'ready', prepared_at: now, prepared_by: state.me?.id || null }
  await updateOrQueue('mobile_stock_requests', state.activeRequest.id, payload)
  renderSuccess(state.activeRequest)
}

async function getCurrentEmployee() {
  if (!navigator.onLine) {
    const snapshot = readJson(SNAPSHOT_KEY, null)
    if (snapshot?.me) return snapshot.me
    throw new Error('Pro první otevření skladu je potřeba internet. Potom bude fungovat i offline.')
  }
  const authUserId = state.authUserId
  if (!authUserId) throw new Error('Přihlášení vypršelo. Přihlas se znovu do OLVEND.')
  const { data, error } = await supabase.from('employees').select('id, name, surname, email, role').eq('auth_user_id', authUserId).maybeSingle()
  if (error) throw error
  if (!data) throw new Error('K přihlášení není přiřazený zaměstnanec.')
  return data
}

async function loadData() {
  showView('loadingView')
  setBootStage('Spouštím skladovou aplikaci…')
  const hardTimeout = window.setTimeout(() => {
    if (elements.loadingView.hidden) return
    elements.errorMessage.textContent = 'Načítání se zastavilo. Zkontroluj připojení a zvol „Přihlásit se znovu“.'
    showView('errorView')
  }, 15000)
  try {
    if (!navigator.onLine) {
      setBootStage('Načítám poslední uložená data…')
      if (!loadSnapshot()) throw new Error('Offline data zatím nejsou uložená. Připoj Zebru k internetu a otevři sklad znovu.')
      renderRequests()
      return
    }
    setBootStage('Ověřuji uložené přihlášení…')
    const session = await ensureWarehouseSession()
    state.authUserId = session && session.user && session.user.id
    setBootStage('Kontroluji neodeslané změny…')
    await syncQueue()
    setBootStage('Načítám pracovníka skladu…')
    state.me = await getCurrentEmployee()
    setBootStage('Načítám sklad…')
    const { data: warehouses, error: warehousesError } = await supabase
      .from('warehouses')
      .select('id, name, code, city, active')
      .eq('active', true)
      .order('id', { ascending: true })
    if (warehousesError) throw warehousesError
    state.warehouses = warehouses || []
    setBootStage('Načítám požadavky na vychystání…')
    const { data: requests, error: requestsError } = await supabase
      .from('mobile_stock_requests')
      .select('*')
      .in('request_type', ['vehicle_order', 'vehicle_load'])
      .in('status', ['requested', 'picking', 'ready'])
      .order('created_at', { ascending: false })
      .limit(100)
    if (requestsError) throw requestsError
    state.requests = requests || []
    if (!state.requests.length) {
      state.items = []
      saveSnapshot()
      renderRequests()
      return
    }

    const requestIds = state.requests.map((request) => request.id)
    const employeeIds = [...new Set(state.requests.flatMap((request) => [request.employee_id, request.prepared_by]).filter(Boolean))]
    const vehicleIds = [...new Set(state.requests.map((request) => request.vehicle_id).filter(Boolean))]
    const routeIds = [...new Set(state.requests.map((request) => request.route_plan_id).filter(Boolean))]
    setBootStage('Načítám položky, vozidla a trasy…')
    const [itemsResult, employeesResult, vehiclesResult, routesResult, locationsResult] = await Promise.all([
      supabase.from('mobile_stock_request_items').select('*').in('request_id', requestIds).order('id', { ascending: true }),
      employeeIds.length ? supabase.from('employee_directory').select('id, name, surname, email').in('id', employeeIds) : Promise.resolve({ data: [], error: null }),
      vehicleIds.length ? supabase.from('vehicles').select('id, name, plate, brand, model, warehouse_id').in('id', vehicleIds) : Promise.resolve({ data: [], error: null }),
      routeIds.length ? supabase.from('route_plans').select('id, title, planning_date').in('id', routeIds) : Promise.resolve({ data: [], error: null }),
      supabase.from('stock_locations').select('id, name, location_type, warehouse_id, vehicle_id, active').eq('active', true)
    ])
    const firstError = [itemsResult, employeesResult, vehiclesResult, routesResult, locationsResult].find((result) => result.error)?.error
    if (firstError) throw firstError
    state.items = itemsResult.data || []
    state.employees = [...(employeesResult.data || [])]
    if (!state.employees.some((employee) => String(employee.id) === String(state.me.id))) state.employees.push(state.me)
    state.vehicles = vehiclesResult.data || []
    state.routes = routesResult.data || []
    state.locations = locationsResult.data || []

    const productIds = [...new Set(state.items.map((item) => item.product_id).filter(Boolean))]
    const relevantLocationIds = [...new Set(state.requests.flatMap((request) => [
      request.source_stock_location_id,
      request.target_stock_location_id,
      locationForRequest(request, 'warehouse')?.id,
      locationForRequest(request, 'vehicle')?.id
    ]).filter(Boolean))]
    setBootStage('Načítám produkty a skladové zásoby…')
    const [productsResult, packagesResult, balancesResult] = await Promise.all([
      productIds.length ? supabase.from('products').select('id, name, sku, product_category, usage_type, base_unit, active, note, image_path, image_updated_at').in('id', productIds) : Promise.resolve({ data: [], error: null }),
      productIds.length ? supabase.from('product_packages').select('id, product_id, package_name, units_per_package, is_default, active').in('product_id', productIds).eq('active', true) : Promise.resolve({ data: [], error: null }),
      relevantLocationIds.length && productIds.length ? supabase.from('stock_location_balances').select('id, stock_location_id, product_id, batch_id, quantity_on_hand, reserved_quantity').in('stock_location_id', relevantLocationIds).in('product_id', productIds) : Promise.resolve({ data: [], error: null })
    ])
    const detailError = [productsResult, packagesResult, balancesResult].find((result) => result.error)?.error
    if (detailError) throw detailError
    state.products = await hydrateProductImages(productsResult.data || [])
    state.packages = packagesResult.data || []
    state.balances = balancesResult.data || []
    state.activeRequest = null
    state.activeItems = []
    applyQueuedUpdates()
    saveSnapshot()
    renderRequests()
  } catch (error) {
    console.error(error)
    elements.errorMessage.textContent = error?.message || 'Zkus stránku obnovit.'
    showView('errorView')
  } finally {
    window.clearTimeout(hardTimeout)
  }
}

async function runAction(action) {
  if (state.busy) return
  setBusy(true)
  try {
    await action()
  } catch (error) {
    console.error(error)
    showToast(error?.message || 'Akci se nepodařilo uložit.', 'error')
  } finally {
    setBusy(false)
  }
}

async function logout() {
  if (pendingCount()) {
    showToast('Nejdřív připoj Zebru k internetu a nech odeslat čekající změny.', 'error')
    return
  }
  if (elements.logoutBtn) {
    elements.logoutBtn.disabled = true
    elements.logoutBtn.setAttribute('aria-label', 'Odpojuji přihlášeného pracovníka…')
  }
  if (elements.currentUserInitials) elements.currentUserInitials.textContent = '…'
  try { await supabase.auth.signOut({ scope: 'local' }) } catch (_) {}
  localStorage.removeItem('sb-rerjlkrhiytgscjerqgs-auth-token')
  localStorage.removeItem('olvendUser')
  localStorage.removeItem(SNAPSHOT_KEY)
  localStorage.removeItem(QUEUE_KEY)
  sessionStorage.removeItem('olvendUser')
  window.location.replace('zebra-prihlaseni.html')
}

elements.requestList.addEventListener('click', (event) => {
  const button = event.target.closest('[data-request-id]')
  if (button) runAction(() => openRequest(button.dataset.requestId))
})
elements.refreshBtn.addEventListener('click', loadData)
elements.emptyRefreshBtn.addEventListener('click', loadData)
elements.errorRetryBtn.addEventListener('click', loadData)
if (elements.logoutBtn) elements.logoutBtn.addEventListener('click', logout)
elements.backToRequestsBtn.addEventListener('click', renderRequests)
elements.successBackBtn.addEventListener('click', loadData)
elements.readyItemBtn.addEventListener('click', () => runAction(saveCurrentItem))
elements.skipItemBtn.addEventListener('click', () => { setSkipPanelOpen(elements.skipPanel.hidden) })
elements.skipPanel.addEventListener('click', (event) => {
  const button = event.target.closest('[data-skip-reason]')
  if (button) {
    setSkipPanelOpen(false)
    runAction(() => skipCurrentItem(button.dataset.skipReason))
  }
})
elements.finishRequestBtn.addEventListener('click', () => runAction(finishRequest))
elements.reviewItemsBtn.addEventListener('click', () => {
  state.currentIndex = Math.max(0, state.activeItems.length - 1)
  resetCurrentQuantity()
  renderCurrentItem()
})
elements.minusBtn.addEventListener('click', () => {
  const item = state.activeItems[state.currentIndex]
  const product = productById(item?.product_id)
  const pack = getPickingPackage(item, product, state.packages)
  const step = state.unitMode === 'package' && pack ? Number(pack.units_per_package || 1) : 1
  state.quantityPieces = Math.max(0, Number((state.quantityPieces - step).toFixed(3)))
  renderQuantityAndStock()
})
elements.plusBtn.addEventListener('click', () => {
  const item = state.activeItems[state.currentIndex]
  const product = productById(item?.product_id)
  const pack = getPickingPackage(item, product, state.packages)
  const step = state.unitMode === 'package' && pack ? Number(pack.units_per_package || 1) : 1
  state.quantityPieces = Number((state.quantityPieces + step).toFixed(3))
  renderQuantityAndStock()
})
elements.packageModeBtn.addEventListener('click', () => { state.unitMode = 'package'; renderQuantityAndStock() })
elements.pieceModeBtn.addEventListener('click', () => { state.unitMode = 'piece'; renderQuantityAndStock() })
elements.quantityInput.addEventListener('input', () => { setQuantityFromInput(); renderQuantityAndStock() })
elements.productPhoto.addEventListener('load', () => { elements.productPhoto.hidden = false; elements.productFallback.hidden = true })
elements.productPhoto.addEventListener('error', () => { elements.productPhoto.hidden = true; elements.productFallback.hidden = false })

window.addEventListener('online', async () => {
  updateConnection()
  const result = await syncQueue()
  showToast(result.synced ? `Synchronizováno ${result.synced} změn.` : 'Připojení je znovu dostupné.')
  if (!result.pending) await loadData()
})
window.addEventListener('offline', updateConnection)
window.addEventListener('olvend-offline-queue', updateConnection)
window.addEventListener('beforeinstallprompt', (event) => {
  event.preventDefault()
  state.deferredInstallPrompt = event
  elements.installAppBtn.hidden = false
})
elements.installAppBtn.addEventListener('click', async () => {
  if (!state.deferredInstallPrompt) return
  state.deferredInstallPrompt.prompt()
  await state.deferredInstallPrompt.userChoice
  state.deferredInstallPrompt = null
  elements.installAppBtn.hidden = true
})
window.addEventListener('appinstalled', () => {
  state.deferredInstallPrompt = null
  elements.installAppBtn.hidden = true
  showToast('OLVEND Sklad je nainstalovaný na ploše.')
})

updateConnection()
loadData()
