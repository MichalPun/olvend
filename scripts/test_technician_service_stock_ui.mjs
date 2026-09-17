import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright')
const html = readFileSync(new URL('../technician-mobile.html', import.meta.url), 'utf8')
  .replace("    import './pwa.js?v=20260917-technician-service-stock-v1'", '')
const mockSupabase = readFileSync(new URL('./fixtures/mock-supabase-technician.js', import.meta.url), 'utf8')

const browser = await chromium.launch({
  headless:true,
  executablePath:process.env.BROWSER_EXECUTABLE || '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge'
})

try {
  const page = await browser.newPage({ viewport:{ width:390, height:844 } })
  const errors = []
  page.on('pageerror', error => errors.push(error.message))
  await page.route('**/*', route => {
    const url = new URL(route.request().url())
    if (url.pathname === '/technician-mobile.html') return route.fulfill({ contentType:'text/html', body:html })
    if (url.pathname === '/supabase.js') return route.fulfill({ contentType:'text/javascript', body:mockSupabase })
    return route.fulfill({ status:404, body:'' })
  })

  await page.goto('https://technician.test/technician-mobile.html')
  await page.waitForTimeout(300)
  if (!await page.locator('[data-task="service_request:52"]').count()) {
    throw new Error(`Technician fixture did not render. UI: ${await page.locator('body').innerText()} · JS: ${errors.join(' | ')}`)
  }
  await page.locator('[data-task="service_request:52"]').first().click()
  await page.getByRole('button', { name:'Zahájit servis' }).click()
  await page.getByRole('button', { name:'+ Upravit zásobník' }).click()
  await page.waitForTimeout(100)

  const pickerCount = await page.locator('[data-select-container]').count()
  assert.equal(pickerCount, 2, `Picker contents: ${await page.locator('#containerSheet').innerText()} · Toast: ${await page.locator('#toast').innerText()}`)
  await page.locator('[data-select-container="501"]').click()
  assert.equal(await page.locator('[data-container-card]').count(), 1, 'Jen vybraný zásobník smí vstoupit do formuláře')
  assert.match(await page.locator('[data-container-card="501"]').innerText(), /Smetana/)
  assert.equal(await page.locator('[data-container-card="502"]').count(), 0, 'Nevybraná káva nesmí být součástí zásahu')

  await page.locator('[data-container-actual="501"]').fill('200')
  await page.locator('[data-container-added="501"]').fill('500')
  assert.match(await page.locator('[data-container-final="501"]').innerText(), /700 g/)
  await page.locator('#serviceWork').fill('Doplněna smetana a srovnán skutečný stav.')
  await page.getByRole('button', { name:'Uložit výsledek servisu' }).click()

  const calls = await page.evaluate(() => globalThis.__mockRpcCalls)
  const stockCall = calls.find(call => call.name === 'apply_technician_service_container_stock_v51')
  assert.ok(stockCall, 'Uložení servisu musí zavolat atomický skladový RPC')
  assert.deepEqual(stockCall.args.p_items, [{ container_id:501, actual_before_quantity:200, added_quantity:500 }])
  assert.equal(stockCall.args.p_vehicle_stock_location_id, 80)
  assert.deepEqual(errors, [])
  console.log('PASS: technician selects only one container, corrects it, refills from vehicle, and submits one atomic item')
} finally {
  await browser.close()
}
