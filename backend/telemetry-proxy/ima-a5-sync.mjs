import { existsSync } from 'node:fs'
import { chromium } from 'playwright-chromium'

const DEFAULT_REPORT_URL = 'https://gpe.vending.ima.cz/Data/Reports'
const DEFAULT_INGEST_URL = 'https://rerjlkrhiytgscjerqgs.supabase.co/functions/v1/ima-a5-ingest'
const DEFAULT_DEVICE_UIDS = ['635456', '635457', '635458']

export function normalizeSelection(value) {
  const raw = String(value ?? '').trim().replace(/\.0$/, '')
  if (!/^\d+$/.test(raw)) return raw
  const numeric = Number(raw)
  return numeric >= 32768 && numeric <= 65535 ? String(numeric - 32768) : raw
}

export function parseCzechMoney(value) {
  const normalized = String(value ?? '')
    .trim()
    .replace(/\s/g, '')
    .replace(',', '.')
  if (!normalized) return null
  const parsed = Number(normalized)
  return Number.isFinite(parsed) ? parsed : null
}

export function pragueIso(value) {
  const raw = String(value ?? '').trim()
  const match = raw.match(/^(\d{1,2})[.\/-](\d{1,2})[.\/-](\d{4})[ ,T]+(\d{1,2}):(\d{2})(?::(\d{2}))?$/)
  if (!match) {
    const parsed = new Date(raw)
    return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString()
  }
  const [, day, month, year, hour, minute, second = '0'] = match
  const wallClock = Date.UTC(Number(year), Number(month) - 1, Number(day), Number(hour), Number(minute), Number(second))
  const noonUtc = new Date(Date.UTC(Number(year), Number(month) - 1, Number(day), 12))
  const parts = Object.fromEntries(new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Prague', year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23'
  }).formatToParts(noonUtc).map((part) => [part.type, part.value]))
  const representedNoon = Date.UTC(Number(parts.year), Number(parts.month) - 1, Number(parts.day), Number(parts.hour), Number(parts.minute), Number(parts.second))
  return new Date(wallClock - (representedNoon - noonUtc.getTime())).toISOString()
}

export function sanitizeRows(rows, allowedDevices = DEFAULT_DEVICE_UIDS) {
  const allowed = new Set(allowedDevices.map(String))
  const safe = []
  const seen = new Set()
  for (const row of rows || []) {
    const deviceUid = String(row.deviceUid ?? '').trim()
    const transactionId = String(row.transactionId ?? '').trim()
    const occurredAt = pragueIso(row.occurredAt)
    const selection = normalizeSelection(row.selection)
    if (!allowed.has(deviceUid) || !transactionId || !occurredAt || !selection) continue
    const eventKey = `${deviceUid}:${transactionId}`
    if (seen.has(eventKey)) continue
    seen.add(eventKey)
    safe.push({
      transactionId,
      occurredAt,
      deviceUid,
      deviceAcronym: String(row.deviceAcronym || deviceUid).trim(),
      selection,
      unitPrice: parseCzechMoney(row.unitPrice),
      quantity: 1,
      productName: String(row.productName || '').trim(),
      paymentMethod: String(row.paymentMethod || '').trim().toLowerCase()
    })
  }
  return safe
}

async function ensurePaymentTypeColumn(page) {
  const dataButton = page.getByRole('button', { name: 'Data', exact: true })
  await dataButton.click()
  const label = page.getByText('EMV – typ karty', { exact: true })
  await label.waitFor({ state: 'visible', timeout: 10_000 })
  const checkbox = label.locator('..').getByRole('checkbox')
  if (!(await checkbox.isChecked())) await checkbox.click()
  await dataButton.press('Enter')
  await page.waitForTimeout(250)
}

export function rowsMatchDevice(rows, expectedDeviceUid) {
  const expected = String(expectedDeviceUid ?? '').trim()
  return (rows || []).every((row) => String(row?.deviceUid ?? '').trim() === expected)
}

async function armReportTableRefreshWatch(page) {
  await page.evaluate(() => {
    window.__olvendReportRefreshWatch?.observer?.disconnect?.()
    const tables = Array.from(document.querySelectorAll('table'))
    const table = tables.find((candidate) => Array.from(candidate.querySelectorAll('th'))
      .some((header) => header.textContent?.includes('ID trn.')))
    const root = table?.parentElement || document.querySelector('main') || document.body
    const state = {
      startedAt: Date.now(),
      mutationCount: 0,
      lastMutationAt: 0,
      observer: null
    }
    state.observer = new MutationObserver(() => {
      state.mutationCount += 1
      state.lastMutationAt = Date.now()
    })
    state.observer.observe(root, {
      subtree: true,
      childList: true,
      characterData: true,
      attributes: true
    })
    window.__olvendReportRefreshWatch = state
  })
}

async function waitForReportTableRefresh(page, expectedDeviceUid) {
  try {
    await page.waitForFunction((uid) => {
      const watch = window.__olvendReportRefreshWatch
      if (!watch || watch.mutationCount < 1) return false
      if (Date.now() - watch.startedAt < 750 || Date.now() - watch.lastMutationAt < 750) return false

      const tables = Array.from(document.querySelectorAll('table'))
      const table = tables.find((candidate) => Array.from(candidate.querySelectorAll('th'))
        .some((header) => header.textContent?.includes('ID trn.')))
      if (!table) return false
      const transactionRows = Array.from(table.querySelectorAll('tbody tr')).filter((row) => {
        const transactionId = row.querySelectorAll('td')[0]?.textContent?.trim() || ''
        return /^\d+$/.test(transactionId)
      })
      return transactionRows.every((row) => row.querySelectorAll('td')[2]?.textContent?.trim() === uid)
    }, String(expectedDeviceUid), { timeout: 20_000, polling: 250 })
    return true
  } catch {
    return false
  } finally {
    await page.evaluate(() => {
      window.__olvendReportRefreshWatch?.observer?.disconnect?.()
    })
  }
}

async function readReportTableRows(page) {
  return page.evaluate(() => {
    const tables = Array.from(document.querySelectorAll('table'))
    const table = tables.find((candidate) => Array.from(candidate.querySelectorAll('th'))
      .some((header) => header.textContent?.includes('ID trn.')))
    if (!table) return { rows: [], paymentColumnFound: false }
    const headers = Array.from(table.querySelectorAll('th')).map((header) => header.textContent?.trim() || '')
    const paymentColumnIndex = headers.findIndex((header) => header.includes('EMV – typ karty'))
    const rows = Array.from(table.querySelectorAll('tbody tr')).flatMap((row) => {
      const cells = row.querySelectorAll('td')
      const transactionId = cells[0]?.textContent?.trim() || ''
      if (!/^\d+$/.test(transactionId)) return []
      const emvCardType = paymentColumnIndex >= 0
        ? cells[paymentColumnIndex]?.textContent?.trim() || ''
        : ''
      // Deliberately read only the safe columns. Card and personal columns are never accessed.
      return [{
        transactionId,
        occurredAt: cells[1]?.textContent?.trim() || '',
        deviceUid: cells[2]?.textContent?.trim() || '',
        deviceAcronym: cells[3]?.textContent?.trim() || '',
        selection: cells[6]?.textContent?.trim() || '',
        unitPrice: cells[8]?.textContent?.trim() || '',
        quantity: 1,
        productName: cells[11]?.textContent?.trim() || '',
        paymentMethod: emvCardType ? 'card' : 'cash'
      }]
    })
    return { rows, paymentColumnFound: paymentColumnIndex >= 0 }
  })
}

async function loginIfNeeded(page, { username, password }, reportUrl) {
  if (!page.url().includes('/Account/Login')) return false
  const reportHost = new URL(reportUrl).host

  // The GPE login page also exposes a legacy local form. OLVEND's account is
  // an A5Central account, so follow the SSO button before entering credentials.
  if (new URL(page.url()).host === reportHost) {
    const centralLogin = page.getByRole('button', { name: 'Přihlášení A5Central', exact: true })
    if (await centralLogin.isVisible()) {
      await Promise.all([
        page.waitForURL((url) => url.host !== reportHost && url.pathname.includes('/Account/Login'), { timeout: 30_000 }),
        centralLogin.click()
      ])
    }
  }

  await page.getByRole('textbox', { name: 'Uživatelské jméno', exact: true }).fill(username)
  await page.getByLabel('Heslo', { exact: true }).fill(password)
  await Promise.all([
    page.waitForURL((url) => {
      const path = url.pathname.toLowerCase()
      return url.host === reportHost &&
        !path.includes('/account/login') &&
        !path.includes('/a5central/signin-oidc')
    }, { timeout: 60_000 }),
    page.getByRole('button', { name: 'Přihlásit', exact: true }).click()
  ])
  await page.waitForLoadState('domcontentloaded')
  return true
}

async function readDeviceRows(page, reportUrl, uid, credentials) {
  const navigationTrail = []
  page.on('framenavigated', (frame) => {
    if (frame !== page.mainFrame()) return
    try {
      const url = new URL(frame.url())
      const safeLocation = `${url.origin}${url.pathname}`
      if (navigationTrail.at(-1) !== safeLocation) navigationTrail.push(safeLocation)
      if (navigationTrail.length > 12) navigationTrail.shift()
    } catch {}
  })
  await page.goto(reportUrl, { waitUntil: 'domcontentloaded', timeout: 30_000 })

  // The Blazor shell answers with /Data/Reports first and performs the auth
  // redirect client-side a moment later. Wait for the real page state before
  // deciding whether credentials are needed.
  await Promise.race([
    page.waitForURL((url) => url.pathname.includes('/Account/Login'), { timeout: 30_000 }).catch(() => null),
    page.getByRole('textbox', { name: 'Zařízení', exact: true })
      .waitFor({ state: 'visible', timeout: 30_000 }).catch(() => null)
  ])
  const loggedIn = await loginIfNeeded(page, credentials, reportUrl)
  if (page.url().includes('/Account/Login')) throw new Error('IMA_LOGIN_FAILED')

  // A successful login can finish on the A5 home page instead of honoring the
  // original return URL. Re-open the report with the authenticated session.
  if (loggedIn || !page.url().includes('/Data/Reports')) {
    await page.goto(reportUrl, { waitUntil: 'domcontentloaded', timeout: 30_000 })
  }
  if (page.url().includes('/Account/Login')) throw new Error('IMA_LOGIN_FAILED')
  try {
    await page.getByRole('textbox', { name: 'Zařízení', exact: true })
      .waitFor({ state: 'visible', timeout: 30_000 })
  } catch {
    throw new Error(`IMA_REPORT_NOT_READY: ${navigationTrail.join(' -> ')}`)
  }

  // The default "Dnes" report is the live transaction view. A5Web's
  // "Poslední 3 dny" aggregate can lag the live view by hours, so using it
  // for a five-minute synchronizer silently omits the newest sales.
  await page.getByText('Dnes', { exact: true }).waitFor({ state: 'visible', timeout: 10_000 })
  await ensurePaymentTypeColumn(page)
  const deviceFilter = page.getByRole('textbox', { name: 'Zařízení', exact: true })
  await deviceFilter.click()
  await page.getByText(`[${uid}] OLMIKA s.r.o.`, { exact: true }).click()
  await deviceFilter.press('Escape')
  await page.getByRole('button', { name: 'Filtr', exact: true }).click()
  // MudBlazor keeps the off-canvas filter controls technically visible in
  // the accessibility tree after closing the drawer, so wait only for the
  // closing animation to settle before watching the report table itself.
  await page.waitForTimeout(500)

  // Arm the observer only after the filter drawer has closed. Otherwise its
  // own DOM animation looks like a successful table refresh and stale rows
  // can be accepted. A5Web also ignores an ordinary pointer click on the
  // floating refresh action in some Chromium sessions; keyboard activation
  // reliably triggers the same action as a manual Enter press.
  await armReportTableRefreshWatch(page)
  await page.getByRole('button', { name: 'Obnovit', exact: true }).press('Enter')

  const exportButton = page.getByRole('button', { name: 'Export', exact: true })
  await exportButton.waitFor({ state: 'visible', timeout: 20_000 })
  const observedRefresh = await waitForReportTableRefresh(page, uid)
  if (!observedRefresh) throw new Error(`IMA_REPORT_REFRESH_NOT_OBSERVED_${uid}`)
  const report = await readReportTableRows(page)
  if (!report.paymentColumnFound) throw new Error(`IMA_REPORT_PAYMENT_COLUMN_MISSING_${uid}`)
  const rows = report.rows
  if (!rowsMatchDevice(rows, uid)) throw new Error(`IMA_REPORT_DEVICE_MISMATCH_${uid}`)
  return { rows, observedRefresh }
}

async function postRows(ingestUrl, ingestToken, rows) {
  const response = await fetch(ingestUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-olvend-telemetry-token': ingestToken
    },
    body: JSON.stringify({ rows })
  })
  const body = await response.json().catch(() => ({}))
  if (!response.ok) throw new Error(`IMA_INGEST_FAILED_${response.status}: ${body.error || 'unknown error'}`)
  return body
}

export function createImaA5Synchronizer(env = process.env) {
  const enabled = String(env.IMA_A5_SYNC_ENABLED || 'false').toLowerCase() === 'true'
  const username = String(env.IMA_A5_USERNAME || '').trim()
  const password = String(env.IMA_A5_PASSWORD || '')
  const ingestToken = String(env.TELEMETRY_INGEST_TOKEN || '')
  const reportUrl = String(env.IMA_A5_REPORT_URL || DEFAULT_REPORT_URL)
  const ingestUrl = String(env.IMA_A5_INGEST_URL || DEFAULT_INGEST_URL)
  const deviceUids = String(env.IMA_A5_DEVICE_UIDS || DEFAULT_DEVICE_UIDS.join(','))
    .split(',').map((value) => value.trim()).filter(Boolean)
  const intervalMs = Math.max(300_000, Number(env.IMA_A5_SYNC_INTERVAL_MS || 300_000))
  const chromiumPath = String(env.CHROMIUM_PATH || '').trim()
  let browser
  let context
  let running = false
  let timer
  const state = {
    enabled,
    running: false,
    lastAttemptAt: null,
    lastSuccessAt: null,
    lastError: null,
    lastRowsRead: 0,
    lastIngest: null,
    lastDeviceReads: null
  }

  async function ensureContext() {
    if (context) return context
    const launchOptions = {
      headless: true,
      args: ['--no-sandbox', '--disable-dev-shm-usage']
    }
    if (chromiumPath && existsSync(chromiumPath)) launchOptions.executablePath = chromiumPath
    browser = await chromium.launch(launchOptions)
    context = await browser.newContext({ locale: 'cs-CZ', timezoneId: 'Europe/Prague' })
    return context
  }

  async function run() {
    if (!enabled || running) return { skipped: true, reason: enabled ? 'already_running' : 'disabled' }
    if (!username || !password || !ingestToken) throw new Error('IMA_A5_SYNC_MISSING_SECRETS')
    running = true
    state.running = true
    state.lastAttemptAt = new Date().toISOString()
    try {
      const activeContext = await ensureContext()
      const rows = []
      const deviceReads = {}
      for (const uid of deviceUids) {
        const page = await activeContext.newPage()
        try {
          const result = await readDeviceRows(page, reportUrl, uid, { username, password })
          rows.push(...result.rows)
          deviceReads[uid] = {
            rows: result.rows.length,
            observedRefresh: result.observedRefresh,
            newestOccurredAt: result.rows[0]?.occurredAt || null
          }
        } finally {
          await page.close()
        }
      }
      const safeRows = sanitizeRows(rows, deviceUids)
      const ingest = await postRows(ingestUrl, ingestToken, safeRows)
      state.lastSuccessAt = new Date().toISOString()
      state.lastError = null
      state.lastRowsRead = safeRows.length
      state.lastIngest = ingest
      state.lastDeviceReads = deviceReads
      return { ok: true, rows: safeRows.length, ingest }
    } catch (error) {
      state.lastError = error instanceof Error ? error.message : String(error)
      if (context) await context.close().catch(() => {})
      if (browser) await browser.close().catch(() => {})
      context = undefined
      browser = undefined
      throw error
    } finally {
      running = false
      state.running = false
    }
  }

  function start() {
    if (!enabled || timer) return
    timer = setInterval(() => run().catch((error) => console.error(`IMA A5 sync failed: ${error.message}`)), intervalMs)
    setTimeout(() => run().catch((error) => console.error(`IMA A5 initial sync failed: ${error.message}`)), 10_000)
  }

  async function stop() {
    if (timer) clearInterval(timer)
    timer = undefined
    if (context) await context.close().catch(() => {})
    if (browser) await browser.close().catch(() => {})
    context = undefined
    browser = undefined
  }

  return { enabled, run, start, stop, state: () => ({ ...state, deviceUids, intervalMs }) }
}
