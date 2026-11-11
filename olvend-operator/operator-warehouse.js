(function () {
  'use strict'

  var root = document.getElementById('ow-app')
  if (!root) return
  var API = 'https://rerjlkrhiytgscjerqgs.supabase.co'
  var KEY = 'sb_publishable_A8OxCcapdNXAzQLjLsW5iA_XtGvBZ0S'
  var preview = location.hostname === '127.0.0.1' && new URLSearchParams(location.search).get('preview') === 'warehouse'
  var session, employee, attendance, route, vehicle, warehouseLocation, vehicleLocation, readyRequest
  var productMap = new Map(), historyRows = [], vehicleStats = { food:0, beverage:0, ingredient:0 }, completed = new Set(), activeFlow = '', started = false
  var products = { load: [], bagettes: [], return: [], waste: [] }, extraBagettes = []
  var overview = document.getElementById('ow-overview'), detail = document.getElementById('ow-detail')
  var list = document.getElementById('ow-product-list'), save = document.getElementById('ow-save')
  var busy = document.getElementById('ow-busy'), toast = document.getElementById('ow-toast')
  var config = {
    load: ['Včera · skladník → auto', 'Převzít vychystané zboží', 'Jedno potvrzení pro celé převzetí', 'Uprav pouze výjimky. Co už ve vozidle máš, označ „Nechci, mám dost“. Bagety zde záměrně nejsou.', 'Potvrdit vše a převzít'],
    bagettes: ['Dnes ráno · chlazený sklad → auto', 'Vzít čerstvé bagety', 'Jedno potvrzení pro celý ranní odběr', 'Uprav množství, odmítni nepotřebné položky nebo přidej jiný dostupný druh. Nakonec vše potvrdíš jedním tlačítkem.', 'Potvrdit vše a vzít'],
    return: ['Auto → sklad / další trasa', 'Vrátit prodejné zboží', 'Prodejné zboží se neodepisuje', 'Zboží může zůstat ve vozidle pro další přiřazenou trasu, nebo ho fyzicky vrať do skladu.', 'Potvrdit rozhodnutí'],
    waste: ['Auto → expirace', 'Odevzdat expirace a odpisy', 'Načteno přímo z dokončené trasy', 'Zkontroluj fyzické množství. Jedním potvrzením uzavřeš odevzdání všech odpisů.', 'Potvrdit odevzdání']
  }

  function esc(v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' })[c] }) }
  function norm(v) { return String(v || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().trim() }
  function today() { try { return new Intl.DateTimeFormat('sv-SE', { timeZone:'Europe/Prague' }).format(new Date()) } catch (_) { return new Date().toISOString().slice(0,10) } }
  function date(v) { return v ? new Date(String(v).slice(0,10) + 'T12:00:00').toLocaleDateString('cs-CZ') : '' }
  function longDate() { return new Intl.DateTimeFormat('cs-CZ', { timeZone:'Europe/Prague', weekday:'long', day:'numeric', month:'long' }).format(new Date()) }
  function hdr(extra) { return Object.assign({ apikey:KEY, Authorization:'Bearer ' + session.access_token, 'Content-Type':'application/json' }, extra || {}) }
  function api(path, options) {
    var opts = Object.assign({}, options || {}); opts.headers = hdr(opts.headers)
    return fetch(API + path, opts).then(function (r) {
      if (!r.ok) return r.text().then(function (t) { var p; try { p = JSON.parse(t) } catch (_) {} throw new Error(p && (p.message || p.details) || 'Operace se nepodařila (HTTP ' + r.status + ').') })
      if (r.status === 204) return null
      return r.text().then(function (t) { return t ? JSON.parse(t) : null })
    })
  }
  function rpc(name, body) { return api('/rest/v1/rpc/' + name, { method:'POST', body:JSON.stringify(body) }) }
  function setBusy(on, label) { document.getElementById('ow-busy-label').textContent = label || 'Načítám…'; busy.hidden = !on }
  function message(text, error) { toast.textContent = text; toast.style.background = error ? '#b42318' : '#18202a'; toast.hidden = false; clearTimeout(message.timer); message.timer = setTimeout(function () { toast.hidden = true }, 3600) }
  function total(flow) { return products[flow].reduce(function (s, x) { return s + Number(x.quantity || 0) }, 0) }
  function expiry(row) { return row && row.inventory_batches && (row.inventory_batches.use_by_date || row.inventory_batches.best_before_date) || '' }
  function batchSort(a,b) { return String(expiry(a) || '9999-12-31').localeCompare(String(expiry(b) || '9999-12-31')) }

  function image(product) {
    if (!product) return './icon-192.png'
    if (product.image_url) return product.image_url
    var path = String(product.image_path || '')
    if (path.indexOf('static:') === 0) return path.slice(7)
    var name = norm(product.name)
    if (name.indexOf('svacink') >= 0) return './assets/product-images/bagette-svacinka.jpg'
    if (name.indexOf('hamka') >= 0) return './assets/product-images/bagette-hamka.jpg'
    if (name.indexOf('porizek') >= 0) return './assets/product-images/bagette-porizek.jpg'
    var byEan = { '9002490200091':'ean-9002490200091.webp','7622201390648':'ean-7622201390648.jpg','5949040204427':'ean-5949040204427.jpg','8000500073698':'ean-8000500073698.jpg' }
    return byEan[String(product.ean || '')] ? './assets/product-images/' + byEan[String(product.ean)] : './icon-192.png'
  }
  function hydrateImage(p) {
    var path = String(p.image_path || '')
    if (!path || path.indexOf('static:') === 0) return Promise.resolve(p)
    return api('/storage/v1/object/sign/product-images/' + path.split('/').map(encodeURIComponent).join('/'), { method:'POST', body:JSON.stringify({ expiresIn:43200 }) }).then(function (d) {
      if (d && d.signedURL) p.image_url = API + '/storage/v1' + d.signedURL
      else if (d && d.signedUrl) p.image_url = d.signedUrl
      return p
    }).catch(function () { return p })
  }
  function loadProducts(ids) {
    var unique = Array.from(new Set(ids.map(String).filter(Boolean))).filter(function (id) { return !productMap.has(id) })
    if (!unique.length) return Promise.resolve()
    var fields = 'id,name,sku,ean,base_unit,product_category,requires_batch_tracking,expiry_tracking_mode,image_path,active'
    return api('/rest/v1/products?select=' + encodeURIComponent(fields) + '&id=in.(' + unique.join(',') + ')').then(function (rows) { return Promise.all((rows || []).map(hydrateImage)) }).then(function (rows) { rows.forEach(function (p) { productMap.set(String(p.id), p) }) })
  }

  function thumbs(items, label) { return items.slice(0,3).map(function (x) { return '<img src="' + esc(x.image) + '" alt="">' }).join('') + '<strong>' + esc(label) + '</strong>' }
  function updateOverview() {
    var hasReady = Boolean(readyRequest), ready = document.getElementById('ow-ready')
    ready.disabled = !hasReady && !completed.has('load'); ready.classList.toggle('done', completed.has('load'))
    document.getElementById('ow-ready-state').textContent = completed.has('load') ? 'Převzato do vozidla' : hasReady ? 'Včera vychystal skladník · připraveno' : 'Skladník zatím nic nepřipravil'
    document.getElementById('ow-ready-title').textContent = completed.has('load') ? 'Převzetí je potvrzené' : hasReady ? products.load.length + ' položek · ' + total('load') + ' ks' : 'Žádný doklad k převzetí'
    document.getElementById('ow-ready-copy').textContent = hasReady ? 'Trvanlivé zboží pro dnešní trasu. Čerstvé bagety v tomto převzetí nejsou.' : 'Jakmile skladník dokončí vychystání, objeví se zde celý doklad.'
    ready.querySelector('.ow-ready-products').innerHTML = thumbs(products.load, hasReady ? 'Doklad #' + readyRequest.id : 'Čeká na sklad')
    ready.querySelector('.ow-ready-open').textContent = hasReady ? 'Převzít vychystané' : 'Zatím nepřipraveno'
    var morning = document.getElementById('ow-morning'); morning.classList.toggle('done', completed.has('bagettes'))
    document.getElementById('ow-morning-state').textContent = completed.has('bagettes') ? 'Ranní odběr potvrzen' : 'Ranní odběr · operátorka'
    document.getElementById('ow-morning-title').textContent = completed.has('bagettes') ? 'Bagety jsou ve vozidle' : 'Vzít čerstvé bagety'
    document.getElementById('ow-morning-copy').textContent = 'Návrh vychází z dnešní trasy. Počet i druhy můžeš před potvrzením změnit.'
    morning.querySelector('.ow-ready-products').innerHTML = thumbs(products.bagettes, products.bagettes.length ? 'Doporučeno ' + products.bagettes.length + ' druhy · ' + total('bagettes') + ' kusů' : 'Vyber ručně z dostupných baget')
    var rc = document.querySelector('[data-open-flow="return"] .ow-task-copy > span'), wc = document.querySelector('[data-open-flow="waste"] .ow-task-copy > span')
    rc.textContent = products.return.length ? total('return') + ' ks s krátkou expirací k rozhodnutí' : 'Žádné prodejné zboží k rozhodnutí'
    wc.textContent = products.waste.length ? total('waste') + ' ks načteno z dokončených návštěv' : 'Žádné odpisy nečekají na odevzdání'
    document.querySelector('[data-open-flow="return"]').disabled = !products.return.length
    document.querySelector('[data-open-flow="waste"]').disabled = !products.waste.length
    document.getElementById('ow-task-summary').textContent = (Number(completed.has('return')) + Number(completed.has('waste'))) + ' ze 2 hotovo'
    document.getElementById('ow-bagette-stock').textContent = Math.round(vehicleStats.food) + ' ks'
    document.querySelector('#ow-history span').textContent = 'Dnes ' + historyRows.length + ' pohybů ›'
    document.querySelectorAll('[data-open-flow]').forEach(function (button) { var state = button.querySelector('[data-task-state]'); if (state) state.textContent = completed.has(button.dataset.openFlow) ? 'Hotovo' : button.dataset.openFlow === 'waste' && products.waste.length ? 'Povinné' : products[button.dataset.openFlow].length ? 'Po trase' : 'Bez položek' })
  }

  function productCard(item, flow) {
    var destination = flow === 'return' ? '<div class="ow-destination"><span>Kam se zbožím</span><select data-destination><option value="route"' + (item.destination === 'route' ? ' selected' : '') + '>Nechat ve vozidle pro další trasu (doporučeno)</option><option value="warehouse"' + (item.destination === 'warehouse' ? ' selected' : '') + '>Vrátit fyzicky do skladu</option></select></div>' : ''
    var fast = flow === 'load' || flow === 'bagettes'
    var action = fast ? '<button class="ow-decline ' + (item.skipped ? 'active' : '') + '" type="button" data-skip-item>' + (item.skipped ? 'Vrátit do odběru' : 'Nechci, mám dost') + '</button>' : '<button class="ow-check" type="button" data-confirm-item>Potvrdit</button>'
    return '<article class="ow-product ' + (item.skipped ? 'skipped' : '') + '" data-product-id="' + esc(item.id) + '"><img src="' + esc(item.image) + '" alt="' + esc(item.name) + '"><div class="ow-product-copy"><div class="ow-product-top"><h3>' + esc(item.name) + '</h3><span class="ow-product-tag ' + (item.green ? 'green' : '') + '">' + esc(item.tag || 'Skladem') + '</span></div><div class="ow-meta">' + esc(item.meta || '') + (item.expiry ? '<br>Expirace ' + esc(item.expiry) : '') + '</div><div class="ow-product-controls"><span class="ow-stepper"><button type="button" data-delta="-1">−</button><output>' + esc(item.quantity) + ' ' + esc(item.unit || 'ks') + '</output><button type="button" data-delta="1">+</button></span>' + action + '</div></div>' + destination + '</article>'
  }
  function catalog() {
    var available = extraBagettes.filter(function (x) { return !products.bagettes.some(function (y) { return String(x.productId) === String(y.productId) }) })
    return '<div class="ow-catalog" id="ow-catalog" hidden><strong>' + (available.length ? 'Další dostupné bagety' : 'Všechny dostupné druhy už jsou přidané') + '</strong>' + (available.length ? '<p>Zvol si vlastní počet kusů. Údaj „skladem“ je pouze dostupné maximum.</p>' : '') + available.map(function (x) { return '<div class="ow-catalog-item" data-extra-id="' + x.id + '"><img src="' + esc(x.image) + '" alt=""><span class="ow-catalog-copy"><strong>' + esc(x.name) + '</strong><span>' + esc(x.tag) + ' · skladem ' + x.stock + ' ks</span></span><span class="ow-catalog-actions"><button data-catalog-delta="-1">−</button><output>' + (x.pickQuantity || 1) + ' ks</output><button data-catalog-delta="1">+</button><button class="ow-catalog-add" data-add-bagette="' + x.id + '">Přidat</button></span></div>' }).join('') + '</div>'
  }
  function renderList() { list.innerHTML = products[activeFlow].map(function (x) { return productCard(x, activeFlow) }).join(''); if (activeFlow === 'bagettes') list.insertAdjacentHTML('beforeend', '<button class="ow-add-product" id="ow-add-bagette" type="button">＋ Přidat jinou bagetu</button>' + catalog()) }
  function refreshAction() { save.textContent = config[activeFlow][4] + ' · ' + total(activeFlow) + ' ks' }
  function openFlow(flow) { if (!products[flow].length) { message(flow === 'load' ? 'Skladník zatím nedokončil žádný doklad k převzetí.' : 'Pro tuto část nejsou žádné položky.'); return } activeFlow = flow; overview.hidden = true; detail.hidden = false; document.getElementById('ow-detail-kicker').textContent = config[flow][0]; document.getElementById('ow-detail-title').textContent = config[flow][1]; document.getElementById('ow-callout-title').textContent = config[flow][2]; document.getElementById('ow-callout-copy').textContent = config[flow][3]; renderList(); refreshAction(); save.disabled = false; scrollTo({ top:0, behavior:'instant' }) }
  function closeFlow() { activeFlow = ''; detail.hidden = true; overview.hidden = false; updateOverview(); scrollTo({ top:0, behavior:'instant' }) }

  function ensureLocation(type, id, name) {
    var col = type === 'warehouse' ? 'warehouse_id' : 'vehicle_id'
    return api('/rest/v1/stock_locations?select=id&location_type=eq.' + type + '&' + col + '=eq.' + id + '&active=eq.true&limit=1').then(function (rows) { if (rows[0]) return rows[0].id; var body = { location_type:type, name:name, active:true }; body[col] = id; return api('/rest/v1/stock_locations?select=id', { method:'POST', headers:{ Prefer:'return=representation' }, body:JSON.stringify(body) }).then(function (created) { return created[0].id }) })
  }
  function loadContext() {
    var d = today(), routeFields = 'id,planning_date,vehicle_id,warehouse_id,execution_status,route_plan_stops(id,stop_order,machine_id,status)'
    return Promise.all([
      api('/rest/v1/attendance_days?select=*&employee_id=eq.' + employee.id + '&attendance_date=eq.' + d + '&order=created_at.desc&limit=1'),
      api('/rest/v1/route_plans?select=' + encodeURIComponent(routeFields) + '&planned_employee_id=eq.' + employee.id + '&planning_date=eq.' + d + '&execution_status=neq.cancelled&order=created_at.desc&limit=1')
    ]).then(function (r) { attendance = r[0][0] || null; route = r[1][0] || null; var vehicleId = attendance && attendance.vehicle_id || route && route.vehicle_id; return api('/rest/v1/vehicles?select=id,name,plate,warehouse_id,assigned_employee_id,active&active=eq.true&order=id').then(function (rows) { vehicle = rows.find(function (x) { return String(x.id) === String(vehicleId || '') }) || rows.find(function (x) { return String(x.assigned_employee_id) === String(employee.id) }); if (!vehicle) throw new Error('Pro dnešní směnu není přiřazené vozidlo.'); return Promise.all([ensureLocation('vehicle', vehicle.id, [vehicle.name,vehicle.plate].filter(Boolean).join(' · ')), ensureLocation('warehouse', vehicle.warehouse_id || route && route.warehouse_id, 'Sklad')]) }) }).then(function (loc) { vehicleLocation = loc[0]; warehouseLocation = loc[1] })
  }
  function loadReady() {
    return api('/rest/v1/mobile_stock_requests?select=*&vehicle_id=eq.' + vehicle.id + '&status=eq.ready&request_type=in.(vehicle_order,vehicle_load)&requested_for_date=eq.' + today() + '&order=prepared_at.desc,created_at.desc&limit=1').then(function (rows) { readyRequest = rows[0] || null; if (!readyRequest) { products.load = []; return } return api('/rest/v1/mobile_stock_request_items?select=*&request_id=eq.' + readyRequest.id + '&order=id').then(function (items) { return loadProducts(items.map(function (x) { return x.prepared_product_id || x.product_id })).then(function () { products.load = items.map(function (x) { var pid = x.prepared_product_id || x.product_id, p = productMap.get(String(pid)) || {}, qty = Number(x.confirmed_quantity != null ? x.confirmed_quantity : x.prepared_quantity != null ? x.prepared_quantity : x.requested_quantity || 0); return { id:'ready-' + x.id, requestItemId:x.id, productId:pid, batchId:x.batch_id, name:x.prepared_product_name || p.name || x.product_name, image:image(p), quantity:qty, max:qty, unit:x.prepared_unit || x.unit || p.base_unit || 'ks', meta:x.note || 'Včera připravil skladník', tag:x.prepared_product_id ? 'Schválená náhrada' : 'Vychystáno', green:true } }) }) }) })
  }
  function freshRecommendation(fresh) {
    var result = new Map(), ids = Array.from(new Set(((route && route.route_plan_stops) || []).map(function (x) { return x.machine_id }).filter(Boolean)))
    if (!ids.length) return Promise.resolve(result)
    return api('/rest/v1/machine_planogram_slots?select=machine_id,product_sku,product_name,current_units,capacity_units,target_units,active&machine_id=in.(' + ids.join(',') + ')&active=eq.true').then(function (slots) { slots.forEach(function (s) { var p = fresh.find(function (x) { return s.product_sku && norm(x.sku) === norm(s.product_sku) }) || fresh.find(function (x) { return norm(x.name) === norm(s.product_name) }); if (!p) return; var q = Math.max(0, Math.ceil(Number(s.target_units != null ? s.target_units : s.capacity_units || 0) - Number(s.current_units || 0))); if (q) result.set(String(p.id), Number(result.get(String(p.id)) || 0) + q) }); return result }).catch(function () { return result })
  }
  function loadFresh() {
    var fields = 'id,name,sku,ean,base_unit,product_category,image_path,active'
    return api('/rest/v1/products?select=' + encodeURIComponent(fields) + '&active=eq.true&product_category=eq.food_ready&order=name').then(function (rows) { return Promise.all(rows.map(hydrateImage)) }).then(function (fresh) { fresh.forEach(function (p) { productMap.set(String(p.id), p) }); return Promise.all([api('/rest/v1/stock_location_balances?select=id,product_id,batch_id,quantity_on_hand,inventory_batches(lot_code,best_before_date,use_by_date)&stock_location_id=eq.' + warehouseLocation + '&quantity_on_hand=gt.0&product_id=in.(' + fresh.map(function (p) { return p.id }).join(',') + ')'), freshRecommendation(fresh)]).then(function (r) { var by = new Map(); r[0].forEach(function (b) { var rows = by.get(String(b.product_id)) || []; rows.push(b); by.set(String(b.product_id), rows) }); products.bagettes = []; extraBagettes = []; fresh.forEach(function (p) { var records = (by.get(String(p.id)) || []).sort(batchSort), stock = records.reduce(function (s,b) { return s + Number(b.quantity_on_hand || 0) },0); if (!stock) return; var wanted = Math.min(stock, Number(r[1].get(String(p.id)) || 0)), exp = expiry(records[0]); var base = { productId:p.id, name:p.name, image:image(p), max:stock, stock:stock, unit:p.base_unit || 'ks', expiry:date(exp), meta:'Ranní odběr · FEFO ze skladu', tag:exp ? 'Nejbližší expirace ' + date(exp) : 'Skladem', green:true }; if (wanted) products.bagettes.push(Object.assign({ id:'fresh-' + p.id, quantity:wanted }, base)); else extraBagettes.push(Object.assign({ id:'extra-' + p.id, pickQuantity:1 }, base)) }) }) })
  }
  function vehicleBalances() { return api('/rest/v1/stock_location_balances?select=id,product_id,batch_id,quantity_on_hand,inventory_batches(lot_code,best_before_date,use_by_date)&stock_location_id=eq.' + vehicleLocation + '&quantity_on_hand=gt.0').then(function (rows) { return loadProducts(rows.map(function (x) { return x.product_id })).then(function () { vehicleStats={food:0,beverage:0,ingredient:0}; rows.forEach(function (b) { var p=productMap.get(String(b.product_id)) || {}, q=Number(b.quantity_on_hand || 0); if (p.product_category==='food_ready') vehicleStats.food+=q; if (p.product_category==='beverage_ready') vehicleStats.beverage+=q; if (p.product_category==='ingredient'||p.product_category==='consumable') vehicleStats.ingredient+=q }); var horizon = new Date(today() + 'T12:00:00'); horizon.setDate(horizon.getDate()+2); products.return = rows.map(function (b) { var p = productMap.get(String(b.product_id)) || {}, exp = expiry(b), expDate = exp && new Date(exp + 'T12:00:00'); if (p.product_category !== 'food_ready' || !expDate || expDate < new Date(today() + 'T12:00:00') || expDate > horizon) return null; return { id:'return-' + b.id, productId:b.product_id, batchId:b.batch_id, name:p.name, image:image(p), quantity:Number(b.quantity_on_hand), available:Number(b.quantity_on_hand), max:Number(b.quantity_on_hand), unit:p.base_unit || 'ks', expiry:date(exp), meta:'Ve vozidle · krátká expirace', tag:'Prodejné do ' + date(exp), destination:'route' } }).filter(Boolean) }) }) }
  function loadWaste() { return api('/rest/v1/route_vehicle_waste_items?select=*&vehicle_id=eq.' + vehicle.id + '&status=eq.pending&order=collected_at').then(function (rows) { return loadProducts(rows.map(function (x) { return x.product_id })).then(function () { var labels = { expired:'Po expiraci',shaken:'Vytřepané',damaged:'Poškozené',opened:'Otevřené',other:'Odpis' }; products.waste = rows.map(function (x) { var p = productMap.get(String(x.product_id)) || {}; return { id:'waste-' + x.id, wasteId:x.id, productId:x.product_id, name:x.product_name || p.name, image:image(p), quantity:Number(x.quantity), max:Number(x.quantity), unit:x.unit || p.base_unit || 'ks', expiry:date(x.expiry_date), meta:[x.machine_name,x.location_name].filter(Boolean).join(' · '), tag:labels[x.reason] || 'Odpis' } }) }) }) }
  function loadHistory() { return api('/rest/v1/stock_movements_v13?select=id&or=(from_stock_location_id.eq.' + vehicleLocation + ',to_stock_location_id.eq.' + vehicleLocation + ')&created_at=gte.' + encodeURIComponent(today() + 'T00:00:00') + '&limit=100').then(function (rows) { historyRows = rows }).catch(function () { historyRows = [] }) }
  function renderContext() { document.querySelector('.ow-brand > div span').textContent = 'Sklad · vozidlo ' + (vehicle.plate || vehicle.name); document.querySelector('.ow-head small').textContent = longDate(); document.querySelector('.ow-vehicle strong').textContent = vehicle.plate || vehicle.name; document.querySelector('.ow-user').textContent = ((employee.name || 'O').charAt(0) + (employee.surname || 'P').charAt(0)).toUpperCase(); var stats=document.querySelectorAll('.ow-stat strong'); if(stats[1]) stats[1].textContent=Math.round(vehicleStats.beverage)+' ks'; if(stats[2]) stats[2].textContent=Math.round(vehicleStats.ingredient)+' bal.'; updateOverview() }
  function loadAll() { setBusy(true, 'Načítám skutečný sklad a dnešní trasu…'); return loadContext().then(function () { return Promise.all([loadReady(),loadFresh(),vehicleBalances(),loadWaste(),loadHistory()]) }).then(renderContext).catch(function (e) { message(e.message || 'Sklad se nepodařilo načíst.', true); throw e }).finally(function () { setBusy(false) }) }

  function sourceRecords(location, ids) { return api('/rest/v1/stock_location_balances?select=product_id,batch_id,quantity_on_hand,inventory_batches(best_before_date,use_by_date)&stock_location_id=eq.' + location + '&quantity_on_hand=gt.0&product_id=in.(' + ids.join(',') + ')') }
  function movements(items, from, to, type, reference, allowFreshNegative) { var ids = Array.from(new Set(items.map(function (x) { return x.productId }))); return sourceRecords(from, ids).then(function (rows) { var by = new Map(); rows.forEach(function (r) { var list = by.get(String(r.product_id)) || []; list.push(r); by.set(String(r.product_id),list) }); var out = []; items.forEach(function (item) { var remaining = Number(item.quantity || 0), records = (by.get(String(item.productId)) || []).sort(batchSort); if (item.batchId) records.sort(function (a) { return String(a.batch_id) === String(item.batchId) ? -1 : 1 }); records.forEach(function (r) { if (remaining <= 0) return; var q = Math.min(remaining,Number(r.quantity_on_hand)); if (!q) return; out.push({ product_id:item.productId,batch_id:r.batch_id || null,from_stock_location_id:from,to_stock_location_id:to,movement_type:type,quantity_base_units:q,reference_type:'mobile_stock_request',reference_id:reference,created_by:employee.id,note:item.meta || null }); remaining = Number((remaining-q).toFixed(3)) }); if (remaining > 0) { var p = productMap.get(String(item.productId)) || {}; if (!(allowFreshNegative && p.product_category === 'food_ready')) throw new Error('Na skladě není dost kusů pro „' + item.name + '“.'); out.push({ product_id:item.productId,batch_id:null,from_stock_location_id:from,to_stock_location_id:to,movement_type:type,quantity_base_units:remaining,reference_type:'mobile_stock_request',reference_id:reference,created_by:employee.id,note:'Fresh odběr bez dohledané šarže',allow_negative_source:true }) } }); return out }) }
  function patchRequest(id,payload) { return api('/rest/v1/mobile_stock_requests?id=eq.' + id,{ method:'PATCH',headers:{ Prefer:'return=minimal' },body:JSON.stringify(payload) }) }
  function applyRows(rows) { return rows.length ? rpc('apply_stock_movements_v13',{ movement_rows:rows }) : Promise.resolve() }
  function finalize(id,reference) { var now = new Date().toISOString(); return patchRequest(id,{ status:'confirmed',confirmed_by:employee.id,confirmed_at:now,stock_applied_at:now,stock_reference_id:reference }) }
  function createRequest(items,type,note) { var req = { request_type:type,status:'picking',employee_id:employee.id,vehicle_id:vehicle.id,warehouse_id:vehicle.warehouse_id || route && route.warehouse_id,attendance_day_id:attendance && attendance.id || null,route_plan_id:route && route.id || null,calculation_source:'operator_warehouse',requested_for_date:today(),confirmed_by:employee.id,confirmed_at:new Date().toISOString(),note:note }; var rows = items.map(function (x) { var p = productMap.get(String(x.productId)) || {}; return { product_id:x.productId,product_name:x.name,sku:p.sku || null,unit:p.base_unit || x.unit || 'ks',requested_quantity:Number(x.quantity),prepared_quantity:Number(x.quantity),confirmed_quantity:Number(x.quantity),note:note,batch_id:x.batchId || null } }); return rpc('create_mobile_stock_request_with_items_v22',{ request_payload:req,items_payload:rows }) }
  function confirmReady() { var selected = products.load.filter(function (x) { return x.quantity > 0 }); return Promise.all(products.load.map(function (x) { return api('/rest/v1/mobile_stock_request_items?id=eq.' + x.requestItemId,{ method:'PATCH',headers:{ Prefer:'return=minimal' },body:JSON.stringify({ confirmed_quantity:Number(x.quantity) }) }) })).then(function () { var ref = readyRequest.stock_reference_id || 'mobile-stock:' + readyRequest.id; return selected.length ? movements(selected,warehouseLocation,vehicleLocation,'load_vehicle',ref,false).then(applyRows).then(function () { return finalize(readyRequest.id,ref) }) : finalize(readyRequest.id,ref) }) }
  function confirmMorning() { var selected = products.bagettes.filter(function (x) { return x.quantity > 0 }); if (!selected.length) throw new Error('Vyber alespoň jednu bagetu.'); return createRequest(selected,'vehicle_load','Ranní odběr fresh sortimentu operátorkou').then(function (d) { var ref = 'mobile-stock:' + d.request.id; return movements(selected,warehouseLocation,vehicleLocation,'load_vehicle',ref,true).then(applyRows).then(function () { return finalize(d.request.id,ref) }) }) }
  function confirmReturn() { var returned = products.return.filter(function (x) { return x.destination === 'warehouse' && x.quantity > 0 }), retained = products.return.filter(function (x) { return x.destination === 'route' && x.quantity > 0 }); localStorage.setItem('olvendWarehouseCarry:' + today() + ':' + vehicle.id,JSON.stringify(retained.map(function (x) { return { product_id:x.productId,batch_id:x.batchId,quantity:x.quantity } }))); if (!returned.length) return Promise.resolve(); return createRequest(returned,'vehicle_unload','Vrácení prodejného fresh sortimentu do skladu').then(function (d) { var ref = 'mobile-stock:' + d.request.id; return movements(returned,vehicleLocation,warehouseLocation,'return',ref,false).then(applyRows).then(function () { return finalize(d.request.id,ref) }) }) }
  function confirmWaste() { return Promise.all(products.waste.map(function (x) { return api('/rest/v1/route_vehicle_waste_items?id=eq.' + x.wasteId,{ method:'PATCH',headers:{ Prefer:'return=minimal' },body:JSON.stringify({ quantity:Number(x.quantity) }) }) })).then(function () { return rpc('confirm_route_vehicle_waste_unload_v29',{ waste_ids:products.waste.map(function (x) { return x.wasteId }),unloading_employee_id:employee.id }) }) }
  function submit() { if (preview) return new Promise(function (r) { setTimeout(r,700) }); if (activeFlow === 'load') return confirmReady(); if (activeFlow === 'bagettes') return confirmMorning(); if (activeFlow === 'return') return confirmReturn(); return confirmWaste() }

  root.addEventListener('click',function (e) {
    var open = e.target.closest('[data-open-flow]'); if (open) { openFlow(open.dataset.openFlow); return }
    var cs = e.target.closest('[data-catalog-delta]'); if (cs) { var row = cs.closest('[data-extra-id]'), item = extraBagettes.find(function (x) { return x.id === row.dataset.extraId }); item.pickQuantity = Math.max(1,Math.min(item.stock,Number(item.pickQuantity || 1)+Number(cs.dataset.catalogDelta))); row.querySelector('output').textContent = item.pickQuantity + ' ks'; return }
    var step = e.target.closest('[data-delta]'); if (step && activeFlow) { var card = step.closest('[data-product-id]'), item2 = products[activeFlow].find(function (x) { return x.id === card.dataset.productId }); if (item2.skipped && Number(step.dataset.delta)>0) { item2.skipped=false; item2.quantity=item2.previousQuantity || 1 } item2.quantity=Math.max(0,Math.min(Number(item2.max == null ? 999999 : item2.max),Number(item2.quantity)+Number(step.dataset.delta))); renderList(); refreshAction(); return }
    var skip = e.target.closest('[data-skip-item]'); if (skip) { var card2=skip.closest('[data-product-id]'), item3=products[activeFlow].find(function (x) { return x.id===card2.dataset.productId }); if (item3.skipped) { item3.skipped=false; item3.quantity=item3.previousQuantity || 1 } else { item3.previousQuantity=item3.quantity; item3.quantity=0; item3.skipped=true } renderList(); refreshAction(); return }
    if (e.target.closest('#ow-add-bagette')) { var c=document.getElementById('ow-catalog'); c.hidden=!c.hidden; return }
    var add=e.target.closest('[data-add-bagette]'); if (add) { var extra=extraBagettes.find(function (x) { return x.id===add.dataset.addBagette }); if (extra) products.bagettes.push(Object.assign({},extra,{ id:'fresh-' + extra.productId,quantity:extra.pickQuantity || 1 })); renderList(); refreshAction(); message('Jiná bageta byla přidána do ranního odběru.'); return }
    var confirm=e.target.closest('[data-confirm-item]'); if (confirm) { var r=confirm.closest('.ow-product'); r.classList.toggle('done'); confirm.classList.toggle('active'); confirm.textContent=r.classList.contains('done')?'✓ Potvrzeno':'Potvrdit' }
  })
  root.addEventListener('change',function (e) { var select=e.target.closest('[data-destination]'); if (!select) return; var card=select.closest('[data-product-id]'), item=products.return.find(function (x) { return x.id===card.dataset.productId }); if (item) item.destination=select.value })
  document.getElementById('ow-back').addEventListener('click',closeFlow)
  document.getElementById('ow-history').addEventListener('click',function () { message(historyRows.length ? 'Dnes je evidováno ' + historyRows.length + ' skutečných skladových pohybů tohoto vozidla.' : 'Dnes zatím není evidovaný žádný skladový pohyb.') })
  save.addEventListener('click',function () { if (!activeFlow) return; var flow=activeFlow, checks=flow==='return'||flow==='waste', left=checks?list.querySelectorAll('.ow-product:not(.done)').length:0; if (left) { message('Nejdřív potvrď všechny položky. Zbývá ' + left + '.'); return } setBusy(true,flow==='load'?'Převádím vychystané zboží do vozidla…':flow==='bagettes'?'Převádím ranní odběr baget do vozidla…':flow==='return'?'Ukládám vratku a další trasu…':'Uzavírám expirace a odpisy…'); save.disabled=true; Promise.resolve().then(submit).then(function () { completed.add(flow); if (flow==='load') readyRequest=null; if (flow==='waste') products.waste=[]; closeFlow(); message('Skladový pohyb je uložený.'); if (!preview) return Promise.all([vehicleBalances(),loadWaste(),loadHistory()]).then(renderContext) }).catch(function (err) { save.disabled=false; message(err.message || 'Skladový pohyb se nepodařilo uložit.',true) }).finally(function () { setBusy(false) }) })

  function seed() {
    vehicleStats={food:2,beverage:34,ingredient:12}
    document.querySelector('.ow-brand > div span').textContent='Sklad · vozidlo 2BC 8456'; document.querySelector('.ow-head small').textContent=longDate(); document.querySelector('.ow-vehicle strong').textContent='2BC 8456'; document.querySelector('.ow-user').textContent='MP'
    products.load=[{id:'redbull',name:'Red Bull 0,25 l',image:'./assets/product-images/ean-9002490200091.webp',quantity:6,max:6,tag:'Vychystáno',green:true},{id:'croissant',name:'7days Croissant 60 g',image:'./assets/product-images/ean-7622201390648.jpg',quantity:8,max:8,tag:'Vychystáno',green:true}]; readyRequest={id:'VY-2026-118'}
    products.bagettes=[{id:'svacinka',productId:1,name:'Snack Svačinka 158 g',image:'./assets/product-images/bagette-svacinka.jpg',quantity:12,max:20,expiry:'12. 11. 2026',tag:'Expirace zítra'},{id:'hamka',productId:2,name:'Snack Hamka 146 g',image:'./assets/product-images/bagette-hamka.jpg',quantity:6,max:12,expiry:'12. 11. 2026',tag:'Expirace zítra'}]
    extraBagettes=[{id:'porizek',productId:3,name:'Snack Pořízek 136 g',image:'./assets/product-images/bagette-porizek.jpg',pickQuantity:1,stock:8,max:8,tag:'Expirace 2 dny'}]
    products.return=[{id:'return1',name:'Snack Svačinka 158 g',image:'./assets/product-images/bagette-svacinka.jpg',quantity:2,max:2,tag:'Prodejné 1 den',destination:'route'}]
    products.waste=[{id:'waste1',name:'Snack Pořízek 136 g',image:'./assets/product-images/bagette-porizek.jpg',quantity:1,max:1,tag:'Odpis dnes'}]; historyRows=new Array(7).fill({}); updateOverview()
  }
  window.operatorWarehouseStart=function (s,e) { if (started || preview) return; started=true; session=s; employee=e; loadAll().catch(function () {}) }
  if (preview) seed()
})()
