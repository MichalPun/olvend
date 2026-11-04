import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright')
const html = readFileSync(new URL('../warehouse-picking.html', import.meta.url), 'utf8')
  .replace(/<script>\s*\(\(\) => \{[\s\S]*?<\/script>/, '')
  .replace(/<script src="pwa\.js[^>]*><\/script>/, '')
const javascript = readFileSync(new URL('../warehouse-picking.js', import.meta.url), 'utf8')
const core = readFileSync(new URL('../warehouse-picking-core.mjs', import.meta.url), 'utf8')
const mock = readFileSync(new URL('./fixtures/mock-supabase-warehouse-substitution.js', import.meta.url), 'utf8')

const browser = await chromium.launch({
  headless: true,
  executablePath: process.env.BROWSER_EXECUTABLE || '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge'
})

try {
  const context = await browser.newContext({ viewport: { width: 360, height: 640 } })
  const page = await context.newPage()
  const errors = []
  page.on('pageerror', (error) => errors.push(error.message))
  await page.route('**/*', (route) => {
    const url = new URL(route.request().url())
    if (url.pathname === '/warehouse-picking.html') return route.fulfill({ contentType: 'text/html', body: html })
    if (url.pathname === '/warehouse-picking.js') return route.fulfill({ contentType: 'text/javascript', body: javascript })
    if (url.pathname === '/warehouse-picking-core.mjs') return route.fulfill({ contentType: 'text/javascript', body: core })
    if (url.pathname === '/supabase-zebra.js') return route.fulfill({ contentType: 'text/javascript', body: mock })
    return route.fulfill({ status: 404, body: '' })
  })

  await page.goto('https://warehouse.test/warehouse-picking.html')
  await page.locator('[data-request-id="700"]').click()
  assert.match(await page.locator('#warehouseStock').innerText(), /^0 /)
  await page.locator('#substituteItemBtn').click()
  await page.locator('[data-substitute-id="99"]').click()
  assert.equal(await page.locator('#productName').innerText(), 'Nestea Peach 0,5l')
  assert.match(await page.locator('#substituteNoticeText').innerText(), /Místo Nestea Lemon 0,5l vydáš Nestea Peach 0,5l/)
  assert.equal(await page.locator('#quantityInput').inputValue(), '12')

  await context.setOffline(true)
  await page.locator('#readyItemBtn').click()
  const queue = await page.evaluate(() => JSON.parse(localStorage.getItem('olvendWarehousePickingQueueV1') || '[]'))
  assert.equal(queue.length, 1)
  assert.equal(queue[0].rowId, 701)
  assert.equal(queue[0].payload.prepared_product_id, 99)
  assert.equal(queue[0].payload.prepared_product_name, 'Nestea Peach 0,5l')
  assert.equal(queue[0].payload.prepared_unit, 'ks')
  assert.equal(queue[0].payload.prepared_quantity, 12)
  assert.equal(errors.length, 0, errors.join(' | '))
  console.log('warehouse-picking-substitution-ui: OK')
} finally {
  await browser.close()
}
