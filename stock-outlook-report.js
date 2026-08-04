const DAY_MS = 86400000;

function normalize(value) {
  return String(value ?? '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .trim();
}

function dateKey(date) {
  const value = date instanceof Date ? date : new Date(date);
  return `${value.getFullYear()}-${String(value.getMonth() + 1).padStart(2, '0')}-${String(value.getDate()).padStart(2, '0')}`;
}

function confirmedSaleQuantity(row) {
  return Number(row?.cash_quantity || 0)
    + Number(row?.cashless_quantity || 0)
    + Number(row?.free_vend_quantity || 0)
    + Number(row?.unknown_payment_quantity || 0);
}

function isLidItem(row) {
  const text = normalize([row?.product_name, row?.container_code, row?.slot_code, row?.unit_label].filter(Boolean).join(' '));
  return /\b(vicko|vicka|vick|lid|lids|cup lid|kelimek vicko)\b/.test(text)
    || text.includes('vicko')
    || text.includes('vicka')
    || text.includes('lid');
}

function isSchoolLocation(row) {
  const text = normalize([row?.location_name, row?.machine_name].filter(Boolean).join(' '));
  return /\b(skola|skolni|zakladni|stredni|gymnazium|vos|sos|sou|ss)\b/.test(text);
}

function schoolsAreActive(date = new Date()) {
  const month = date.getMonth();
  const day = date.getDate();
  return !(month === 6 || (month === 7 && day < 24));
}

function isServiceSuspended(value, date = new Date()) {
  if (!value) return false;
  const until = new Date(`${value}T00:00:00`);
  if (Number.isNaN(until.getTime())) return false;
  const current = new Date(date);
  current.setHours(0, 0, 0, 0);
  return current < until;
}

function convertQuantity(quantity, fromUnit, toUnit) {
  const from = normalize(fromUnit);
  const to = normalize(toUnit);
  if (!from || !to || from === to) return Number(quantity || 0);
  const mass = { g: 1, gram: 1, gramy: 1, kg: 1000, kilogram: 1000 };
  const volume = { ml: 1, l: 1000, litr: 1000, litry: 1000 };
  if (mass[from] && mass[to]) return Number(quantity || 0) * mass[from] / mass[to];
  if (volume[from] && volume[to]) return Number(quantity || 0) * volume[from] / volume[to];
  return Number(quantity || 0);
}

function countObservedHours(start, end, targetHour, targetWeekday = null) {
  if (!start || !end || end <= start) return 0;
  const cursor = new Date(start);
  cursor.setMinutes(0, 0, 0);
  if (cursor < start) cursor.setHours(cursor.getHours() + 1);
  let count = 0;
  while (cursor.getTime() + 3600000 <= end.getTime()) {
    if (cursor.getHours() === targetHour && (targetWeekday === null || cursor.getDay() === targetWeekday)) count += 1;
    cursor.setHours(cursor.getHours() + 1);
  }
  return count;
}

function quantityLabel(value, unit) {
  const amount = Number(value || 0);
  const decimals = normalize(unit) === 'ks' ? 0 : 2;
  return `${amount.toLocaleString('cs-CZ', { minimumFractionDigits: 0, maximumFractionDigits: decimals })} ${unit || 'ks'}`;
}

function uniqueById(rows) {
  return Array.from(new Map((rows || []).map((row) => [String(row.id), row])).values());
}

export async function loadStockOutlookReport({ supabase, fetchPaged }) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);
  const tomorrowKey = dateKey(tomorrow);
  const historyStart = new Date(today);
  historyStart.setDate(historyStart.getDate() - 13);

  const [slotsResult, containersResult, linksResult, statesResult, inventoriedResult, productsResult, routesResult] = await Promise.all([
    fetchPaged(() => supabase
      .from('machine_planogram_slots')
      .select('id, machine_id, slot_code, product_name, product_sku, current_units, capacity_units, desired_units, fill_percent, active')
      .eq('active', true)),
    supabase
      .from('machine_coffee_containers')
      .select('id, machine_id, container_code, product_name, product_sku, current_quantity, capacity_quantity, min_refill_quantity, unit, active')
      .eq('active', true),
    supabase
      .from('machine_external_links')
      .select('machine_id, provider, telemetry_enabled')
      .eq('telemetry_enabled', true),
    supabase.from('machine_telemetry_state').select('machine_id, provider, last_seen_at'),
    supabase
      .from('route_machine_visit_items')
      .select('machine_id')
      .not('actual_before_quantity', 'is', null)
      .limit(5000),
    supabase
      .from('products')
      .select('id, sku, name, base_unit, product_category')
      .eq('active', true),
    supabase
      .from('route_plans')
      .select('id, planning_date, planned_departure_time, title, execution_status, estimated_drive_minutes, route_plan_stops(id, machine_id, stop_order, status, estimated_service_minutes)')
      .eq('planning_date', tomorrowKey)
      .neq('execution_status', 'cancelled')
  ]);

  [slotsResult, containersResult, linksResult, statesResult, inventoriedResult, productsResult, routesResult].forEach((result) => {
    if (result.error) throw result.error;
  });

  const slots = slotsResult.data || [];
  const containers = containersResult.data || [];
  const states = statesResult.data || [];
  const links = linksResult.data || [];
  const routes = routesResult.data || [];
  const machineIds = [...new Set([
    ...slots.map((row) => row.machine_id),
    ...containers.map((row) => row.machine_id),
    ...states.map((row) => row.machine_id),
    ...routes.flatMap((route) => (route.route_plan_stops || []).map((stop) => stop.machine_id))
  ].map(Number).filter(Boolean))];

  const machinesResult = machineIds.length
    ? await supabase.from('machines').select('id, evidence_number, name, machine_type, location_id, active').in('id', machineIds)
    : { data: [], error: null };
  if (machinesResult.error) throw machinesResult.error;
  const machines = machinesResult.data || [];
  const locationIds = [...new Set(machines.map((machine) => Number(machine.location_id)).filter(Boolean))];
  const locationsResult = locationIds.length
    ? await supabase.from('locations').select('id, name, city, service_suspended_until').in('id', locationIds)
    : { data: [], error: null };
  if (locationsResult.error) throw locationsResult.error;
  const locations = locationsResult.data || [];

  const machineMap = new Map(machines.map((machine) => [String(machine.id), machine]));
  const locationMap = new Map(locations.map((location) => [String(location.id), location]));
  const products = productsResult.data || [];
  const productById = new Map(products.map((product) => [String(product.id), product]));
  const productBySku = new Map(products.filter((product) => product.sku != null).map((product) => [String(product.sku), product]));
  const productByName = new Map(products.map((product) => [normalize(product.name), product]).filter(([key]) => key));
  const inventoryMachineIds = new Set((inventoriedResult.data || []).map((row) => String(row.machine_id)));
  const enabledLinks = new Set(links.map((link) => `${link.machine_id}:${normalize(link.provider)}`));
  const freshCutoff = Date.now() - 15 * 60 * 1000;
  const freshStates = states.filter((state) => enabledLinks.has(`${state.machine_id}:${normalize(state.provider)}`)
    && new Date(state.last_seen_at || 0).getTime() >= freshCutoff);
  const freshMachineIds = new Set(freshStates.map((state) => String(state.machine_id)));
  const showSchools = schoolsAreActive(today);

  const enrichBase = (row) => {
    const machine = machineMap.get(String(row.machine_id));
    const location = machine?.location_id ? locationMap.get(String(machine.location_id)) : null;
    return {
      ...row,
      machine_name: machine?.name || `Automat ${row.machine_id || ''}`.trim(),
      machine_code: machine?.evidence_number ? `EV ${machine.evidence_number}` : '',
      machine_type: machine?.machine_type || '',
      location_id: machine?.location_id || '',
      location_name: [location?.city, location?.name].filter(Boolean).join(' · ') || 'Bez lokality',
      service_suspended_until: location?.service_suspended_until || null
    };
  };

  const lowSlots = slots.map((slot) => {
    const row = enrichBase(slot);
    const product = productBySku.get(String(slot.product_sku || '')) || productByName.get(normalize(slot.product_name));
    const current = Number(slot.current_units ?? 0);
    const capacity = Number(slot.capacity_units || 0);
    const desired = Number(slot.desired_units || 0);
    const percent = capacity > 0 ? Math.max(0, Math.min(100, Math.round((current / capacity) * 100))) : Number(slot.fill_percent || 0);
    const isFood = ['food_ready', 'snack_ready'].includes(normalize(product?.product_category)) || normalize(row.machine_type) === 'snack';
    const low = isFood
      ? (capacity > 0 && capacity <= 6 ? current <= Math.min(2, Math.max(0, capacity - 1)) : capacity > 0 && percent <= 25)
      : (capacity > 0 && percent <= 25) || (desired > 0 && current <= desired);
    return { ...row, current, capacity, percent, desired, is_food: isFood, low, selection_code: slot.slot_code, unit_label: 'ks' };
  }).filter((row) => row.low && (row.is_food || normalize(row.machine_type) === 'snack' || (freshMachineIds.has(String(row.machine_id)) && inventoryMachineIds.has(String(row.machine_id)))));

  const lowContainers = containers.map((container) => {
    const row = enrichBase(container);
    const current = Number(container.current_quantity ?? 0);
    const capacity = Number(container.capacity_quantity || 0);
    const percent = capacity > 0 ? Math.max(0, Math.min(100, Math.round((current / capacity) * 100))) : 0;
    return { ...row, current, capacity, percent, low: capacity > 0 && percent <= 25, selection_code: container.container_code, unit_label: container.unit || 'ks' };
  }).filter((row) => row.low && freshMachineIds.has(String(row.machine_id)) && inventoryMachineIds.has(String(row.machine_id)));

  const lowStock = [...lowSlots, ...lowContainers]
    .filter((row) => !isLidItem(row))
    .filter((row) => showSchools || !isSchoolLocation(row))
    .filter((row) => !isServiceSuspended(row.service_suspended_until, today));
  const lowMachineIds = [...new Set(lowStock.map((row) => Number(row.machine_id)).filter(Boolean))];

  let recipeRows = [];
  let salesRows = [];
  if (lowMachineIds.length) {
    const [recipeResult, lowMachineSales] = await Promise.all([
      supabase
        .from('machine_coffee_recipe_items')
        .select('machine_id, product_id, quantity_per_vend, unit, active, machine_coffee_buttons(selection_code)')
        .in('machine_id', lowMachineIds)
        .eq('active', true),
      fetchPaged(() => supabase
        .from('telemetry_sales_events')
        .select('id, provider, machine_id, selection_code, product_name, product_sku, cash_quantity, cashless_quantity, free_vend_quantity, unknown_payment_quantity, source_event_at')
        .eq('provider', 'ima')
        .in('machine_id', lowMachineIds)
        .gte('source_event_at', historyStart.toISOString())
        .order('source_event_at', { ascending: false })
        .order('id', { ascending: false }))
    ]);
    if (recipeResult.error && !/machine_coffee_recipe_items|schema cache/i.test(String(recipeResult.error.message || ''))) throw recipeResult.error;
    recipeRows = recipeResult.data || [];
    salesRows = lowMachineSales;
  }

  const recipes = new Map();
  recipeRows.forEach((item) => {
    const key = `${item.machine_id}::${normalize(item.machine_coffee_buttons?.selection_code)}`;
    const list = recipes.get(key) || [];
    list.push(item);
    recipes.set(key, list);
  });

  const routeCoverage = new Map();
  routes.forEach((route) => {
    const stops = [...(route.route_plan_stops || [])]
      .filter((stop) => stop.machine_id && String(stop.status || 'planned') !== 'skipped')
      .sort((a, b) => Number(a.stop_order || 0) - Number(b.stop_order || 0));
    const departure = new Date(`${route.planning_date}T${String(route.planned_departure_time || '07:00').slice(0, 5)}:00`);
    const drivePerStop = stops.length ? Number(route.estimated_drive_minutes || 0) / stops.length : 0;
    let serviceMinutes = 0;
    stops.forEach((stop, index) => {
      const arrival = new Date(departure.getTime() + ((index + 1) * drivePerStop + serviceMinutes) * 60000);
      const key = String(stop.machine_id);
      const current = routeCoverage.get(key);
      if (!current || arrival < current.arrival) {
        routeCoverage.set(key, {
          routeId: route.id,
          routeTitle: route.title || `Trasa ${route.planning_date}`,
          stopOrder: Number(stop.stop_order || index + 1),
          arrival
        });
      }
      serviceMinutes += Number(stop.estimated_service_minutes || 0);
    });
  });

  const coverageStart = new Map();
  const salesByMachineProduct = new Map();
  const addSale = (machineId, productId, sourceEventAt, quantity) => {
    const at = new Date(sourceEventAt || '');
    const amount = Number(quantity || 0);
    if (!machineId || !productId || Number.isNaN(at.getTime()) || amount <= 0.0001) return;
    const key = `${machineId}::${productId}`;
    const values = salesByMachineProduct.get(key) || [];
    values.push({ at, quantity: amount });
    salesByMachineProduct.set(key, values);
  };

  uniqueById(salesRows).forEach((sale) => {
    const amount = confirmedSaleQuantity(sale);
    if (amount <= 0.0001) return;
    const at = new Date(sale.source_event_at || '');
    const machineKey = String(sale.machine_id || '');
    if (!Number.isNaN(at.getTime())) {
      const currentStart = coverageStart.get(machineKey);
      if (!currentStart || at < currentStart) coverageStart.set(machineKey, at);
    }
    const directProduct = productBySku.get(String(sale.product_sku || '')) || productByName.get(normalize(sale.product_name));
    if (directProduct) addSale(sale.machine_id, directProduct.id, sale.source_event_at, amount);
    (recipes.get(`${sale.machine_id}::${normalize(sale.selection_code)}`) || []).forEach((recipe) => {
      const ingredient = productById.get(String(recipe.product_id));
      addSale(sale.machine_id, recipe.product_id, sale.source_event_at, amount * convertQuantity(
        Number(recipe.quantity_per_vend || 0),
        recipe.unit || ingredient?.base_unit,
        ingredient?.base_unit || recipe.unit
      ));
    });
  });

  const estimateUntil = (machineId, productId, arrival) => {
    const now = new Date();
    const start = coverageStart.get(String(machineId || ''));
    const history = salesByMachineProduct.get(`${machineId}::${productId}`) || [];
    if (!(arrival instanceof Date) || Number.isNaN(arrival.getTime()) || arrival <= now || !start || now - start < DAY_MS || !history.length) return 0;
    const byHour = new Map();
    const byWeekdayHour = new Map();
    history.forEach((row) => {
      const hour = row.at.getHours();
      const weekdayHour = `${row.at.getDay()}::${hour}`;
      byHour.set(hour, Number(((byHour.get(hour) || 0) + row.quantity).toFixed(4)));
      byWeekdayHour.set(weekdayHour, Number(((byWeekdayHour.get(weekdayHour) || 0) + row.quantity).toFixed(4)));
    });
    let expected = 0;
    let cursor = new Date(now);
    while (cursor < arrival) {
      const bucketEnd = new Date(cursor);
      bucketEnd.setMinutes(0, 0, 0);
      bucketEnd.setHours(bucketEnd.getHours() + 1);
      const segmentEnd = bucketEnd < arrival ? bucketEnd : arrival;
      const segmentHours = Math.max(0, (segmentEnd - cursor) / 3600000);
      const hour = cursor.getHours();
      const weekday = cursor.getDay();
      const allOccurrences = countObservedHours(start, now, hour);
      const allRate = allOccurrences > 0 ? Number(byHour.get(hour) || 0) / allOccurrences : 0;
      const weekdayOccurrences = countObservedHours(start, now, hour, weekday);
      const weekdayQuantity = Number(byWeekdayHour.get(`${weekday}::${hour}`) || 0);
      const rate = weekdayOccurrences > 0 ? (weekdayQuantity + allRate * 2) / (weekdayOccurrences + 2) : allRate;
      expected += rate * segmentHours;
      cursor = segmentEnd;
    }
    return Math.max(0, Number(expected.toFixed(3)));
  };

  const grouped = new Map();
  lowStock.forEach((item) => {
    const key = String(item.machine_id || '');
    const machineGroup = grouped.get(key) || {
      machine_id: item.machine_id,
      machine_name: item.machine_name,
      machine_code: item.machine_code,
      location_id: item.location_id,
      location_name: item.location_name,
      items: [],
      products: new Map(),
      lowest_percent: 100
    };
    machineGroup.items.push(item);
    machineGroup.lowest_percent = Math.min(machineGroup.lowest_percent, Number(item.percent || 0));
    const product = productBySku.get(String(item.product_sku || '')) || productByName.get(normalize(item.product_name));
    const productKey = product?.id ? String(product.id) : `name:${normalize(item.product_name || item.product_sku || item.selection_code || 'unknown')}`;
    const current = machineGroup.products.get(productKey) || {
      product,
      product_name: item.product_name || item.product_sku || 'Bez produktu',
      current: 0,
      capacity: 0,
      unit: item.unit_label || item.unit || product?.base_unit || 'ks',
      positions: []
    };
    current.current += Number(item.current || 0);
    current.capacity += Number(item.capacity || 0);
    current.positions.push(item.selection_code || item.slot_code || item.container_code || '?');
    machineGroup.products.set(productKey, current);
    grouped.set(key, machineGroup);
  });

  const fallbackArrival = new Date(tomorrow);
  fallbackArrival.setHours(17, 0, 0, 0);
  const rows = Array.from(grouped.values()).map((group) => {
    const route = routeCoverage.get(String(group.machine_id));
    const arrival = route?.arrival || fallbackArrival;
    const productsForMachine = Array.from(group.products.values()).map((item) => {
      const forecast = item.product?.id ? Math.min(item.current, estimateUntil(group.machine_id, item.product.id, arrival)) : 0;
      const projected = Math.max(0, Number((item.current - forecast).toFixed(3)));
      const emptyNow = item.current <= 0.0001;
      const stockoutRisk = !emptyNow && forecast > 0.0001 && projected <= 0.0001;
      return {
        ...item,
        position: item.positions.join(', '),
        forecast,
        projected,
        empty_now: emptyNow,
        stockout_risk: stockoutRisk,
        current_label: `${quantityLabel(item.current, item.unit)} / ${quantityLabel(item.capacity, item.unit)}`,
        projected_label: quantityLabel(projected, item.unit),
        forecast_label: quantityLabel(forecast, item.unit)
      };
    }).sort((a, b) => Number(b.empty_now) - Number(a.empty_now) || Number(b.stockout_risk) - Number(a.stockout_risk) || a.current - b.current);
    const criticalNow = productsForMachine.some((item) => item.empty_now);
    const stockoutRisk = productsForMachine.some((item) => item.stockout_risk);
    const arrivalTime = route?.arrival && !Number.isNaN(route.arrival.getTime())
      ? route.arrival.toLocaleTimeString('cs-CZ', { hour: '2-digit', minute: '2-digit' })
      : '';
    return {
      machine_id: group.machine_id,
      machine_name: group.machine_name,
      machine_code: group.machine_code,
      location_id: group.location_id,
      location_name: group.location_name,
      low_count: group.items.length,
      lowest_percent: Math.max(0, Math.round(group.lowest_percent)),
      products: productsForMachine,
      product_name: productsForMachine.map((item) => item.product_name).join(' · '),
      critical_now: criticalNow,
      stockout_risk: stockoutRisk,
      covered: Boolean(route),
      route_label: route ? `${route.routeTitle} · zastávka ${route.stopOrder} · ETA ${arrivalTime}` : `Bez trasy na ${tomorrow.toLocaleDateString('cs-CZ')}`,
      action_href: route ? `routes-create.html?edit=${encodeURIComponent(route.routeId)}` : `routes-create.html?date=${encodeURIComponent(tomorrowKey)}`
    };
  }).sort((a, b) => Number(b.critical_now && !b.covered) - Number(a.critical_now && !a.covered)
    || Number(b.stockout_risk && !b.covered) - Number(a.stockout_risk && !a.covered)
    || Number(b.critical_now) - Number(a.critical_now)
    || Number(b.stockout_risk) - Number(a.stockout_risk)
    || Number(a.covered) - Number(b.covered)
    || a.lowest_percent - b.lowest_percent);

  const initialInventoryCount = freshStates.filter((state) => !inventoryMachineIds.has(String(state.machine_id)))
    .filter((state) => normalize(machineMap.get(String(state.machine_id))?.machine_type) !== 'snack').length;

  return {
    rows,
    machines,
    locations,
    meta: {
      target_date: tomorrowKey,
      target_date_label: `stav teď → ${tomorrow.toLocaleDateString('cs-CZ')}`,
      history_days: 14,
      initial_inventory_count: initialInventoryCount,
      generated_at: new Date().toISOString()
    }
  };
}
