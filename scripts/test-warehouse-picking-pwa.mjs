import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptsDirectory = path.dirname(fileURLToPath(import.meta.url))
const root = path.resolve(scriptsDirectory, '..')
const html = fs.readFileSync(path.join(root, 'warehouse-picking.html'), 'utf8')
const javascript = fs.readFileSync(path.join(root, 'warehouse-picking.js'), 'utf8')
const supabaseJavascript = fs.readFileSync(path.join(root, 'supabase.js'), 'utf8')
const serviceWorker = fs.readFileSync(path.join(root, 'sw.js'), 'utf8')
const manifest = JSON.parse(fs.readFileSync(path.join(root, 'warehouse-picking.webmanifest'), 'utf8'))

const ids = new Set([...html.matchAll(/\bid="([^"]+)"/g)].map((match) => match[1]))
const referencedIds = new Set([...javascript.matchAll(/elements\.([A-Za-z0-9_]+)/g)].map((match) => match[1]))
assert.deepEqual([...referencedIds].filter((id) => !ids.has(id)), [], 'JavaScript odkazuje na chybějící HTML id.')

assert.equal(manifest.start_url, '/warehouse-picking.html')
assert.equal(manifest.display, 'standalone')
assert.equal(manifest.orientation, 'portrait')
for (const icon of manifest.icons || []) {
  assert.equal(fs.existsSync(path.join(root, icon.src.replace(/^\//, ''))), true, `Chybí ikona ${icon.src}`)
}

const appShellMatch = serviceWorker.match(/const APP_SHELL = \[([\s\S]*?)\];/)
assert.ok(appShellMatch, 'V service workeru chybí APP_SHELL.')
const appShellFiles = [...appShellMatch[1].matchAll(/'\.\/([^'?]+)(?:\?[^']*)?'/g)].map((match) => match[1])
const missingAppShellFiles = appShellFiles.filter((file) => file && !fs.existsSync(path.join(root, file)))
assert.deepEqual(missingAppShellFiles, [], 'V APP_SHELL jsou neexistující soubory.')
for (const required of ['warehouse-picking.html', 'warehouse-picking.js', 'warehouse-picking-core.mjs', 'warehouse-picking.webmanifest']) {
  assert.ok(appShellFiles.includes(required), `${required} chybí v APP_SHELL.`)
}
assert.equal(supabaseJavascript.includes('https://esm.sh/@supabase'), false, 'Start nesmí záviset na externím esm.sh CDN.')
assert.equal(supabaseJavascript.includes('./vendor/supabase/supabase-js-2.118.0.bundle.mjs'), true)
assert.ok(appShellFiles.includes('vendor/supabase/supabase-js-2.118.0.bundle.mjs'), 'Lokální Supabase SDK chybí v APP_SHELL.')

assert.equal(javascript.includes("status: 'ready'"), true)
assert.equal(javascript.includes("from('stock_movements_v13')"), false)
assert.equal(javascript.includes("from('stock_location_balances').update"), false)
assert.equal(javascript.includes("from('stock_location_balances').insert"), false)
assert.equal(javascript.includes('olvendWarehousePickingSnapshotV1'), true)
assert.equal(javascript.includes('olvendWarehousePickingQueueV1'), true)
assert.equal(javascript.includes('async function syncQueue()'), true)
assert.equal(javascript.includes('syncOfflineRequests'), true)
assert.equal(javascript.includes("window.addEventListener('olvend-offline-queue'"), true)
assert.match(supabaseJavascript, /navigator\.onLine !== false[\s\S]*security_active_employee/)
assert.equal(html.includes('sb-rerjlkrhiytgscjerqgs-auth-token'), true)
assert.equal(html.includes('index.html?next=warehouse-picking.html'), true)
assert.equal(html.includes('window.__warehousePickingReady'), true)
assert.equal(html.includes('12000'), true)

console.log('warehouse-picking-pwa: OK')
