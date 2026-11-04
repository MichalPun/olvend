const employeeId = '11111111-1111-4111-8111-111111111111'

const rows = {
  warehouses: [{ id: 1, name: 'Hlavní sklad', code: 'HLAVNI', city: 'Břeclav', active: true }],
  mobile_stock_requests: [{ id: 700, request_type: 'vehicle_load', status: 'requested', employee_id: employeeId, vehicle_id: 10, warehouse_id: 1, source_stock_location_id: 1, target_stock_location_id: 2, route_plan_id: null, created_at: '2026-11-04T08:00:00Z' }],
  mobile_stock_request_items: [{ id: 701, request_id: 700, product_id: 155, product_name: 'Nestea Lemon 0,5l', sku: '275', unit: 'Celé balení', requested_quantity: 1, prepared_quantity: null, confirmed_quantity: null, note: null }],
  employees: [{ id: employeeId, auth_user_id: 'mock-auth-user', name: 'Michal', surname: 'Punčochář', email: 'michal@example.test', role: 'admin' }],
  employee_directory: [{ id: employeeId, name: 'Veronika', surname: 'Testovací', email: 'veronika@example.test' }],
  vehicles: [{ id: 10, name: 'Fiat Doblo', plate: '3BU 9736', brand: 'Fiat', model: 'Doblo', warehouse_id: 1 }],
  route_plans: [],
  stock_locations: [{ id: 1, name: 'Hlavní sklad', location_type: 'warehouse', warehouse_id: 1, vehicle_id: null, active: true }, { id: 2, name: 'Fiat Doblo', location_type: 'vehicle', warehouse_id: null, vehicle_id: 10, active: true }],
  products: [
    { id: 155, name: 'Nestea Lemon 0,5l', sku: '275', product_category: 'water_product', usage_type: 'route_stock', base_unit: 'ks', active: true, note: '[olvend_storage_position:B-04]', image_path: null, image_updated_at: null },
    { id: 99, name: 'Nestea Peach 0,5l', sku: '67', product_category: 'water_product', usage_type: 'route_stock', base_unit: 'ks', active: true, note: '[olvend_storage_position:B-03]', image_path: null, image_updated_at: null }
  ],
  machine_planogram_slots: [{ product_sku: '275', product_family: 'Nestea', substitution_policy: 'approved_list', allowed_substitutes: 'Nestea Peach 0,5l (SKU 67); Nestea Lemon 0,5l (SKU 275)', active: true }],
  product_packages: [{ id: 1, product_id: 155, package_name: 'Celé balení', units_per_package: 12, is_default: true, active: true }, { id: 2, product_id: 99, package_name: 'Celé balení', units_per_package: 12, is_default: true, active: true }],
  stock_location_balances: [{ id: 1, stock_location_id: 1, product_id: 155, batch_id: null, quantity_on_hand: 0, reserved_quantity: 0 }, { id: 2, stock_location_id: 1, product_id: 99, batch_id: null, quantity_on_hand: 48, reserved_quantity: 0 }, { id: 3, stock_location_id: 2, product_id: 155, batch_id: null, quantity_on_hand: 4, reserved_quantity: 0 }, { id: 4, stock_location_id: 2, product_id: 99, batch_id: null, quantity_on_hand: 2, reserved_quantity: 0 }]
}

globalThis.__warehouseMockUpdates = []

class Query {
  constructor(table) { this.table = table; this.filters = []; this.payload = null }
  select() { return this }
  in(column, values) { this.filters.push((row) => values.map(String).includes(String(row[column]))); return this }
  eq(column, value) { this.filters.push((row) => String(row[column]) === String(value)); return this }
  order() { return this }
  limit() { return this }
  update(payload) { this.payload = payload; return this }
  maybeSingle() { return this.result().then(({ data, error }) => ({ data: data[0] || null, error })) }
  result() {
    let data = [...(rows[this.table] || [])].filter((row) => this.filters.every((filter) => filter(row)))
    if (this.payload) {
      data.forEach((row) => Object.assign(row, this.payload))
      globalThis.__warehouseMockUpdates.push({ table: this.table, payload: { ...this.payload }, ids: data.map((row) => row.id) })
    }
    return Promise.resolve({ data, error: null })
  }
  then(resolve, reject) { return this.result().then(resolve, reject) }
}

export const supabase = {
  from(table) { return new Query(table) },
  storage: { from() { return { createSignedUrl() { return Promise.resolve({ data: null, error: null }) } } } }
}

export function getOfflineRequestCount() { return 0 }
export async function syncOfflineRequests() { return { synced: 0, pending: 0 } }
export async function ensureWarehouseSession() { return { user: { id: 'mock-auth-user' } } }
