import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const inventory = await readFile(path.join(projectRoot, 'inventory.html'), 'utf8')

assert.match(inventory, /class="stock-card-v2-tab active"[^>]+data-stock-v2-tab="sales"/, 'sales or consumption must be the default product-card tab')
assert.match(inventory, /data-stock-v2-tab="where">Rozmístění zásob/, 'stock locations must live in their own tab')
assert.match(inventory, /data-product-sales-range="14"/, 'sales graph must support a 14-day range')
assert.match(inventory, /data-product-sales-range="30"/, 'sales graph must support a 30-day range')
assert.match(inventory, /data-product-sales-range="90"/, 'sales graph must support a 90-day range')
assert.match(inventory, /data-stock-location-search-input/, 'location overview must be searchable')
assert.match(inventory, /data-stock-location-filter="warehouse"/, 'location overview must filter warehouses')
assert.match(inventory, /data-stock-location-filter="vehicle"/, 'location overview must filter vehicles')
assert.match(inventory, /data-stock-location-filter="machine"/, 'location overview must filter machines')
assert.match(inventory, /convertRecipeQuantityToBase\(row\.current, row\.unit, product\.base_unit\)/, 'machine telemetry must be converted into the product base unit')
assert.match(inventory, /\.in\('movement_type', \['sale', 'consumption'\]\)/, 'chart must support both sales and ingredient consumption')

console.log('OK: stock detail opens on the sales dashboard and keeps locations in a separate searchable tab')
