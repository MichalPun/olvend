(function () {
  'use strict'

  var root = document.getElementById('operatorOperationalDashboard')
  if (!root) return
  var API = 'https://rerjlkrhiytgscjerqgs.supabase.co'
  var KEY = 'sb_publishable_A8OxCcapdNXAzQLjLsW5iA_XtGvBZ0S'
  var session = null
  var employee = null
  var attendance = null
  var route = null
  var routeStats = null
  var vehicle = null
  var stockLoaded = false
  var instructionState = 'loading'
  var worktimeCache = null
  var started = false

  var icons = {
    'cloud-sun':'<path d="M12 2v2M4.9 4.9l1.4 1.4M20 12h2M19.1 4.9l-1.4 1.4M15 8a4 4 0 0 0-7.7 1.4"/><path d="M17.5 18H9a5 5 0 1 1 4.9-6H15a3 3 0 0 1 2.5 6Z"/>',
    'chevron-right':'<path d="m9 18 6-6-6-6"/>',
    map:'<path d="m3 6 6-3 6 3 6-3v15l-6 3-6-3-6 3Z"/><path d="M9 3v15M15 6v15"/>',
    'car-front':'<path d="m5 17-2 2M19 17l2 2M5 9l1.5-4h11L19 9M3 11h18v6H3z"/><circle cx="7" cy="14" r="1"/><circle cx="17" cy="14" r="1"/>',
    'package-check':'<path d="m16 16 2 2 4-4"/><path d="M21 10V8a2 2 0 0 0-1-1.7l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.7l7 4a2 2 0 0 0 2 0l2-1.1"/><path d="m3.3 7 8.7 5 8.7-5M12 22V12"/>',
    'circle-check':'<circle cx="12" cy="12" r="10"/><path d="m8 12 2.5 2.5L16 9"/>',
    'circle-dot':'<circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="2"/>',
    clock:'<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>',
    'clipboard-check':'<rect width="16" height="18" x="4" y="3" rx="2"/><path d="M9 3V1h6v2M9 12l2 2 4-4"/>',
    check:'<path d="m5 12 4 4L19 6"/>'
  }

  function installIcons() {
    Array.prototype.forEach.call(root.querySelectorAll('[data-od-icon]'), function (node) {
      if (node.tagName.toLowerCase() === 'svg') return
      var svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg')
      svg.setAttribute('viewBox', '0 0 24 24')
      svg.setAttribute('fill', 'none')
      svg.setAttribute('stroke', 'currentColor')
      svg.setAttribute('stroke-width', '2')
      svg.setAttribute('stroke-linecap', 'round')
      svg.setAttribute('stroke-linejoin', 'round')
      svg.setAttribute('aria-hidden', 'true')
      if (node.className) svg.setAttribute('class', node.className)
      svg.innerHTML = icons[node.getAttribute('data-od-icon')] || icons.check
      node.replaceWith(svg)
    })
  }

  function esc(value) { return String(value == null ? '' : value).replace(/[&<>"']/g, function (c) { return ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'})[c] }) }
  function norm(value) { return String(value || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().trim() }
  function number(value) { var n = Number(value); return Number.isFinite(n) ? n : 0 }
  function today() { try { return new Intl.DateTimeFormat('sv-SE',{timeZone:'Europe/Prague'}).format(new Date()) } catch (_) { return new Date().toISOString().slice(0,10) } }
  function clock(value) { if (!value) return '—'; return new Date(value).toLocaleTimeString('cs-CZ',{hour:'2-digit',minute:'2-digit',timeZone:'Europe/Prague'}) }
  function fmt(value, decimals) { return number(value).toLocaleString('cs-CZ',{minimumFractionDigits:decimals || 0,maximumFractionDigits:decimals || 0}) }
  function minutesLabel(value) { var mins = Math.max(0,Math.round(number(value))), h = Math.floor(mins/60), m = mins%60; return h ? h + ' h' + (m ? ' ' + m + ' min' : '') : m + ' min' }
  function dateKey(d) { return [d.getFullYear(),('0'+(d.getMonth()+1)).slice(-2),('0'+d.getDate()).slice(-2)].join('-') }
  function monthRange() { var now = new Date(), first = new Date(now.getFullYear(),now.getMonth(),1), last = new Date(now.getFullYear(),now.getMonth()+1,0); return {from:dateKey(first),to:dateKey(last),first:first,last:last} }
  function doneStatus(value) { return ['done','completed','visited','skipped','closed'].indexOf(String(value || '').toLowerCase()) >= 0 }
  function greeting() { var hour = new Date().getHours(); return hour < 10 ? 'Dobré ráno' : hour < 18 ? 'Dobrý den' : 'Dobrý večer' }
  function vocative(name) { var n=String(name||'').trim(), lower=n.toLocaleLowerCase('cs-CZ'), known={michal:'Michale',pavel:'Pavle',petr:'Petře',marek:'Marku',tomáš:'Tomáši',lukáš:'Lukáši',martin:'Martine',david:'Davide',jan:'Jane',jakub:'Jakube',radek:'Radku',roman:'Romane',kristýna:'Kristýno',petra:'Petro',veronika:'Veroniko',lucie:'Lucie'}; if(known[lower])return known[lower]; if(/a$/i.test(n))return n.slice(0,-1)+'o'; return n }

  function api(path, options, timeoutMs) {
    var controller = typeof AbortController === 'function' ? new AbortController() : null
    var opts = Object.assign({}, options || {})
    opts.headers = Object.assign({apikey:KEY,Authorization:'Bearer '+session.access_token,'Content-Type':'application/json'},opts.headers||{})
    if (controller) opts.signal = controller.signal
    var timer
    var timeout = new Promise(function (_, reject) { timer=setTimeout(function(){if(controller)controller.abort();reject(new Error('Načítání trvalo příliš dlouho.'))},timeoutMs||12000) })
    return Promise.race([fetch(API+path,opts),timeout]).then(function(response){clearTimeout(timer);if(!response.ok)return response.text().then(function(t){var d;try{d=JSON.parse(t)}catch(_){};throw new Error(d&&(d.message||d.details)||'HTTP '+response.status)});if(response.status===204)return null;return response.text().then(function(t){return t?JSON.parse(t):null})},function(error){clearTimeout(timer);throw error})
  }

  function core() {
    var d=today(), routeFields='id,planning_date,title,vehicle_id,warehouse_id,start_latitude,start_longitude,execution_status,estimated_distance_km,estimated_drive_minutes,started_at,route_plan_stops(id,stop_order,status,title,address_snapshot,city_snapshot,latitude,longitude,machine_id,location_id)'
    return Promise.all([
      api('/rest/v1/attendance_days?select=*&employee_id=eq.'+encodeURIComponent(employee.id)+'&attendance_date=eq.'+d+'&order=created_at.desc&limit=1'),
      api('/rest/v1/route_plans?select='+encodeURIComponent(routeFields)+'&planned_employee_id=eq.'+encodeURIComponent(employee.id)+'&planning_date=eq.'+d+'&execution_status=neq.cancelled&order=created_at.desc&limit=1')
    ]).then(function(rows){attendance=rows[0]&&rows[0][0]||null;route=rows[1]&&rows[1][0]||null;return Boolean(attendance&&attendance.actual_start&&!attendance.actual_end)||Boolean(route&&route.execution_status==='in_progress')})
  }

  function setBase() {
    root.hidden=false
    document.getElementById('odDate').textContent=new Intl.DateTimeFormat('cs-CZ',{weekday:'long',day:'numeric',month:'long',timeZone:'Europe/Prague'}).format(new Date())
    document.getElementById('odGreeting').textContent=greeting()+', '+vocative(employee.name)
    var initials=(String(employee.name||'').charAt(0)+String(employee.surname||'').charAt(0)).toUpperCase()||'OP'
    root.querySelector('.od-user').textContent=initials
    var start=attendance&&attendance.actual_start||route&&route.started_at
    document.getElementById('odShiftSince').textContent=start?'· zahájena v '+clock(start):'· aktivní trasa'
    updateShiftClock()
  }

  function updateShiftClock() {
    var start=attendance&&attendance.actual_start||route&&route.started_at
    document.getElementById('odShiftElapsed').textContent=start?minutesLabel((Date.now()-new Date(start).getTime())/60000):'Probíhá'
    if(worktimeCache)renderWorktime(worktimeCache)
  }

  function routeKey(stop) { return stop.location_id?'l:'+stop.location_id:[stop.address_snapshot,stop.city_snapshot].join('|') }
  function machineImage(machine) {
    var p=norm([machine&&machine.brand,machine&&machine.model,machine&&machine.name,machine&&machine.machine_type].filter(Boolean).join(' '))
    if(p.indexOf('jetinno')>=0||p.indexOf('jl300')>=0)return '../assets/machine-overview/models/jetinno-jl300.jpg'
    if(p.indexOf('vitality')>=0)return '../assets/machine-overview/models/bianchi-vitality-l.png'
    if(p.indexOf('aria')>=0)return '../assets/machine-overview/models/bianchi-aria.jpg'
    if(p.indexOf('europa snack')>=0)return '../assets/machine-overview/models/rheavendors-europa-snack.png'
    if(p.indexOf('luce snack x')>=0)return '../assets/machine-overview/models/rheavendors-luce-snack-x.jpg'
    if(p.indexOf('luce zero')>=0)return '../assets/machine-overview/models/rheavendors-luce-zero-1.jpg'
    if(p.indexOf('luce x2')>=0)return '../assets/machine-overview/models/rheavendors-luce-x2.jpg'
    if(p.indexOf('luce x1')>=0)return '../assets/machine-overview/models/rheavendors-luce-x1.jpg'
    return './icon-192.png'
  }
  function machineType(machine) { var p=norm(machine&&machine.machine_type); return p.indexOf('snack')>=0||p.indexOf('food')>=0?'potravinový':'kávový' }

  function loadRouteDetail() {
    if (!route) {
      routeStats={completed:0,total:0,next:null,remainingDistance:0,drivenDistance:0}
      document.getElementById('odRouteProgress').textContent='0 / 0'
      document.getElementById('odNextLabel').textContent='TRASA NENÍ PŘIŘAZENA'
      document.getElementById('odNextPlace').textContent='Otevřete sekci Trasa'
      document.getElementById('odNextDetail').textContent='Zkontrolujte dnešní plán nebo kontaktujte vedoucího.'
      document.getElementById('odMachines').innerHTML=''
      return Promise.resolve()
    }
    var stops=(route&&route.route_plan_stops||[]).slice().sort(function(a,b){return number(a.stop_order)-number(b.stop_order)})
    var completed=stops.filter(function(s){return doneStatus(s.status)}).length, total=stops.length, next=stops.find(function(s){return !doneStatus(s.status)})||null
    var remainingDistance=Math.max(0,number(route&&route.estimated_distance_km)*(total?1-completed/total:0))
    var drivenDistance=Math.max(0,number(route&&route.estimated_distance_km)-remainingDistance)
    routeStats={completed:completed,total:total,next:next,remainingDistance:remainingDistance,drivenDistance:drivenDistance}
    document.getElementById('odRouteProgress').textContent=completed+' / '+total
    var percent=total?Math.round(completed/total*100):0
    document.getElementById('odProgressBar').style.width=percent+'%'
    root.querySelector('.od-progress').setAttribute('aria-valuenow',String(percent))
    if(!next){document.getElementById('odNextLabel').textContent='TRASA DOKONČENA';document.getElementById('odNextPlace').textContent='Všechny zastávky hotové';document.getElementById('odNextDetail').textContent='Otevřete trasu pro její uzavření';document.getElementById('odMachines').innerHTML='';return Promise.resolve()}
    var average=total?Math.max(1,Math.round(number(route.estimated_drive_minutes)/total)):0
    document.getElementById('odNextLabel').textContent='DALŠÍ ZASTÁVKA'+(average?' · ~'+average+' MIN':'')
    document.getElementById('odNextPlace').textContent=[next.city_snapshot,next.address_snapshot].filter(Boolean).join(' · ')||next.title||'Další zastávka'
    var same=stops.filter(function(s){return !doneStatus(s.status)&&routeKey(s)===routeKey(next)})
    document.getElementById('odNextDetail').textContent=same.length+' '+(same.length===1?'automat':'automaty')+' · zbývá přibližně '+fmt(remainingDistance)+' km'
    var ids=same.map(function(s){return s.machine_id}).filter(Boolean)
    if(!ids.length){document.getElementById('odMachines').innerHTML='';return Promise.resolve()}
    return api('/rest/v1/machines?select=id,name,machine_type,brand,model,evidence_number&id=in.('+ids.join(',')+')').then(function(machines){var map=new Map((machines||[]).map(function(m){return[String(m.id),m]}));document.getElementById('odMachines').innerHTML=same.slice(0,2).map(function(stop){var m=map.get(String(stop.machine_id))||{},name=m.model||m.name||stop.title||'Automat';return '<span class="od-machine"><img src="'+esc(machineImage(m))+'" alt="'+esc(name)+'"><span><b>'+esc(name)+'</b><small>'+esc(machineType(m))+'</small></span></span>'}).join('')}).catch(function(){document.getElementById('odMachines').innerHTML=''})
  }

  function vehicleImage(item){var path=String(item&&item.image_path||'');if(path.indexOf('static:')===0)path=path.slice(7);return /^\.\.\/assets\/vehicles\/[a-z0-9._-]+$/i.test(path)?path:'./icon-192.png'}
  function loadVehicle() {
    var vehicleId=attendance&&attendance.vehicle_id||route&&route.vehicle_id
    if(!vehicleId){document.getElementById('odVehicleName').textContent='Dnes bez vozidla';document.getElementById('odVehiclePlate').textContent='NEPOUŽÍVÁ SE';document.getElementById('odVehiclePhoto').innerHTML='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m5 17-2 2M19 17l2 2M5 9l1.5-4h11L19 9M3 11h18v6H3z"/><circle cx="7" cy="14" r="1"/><circle cx="17" cy="14" r="1"/></svg>';document.getElementById('odStockNote').textContent='Směna je zahájena bez použití vozidla';return Promise.resolve()}
    var range=monthRange()
    return Promise.all([
      api('/rest/v1/vehicles?select=id,name,plate,brand,model,current_odometer_km,next_service_odometer_km,stk_valid_until,image_path&id=eq.'+vehicleId+'&limit=1'),
      api('/rest/v1/vehicle_operation_logs?select=id,status,start_odometer_km,end_odometer_km,distance_km,started_at,ended_at,log_date&vehicle_id=eq.'+vehicleId+'&log_date=gte.'+range.from+'&log_date=lte.'+range.to+'&order=log_date'),
      api('/rest/v1/stock_locations?select=id&vehicle_id=eq.'+vehicleId+'&active=eq.true&limit=1')
    ]).then(function(rows){vehicle=rows[0]&&rows[0][0]||null;var logs=rows[1]||[],location=rows[2]&&rows[2][0];renderVehicle(logs);if(location)return loadStock(location.id);return null})
  }
  function renderVehicle(logs){if(!vehicle)return;document.getElementById('odVehicleName').textContent=vehicle.name||[vehicle.brand,vehicle.model].filter(Boolean).join(' ')||'Vozidlo';document.getElementById('odVehiclePlate').textContent=String(vehicle.plate||'—').replace(/\s+/g,'');document.getElementById('odVehiclePhoto').innerHTML='<img src="'+esc(vehicleImage(vehicle))+'" alt="'+esc(vehicle.name||'Vozidlo')+'">';var driven=routeStats?routeStats.drivenDistance:0,start=number((logs||[]).find(function(l){return l.status==='open'})&&logs.find(function(l){return l.status==='open'}).start_odometer_km)||number(vehicle.current_odometer_km),estimated=Math.round(start+driven),month=(logs||[]).reduce(function(sum,l){return sum+(l.status==='closed'?number(l.distance_km):0)},0)+Math.round(driven);document.getElementById('odOdometer').textContent=fmt(estimated)+' km';document.getElementById('odFromDeparture').textContent='+'+fmt(driven)+' km od výjezdu';document.getElementById('odRemainingKm').textContent=(routeStats?fmt(routeStats.remainingDistance):'—')+' km';document.getElementById('odServiceKm').textContent=vehicle.next_service_odometer_km?fmt(Math.max(0,number(vehicle.next_service_odometer_km)-estimated))+' km':'Nenastaven';document.getElementById('odMonthKm').textContent=fmt(month)+' km';document.getElementById('odStk').textContent=vehicle.stk_valid_until?String(vehicle.stk_valid_until).slice(5,7)+'/'+String(vehicle.stk_valid_until).slice(0,4):'Nenastavena'}

  function categoryKey(product){var c=String(product&&product.product_category||''),u=String(product&&product.base_unit||'');if(c==='food_ready')return'food';if(c==='snack_ready')return'snack';if(c==='beverage_ready'||c==='water_product')return'drink';if(c==='ingredient'&&u==='kg')return'ingredient';return''}
  function loadStock(locationId){return api('/rest/v1/stock_location_balances?select=quantity_on_hand,product_id,products(id,name,sku,product_category,base_unit)&stock_location_id=eq.'+locationId+'&quantity_on_hand=gt.0').then(function(rows){var current={food:0,snack:0,drink:0,ingredient:0,pieces:0,kg:0},products=[];(rows||[]).forEach(function(r){var p=r.products||{},q=number(r.quantity_on_hand),key=categoryKey(p);products.push(p);if(key)current[key]+=q;if(p.base_unit==='kg')current.kg+=q;else current.pieces+=q});document.getElementById('odVehiclePieces').textContent=fmt(current.pieces)+' ks';document.getElementById('odVehicleKg').textContent=current.kg?'+ '+fmt(current.kg,1)+' kg':'bez kg';var remaining=(route&&route.route_plan_stops||[]).filter(function(s){return !doneStatus(s.status)&&s.machine_id}).map(function(s){return s.machine_id}), projected=Object.assign({},current);if(!remaining.length){renderStock(current,projected);return}return api('/rest/v1/machine_planogram_slots?select=machine_id,product_sku,product_name,current_units,target_units,capacity_units,active&active=eq.true&machine_id=in.('+Array.from(new Set(remaining)).join(',')+')').then(function(slots){(slots||[]).forEach(function(slot){var p=products.find(function(item){return slot.product_sku&&norm(item.sku)===norm(slot.product_sku)})||products.find(function(item){return norm(item.name)===norm(slot.product_name)});var key=categoryKey(p);if(!key)return;var need=Math.max(0,number(slot.target_units!=null?slot.target_units:slot.capacity_units)-number(slot.current_units));projected[key]=Math.max(0,projected[key]-need)});renderStock(current,projected)}).catch(function(){renderStock(current,current)})}).then(function(){return loadLoadState()}).catch(function(){stockLoaded=false;updateAttention()})}
  function stockValue(value,key){return fmt(value,key==='ingredient'?1:0)+(key==='ingredient'?' kg':' ks')}
  function renderStock(current,projected){stockLoaded=true;[['Food','food'],['Snack','snack'],['Drink','drink'],['Ingredient','ingredient']].forEach(function(pair){document.getElementById('od'+pair[0]+'Now').textContent=stockValue(current[pair[1]],pair[1]);document.getElementById('od'+pair[0]+'End').textContent=stockValue(projected[pair[1]],pair[1])});document.getElementById('odStockNote').textContent='Aktualizováno '+clock(new Date())+' · odhad podle zbývající trasy';updateAttention()}
  function loadLoadState(){if(!vehicle)return Promise.resolve();return api('/rest/v1/mobile_stock_requests?select=id,status,confirmed_at&vehicle_id=eq.'+vehicle.id+'&requested_for_date=eq.'+today()+'&status=eq.confirmed&order=confirmed_at.desc&limit=1').then(function(rows){var el=document.getElementById('odLoadState');el.innerHTML='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="m8 12 2.5 2.5L16 9"/></svg>'+(rows&&rows.length?'Nakládka potvrzena':'Zásoba načtena')}).catch(function(){})}

  function loadWeather(){var lat=route&&route.start_latitude,lon=route&&route.start_longitude;if(lat==null||lon==null)return Promise.resolve();return api('/functions/v1/operator-weather',{method:'POST',body:JSON.stringify({latitude:number(lat),longitude:number(lon),place:'Výchozí místo'})},9000).then(function(w){if(!w||!Number.isFinite(Number(w.temperature_c)))return;document.getElementById('odWeatherTemperature').textContent=Math.round(number(w.temperature_c))+' °C';document.getElementById('odWeatherPlace').textContent=(w.place||'Výchozí místo')+' · '+(w.condition||'proměnlivo');document.getElementById('odWeather').hidden=false}).catch(function(){})}

  function loadInstruction(){return api('/rest/v1/daily_instructions?select=*&is_active=eq.true&order=created_at.desc&limit=20').then(function(rows){var d=today(),item=(rows||[]).find(function(x){var starts=x.is_persistent||!x.valid_from||String(x.valid_from).slice(0,10)<=d,ends=x.is_persistent||!x.valid_to||String(x.valid_to).slice(0,10)>=d,target=x.target_type==='company'||x.target_type==='role'&&String(x.target_role||'').toLowerCase()===String(employee.role||'').toLowerCase()||x.target_type==='employee'&&String(x.target_employee_id||'')===String(employee.id);return starts&&ends&&target});if(!item){instructionState='none';renderInstruction(null,true);return}return api('/rest/v1/instruction_acknowledgements?select=id,acknowledged_at&instruction_id=eq.'+item.id+'&employee_id=eq.'+employee.id+'&limit=1').then(function(a){instructionState=a&&a.length?'confirmed':'pending';renderInstruction(item,instructionState==='confirmed')})}).catch(function(){instructionState='unknown';renderInstruction(null,false)})}
  function renderInstruction(item,confirmed){var state=document.getElementById('odInstructionState');document.getElementById('odInstructionTitle').textContent=item&&(item.attachment_label||item.title||item.name)||'Dnešní pokyn';if(!item){state.classList.remove('pending');state.innerHTML='Dnes bez nového pokynu';document.getElementById('odInstructionNote').textContent='Pro dnešní směnu nebyl vydán nový pokyn.'}else if(confirmed){state.classList.remove('pending');state.innerHTML='✓ Přečteno a potvrzeno';document.getElementById('odInstructionNote').textContent='Otevřít dokument a záznam potvrzení'}else{state.classList.add('pending');state.innerHTML='Čeká na potvrzení';document.getElementById('odInstructionNote').textContent='Pokyn je potřeba otevřít a potvrdit'}updateAttention()}

  function easterSunday(year){var a=year%19,b=Math.floor(year/100),c=year%100,d=Math.floor(b/4),e=b%4,f=Math.floor((b+8)/25),g=Math.floor((b-f+1)/3),h=(19*a+b-d-g+15)%30,i=Math.floor(c/4),k=c%4,l=(32+2*e+2*i-h-k)%7,m=Math.floor((a+11*h+22*l)/451),month=Math.floor((h+l-7*m+114)/31),day=(h+l-7*m+114)%31+1;return new Date(year,month-1,day)}
  function isHoliday(date){var key=('0'+(date.getMonth()+1)).slice(-2)+'-'+('0'+date.getDate()).slice(-2),fixed={'01-01':1,'05-01':1,'05-08':1,'07-05':1,'07-06':1,'09-28':1,'10-28':1,'11-17':1,'12-24':1,'12-25':1,'12-26':1};if(fixed[key])return true;var easter=easterSunday(date.getFullYear()),friday=new Date(easter),monday=new Date(easter);friday.setDate(easter.getDate()-2);monday.setDate(easter.getDate()+1);return dateKey(date)===dateKey(friday)||dateKey(date)===dateKey(monday)}
  function loadWorktime(){var range=monthRange();return Promise.all([api('/rest/v1/employees?select=contracted_weekly_hours,employment_type&id=eq.'+employee.id+'&limit=1'),api('/rest/v1/attendance_days?select=attendance_date,payable_minutes,actual_start,actual_end&employee_id=eq.'+employee.id+'&attendance_date=gte.'+range.from+'&attendance_date=lte.'+range.to)]).then(function(rows){var profile=rows[0]&&rows[0][0]||{},days=rows[1]||[],weekly=number(profile.contracted_weekly_hours)||40,daily=weekly/5*60,fund=0,holiday=0;for(var d=new Date(range.first);d<=range.last;d.setDate(d.getDate()+1)){if(d.getDay()===0||d.getDay()===6)continue;fund+=daily;if(isHoliday(d))holiday+=daily}worktimeCache={days:days,daily:daily,fund:fund,holiday:holiday};renderWorktime(worktimeCache)}).catch(function(){})}
  function renderWorktime(data){var now=Date.now(),todayKey=today(),todayMinutes=0,total=0;(data.days||[]).forEach(function(day){var value=number(day.payable_minutes);if(day.attendance_date===todayKey&&day.actual_start&&!day.actual_end)value=Math.max(value,(now-new Date(day.actual_start).getTime())/60000);if(day.attendance_date===todayKey)todayMinutes=value;total+=value});var remaining=Math.max(0,data.fund-total-data.holiday);document.getElementById('odTodayHours').textContent=minutesLabel(todayMinutes);document.getElementById('odMonthHours').textContent=minutesLabel(total);document.getElementById('odRemainingHours').textContent=minutesLabel(remaining);document.getElementById('odWorktimeNote').textContent='Měsíční fond '+minutesLabel(data.fund)+' · svátky '+minutesLabel(data.holiday)}

  function updateAttention(){var title=document.getElementById('odAttentionTitle'),text=document.getElementById('odAttentionText');if(instructionState==='pending'){title.textContent='Dnešní pokyn ještě není potvrzený';text.textContent='Otevřete Pokyn dne a dokončete potvrzení.';return}if(!vehicle){title.textContent='Směna běží bez přiřazeného vozidla';text.textContent='Pokud vozidlo používáte, zkontrolujte jeho přiřazení.';return}if(!stockLoaded){title.textContent='Kontroluji sklad vozidla';text.textContent='Skladový souhrn se ještě načítá nebo není dostupný.';return}title.textContent='V tuto chvíli není potřeba nic řešit';text.textContent='Vozidlo, pokyn a zásoba jsou načtené.'}

  function bind(){document.getElementById('odRouteCard').addEventListener('click',function(){location.href='./trasa.html'});document.getElementById('odVehicleCard').addEventListener('click',function(){location.href='./vozidlo.html'});document.getElementById('odStockCard').addEventListener('click',function(){location.href='./sklad.html'});document.getElementById('odTimeCard').addEventListener('click',function(){location.href='./profil.html?view=worktime'});document.getElementById('odInstructionCard').addEventListener('click',function(){location.href='./pokyny.html'});document.getElementById('odReportProblem').addEventListener('click',function(){location.href='./trasa.html?report=problem'})}

  function start(activeSession,activeEmployee){if(started)return;started=true;session=activeSession;employee=activeEmployee||{};if(!session||!employee.id)return;core().then(function(active){if(!active)return;setBase();return loadRouteDetail().then(function(){return Promise.all([loadVehicle(),loadWeather(),loadInstruction(),loadWorktime()])})}).catch(function(){})}

  function seed(){var legacy=document.querySelector('#olvend-before-shift-tiles > .ot-phone');if(legacy)legacy.hidden=true;session={access_token:'preview'};employee={id:'preview',name:'Michal',surname:'Punčochář',role:'operator'};attendance={actual_start:new Date(Date.now()-84*60000).toISOString(),vehicle_id:6};route={id:1,vehicle_id:6,execution_status:'in_progress',estimated_distance_km:132.7,estimated_drive_minutes:108,route_plan_stops:[{id:1,stop_order:1,status:'done',machine_id:1,location_id:1},{id:2,stop_order:2,status:'done',machine_id:2,location_id:1},{id:3,stop_order:3,status:'planned',machine_id:3,location_id:2,city_snapshot:'Hodonín',address_snapshot:'Stavební 4058/3'},{id:4,stop_order:4,status:'planned',machine_id:4,location_id:2,city_snapshot:'Hodonín',address_snapshot:'Stavební 4058/3'},{id:5,stop_order:5,status:'planned',machine_id:5,location_id:3},{id:6,stop_order:6,status:'planned',machine_id:6,location_id:4}]};setBase();routeStats={completed:2,total:6,remainingDistance:84,drivenDistance:49};document.getElementById('odRouteProgress').textContent='2 / 6';document.getElementById('odProgressBar').style.width='33%';root.querySelector('.od-progress').setAttribute('aria-valuenow','33');document.getElementById('odNextLabel').textContent='DALŠÍ ZASTÁVKA · ~18 MIN';document.getElementById('odNextPlace').textContent='Hodonín · Stavební 4058/3';document.getElementById('odNextDetail').textContent='2 automaty · zbývá přibližně 84 km';document.getElementById('odMachines').innerHTML='<span class="od-machine"><img src="../assets/machine-overview/models/rheavendors-europa-snack.png" alt="Europa Snack Side"><span><b>Europa Snack Side</b><small>potravinový</small></span></span><span class="od-machine"><img src="../assets/machine-overview/models/rheavendors-luce-x2.jpg" alt="Luce X2 I"><span><b>Luce X2 I</b><small>kávový</small></span></span>';vehicle={name:'Fiat Doblò Cargo',plate:'3BU9736',image_path:'static:../assets/vehicles/fiat-doblo-2012.png',current_odometer_km:128318,next_service_odometer_km:140000,stk_valid_until:'2028-09-20'};renderVehicle([{status:'closed',distance_km:1860},{status:'open',start_odometer_km:128318}]);document.getElementById('odVehiclePieces').textContent='1 481 ks';document.getElementById('odVehicleKg').textContent='+ 60 kg';renderStock({food:42,snack:309,drink:120,ingredient:60},{food:12,snack:248,drink:86,ingredient:51});instructionState='confirmed';renderInstruction({title:'Dnešní pokyn'},true);worktimeCache={days:[{attendance_date:today(),payable_minutes:84}],fund:10080,holiday:480};renderWorktime(worktimeCache);document.getElementById('odLoadState').innerHTML='✓ Nakládka potvrzena';document.getElementById('odWeatherTemperature').textContent='8 °C';document.getElementById('odWeatherPlace').textContent='Blučina · oblačno';document.getElementById('odWeather').hidden=false;updateAttention()}

  bind();installIcons();window.operatorDashboardStart=start;setInterval(updateShiftClock,60000)
  if(location.hostname==='127.0.0.1'&&new URLSearchParams(location.search).get('preview')==='dashboard')seed()
})()
