import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { PDFDocument, rgb } from 'https://esm.sh/pdf-lib@1.17.1'
import fontkit from 'https://esm.sh/@pdf-lib/fontkit@1.1.1'
import { aggregateProductRows, periodFromMonth, previousMonthPeriod, reportGroups, reportTotals, zonedMidnightUtc } from './report-core.mjs'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-olvend-cron-token',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const json = (data: unknown, status = 200) => new Response(JSON.stringify(data), {
  status,
  headers: { ...CORS, 'Content-Type': 'application/json' },
})
const money = (value: unknown) => `${Number(value || 0).toLocaleString('cs-CZ', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} Kč`
const qty = (value: unknown) => Number(value || 0).toLocaleString('cs-CZ', { maximumFractionDigits: 3 })
const bytesToBase64 = (bytes: Uint8Array) => {
  let binary = ''
  for (let offset = 0; offset < bytes.length; offset += 0x8000) binary += String.fromCharCode(...bytes.subarray(offset, offset + 0x8000))
  return btoa(binary)
}

async function fetchPaged(buildQuery: (from: number, to: number) => PromiseLike<{ data: unknown[] | null; error: { message?: string } | null }>) {
  const output: unknown[] = []
  const pageSize = 1000
  for (let from = 0; from < 100000; from += pageSize) {
    const { data, error } = await buildQuery(from, from + pageSize - 1)
    if (error) throw new Error(error.message || 'Načtení telemetrie selhalo.')
    output.push(...(data || []))
    if (!data || data.length < pageSize) break
  }
  return output
}

async function authorize(req: Request, admin: ReturnType<typeof createClient>) {
  const expected = Deno.env.get('MONTHLY_ACCOUNTING_REPORT_CRON_TOKEN') || ''
  const provided = req.headers.get('x-olvend-cron-token') || ''
  if (expected && provided && provided === expected) return true
  const token = (req.headers.get('authorization') || '').replace(/^Bearer\s+/i, '').trim()
  if (!token) return false
  const { data: userData } = await admin.auth.getUser(token)
  if (!userData.user) return false
  const { data: employee } = await admin.from('employees').select('role,active').eq('auth_user_id', userData.user.id).maybeSingle()
  return employee?.active !== false && ['admin', 'manager'].includes(String(employee?.role || '').toLowerCase())
}

async function loadFonts(appUrl: string) {
  const [regularResponse, boldResponse] = await Promise.all([
    fetch(`${appUrl}/assets/fonts/Aptos-Narrow.ttf`),
    fetch(`${appUrl}/assets/fonts/Aptos-Narrow-Bold.ttf`),
  ])
  if (!regularResponse.ok || !boldResponse.ok) throw new Error('Nepodařilo se načíst písmo pro PDF.')
  return {
    regular: new Uint8Array(await regularResponse.arrayBuffer()),
    bold: new Uint8Array(await boldResponse.arrayBuffer()),
  }
}

async function buildPdf(rows: Record<string, unknown>[], period: { label: string }, appUrl: string) {
  const doc = await PDFDocument.create()
  doc.registerFontkit(fontkit)
  const fontBytes = await loadFonts(appUrl)
  const regular = await doc.embedFont(fontBytes.regular, { subset: true })
  const bold = await doc.embedFont(fontBytes.bold, { subset: true })
  const groups = reportGroups(rows)
  const totals = reportTotals(rows)
  const size: [number, number] = [841.89, 595.28]
  const dark = rgb(23 / 255, 33 / 255, 43 / 255)
  const muted = rgb(95 / 255, 107 / 255, 124 / 255)
  const red = rgb(213 / 255, 16 / 255, 26 / 255)
  const pale = rgb(246 / 255, 248 / 255, 250 / 255)
  const line = rgb(220 / 255, 226 / 255, 232 / 255)
  const bluePale = rgb(238 / 255, 246 / 255, 1)
  const pages: ReturnType<typeof doc.addPage>[] = []

  const addPage = (section = 'ÚČETNÍ PODKLAD') => {
    const page = doc.addPage(size)
    pages.push(page)
    page.drawRectangle({ x: 0, y: size[1] - 40, width: size[0], height: 40, color: dark })
    page.drawText('OLVEND', { x: 34, y: size[1] - 27, size: 15, font: bold, color: rgb(1, 1, 1) })
    page.drawText(section, { x: size[0] - regular.widthOfTextAtSize(section, 10) - 34, y: size[1] - 26, size: 10, font: regular, color: rgb(1, 1, 1) })
    return page
  }
  const text = (page, value, x, y, options: Record<string, unknown> = {}) => page.drawText(String(value ?? ''), { x, y, size: 10, font: regular, color: dark, ...options })
  const rightText = (page, value, right, y, options: Record<string, unknown> = {}) => {
    const selectedFont = options.font || regular
    const selectedSize = Number(options.size || 9)
    text(page, value, right - selectedFont.widthOfTextAtSize(String(value), selectedSize), y, { ...options, font: selectedFont, size: selectedSize })
  }
  const clip = (value, maxWidth, selectedFont = regular, fontSize = 9) => {
    let output = String(value ?? '')
    while (output.length > 1 && selectedFont.widthOfTextAtSize(output, fontSize) > maxWidth) output = `${output.slice(0, -2)}…`
    return output
  }
  const tableRow = (page, values, widths, y, header = false, total = false) => {
    let x = 34
    page.drawRectangle({ x, y: y - 4, width: widths.reduce((sum, width) => sum + width, 0), height: 22, color: header ? red : total ? bluePale : pale, borderColor: header ? red : line, borderWidth: 0.5 })
    values.forEach((value, index) => {
      const rowFont = header || total ? bold : regular
      const fontSize = header ? 8 : 8.5
      const valueText = clip(value, widths[index] - 10, rowFont, fontSize)
      const options = { font: rowFont, size: fontSize, color: header ? rgb(1, 1, 1) : dark }
      if (index > 0) rightText(page, valueText, x + widths[index] - 5, y + 3, options)
      else text(page, valueText, x + 5, y + 3, options)
      x += widths[index]
    })
  }

  const cover = addPage()
  text(cover, 'Prodej podle produktů', 34, 514, { size: 24, font: bold })
  text(cover, `Uzavřený měsíc: ${period.label} · Tržby včetně DPH`, 34, 493, { size: 11, color: muted })
  const cards = [
    ['POLOŽKY', rows.length.toLocaleString('cs-CZ')], ['VÝDEJE', `${qty(totals.quantity)} ks`], ['TRŽBA S DPH', money(totals.revenue)],
    ['HOTOVĚ', money(totals.cash)], ['KARTOU', money(totals.cashless)],
  ]
  cards.forEach(([label, value], index) => {
    const x = 34 + index * 155
    cover.drawRectangle({ x, y: 430, width: 147, height: 48, color: pale, borderColor: line, borderWidth: 0.6 })
    text(cover, label, x + 9, 462, { size: 8, color: muted, font: bold })
    text(cover, value, x + 9, 440, { size: 13, font: bold })
  })
  const paymentTotal = totals.cash + totals.cashless + totals.unknown
  const difference = totals.revenue - paymentTotal
  cover.drawRectangle({ x: 34, y: 395, width: 767, height: 25, color: Math.abs(difference) < 0.01 ? rgb(236 / 255, 253 / 255, 245 / 255) : rgb(1, 247 / 255, 237 / 255) })
  text(cover, `Kontrola plateb: hotově ${money(totals.cash)} + kartou ${money(totals.cashless)} + neurčeno ${money(totals.unknown)} = ${money(paymentTotal)} · rozdíl ${money(difference)}`, 43, 404, { size: 9, font: bold })
  text(cover, 'Souhrn podle skupin', 34, 367, { size: 15, font: bold })
  const summaryWidths = [225, 70, 95, 115, 95, 95, 72]
  tableRow(cover, ['Skupina', 'Položek', 'Výdeje', 'Tržba s DPH', 'Hotově', 'Kartou', 'Podíl'], summaryWidths, 337, true)
  let summaryY = 315
  groups.forEach((group) => {
    tableRow(cover, [group.label, group.rows.length, qty(group.totals.quantity), money(group.totals.revenue), money(group.totals.cash), money(group.totals.cashless), totals.revenue ? `${(group.totals.revenue / totals.revenue * 100).toFixed(1).replace('.', ',')} %` : '0,0 %'], summaryWidths, summaryY)
    summaryY -= 22
  })
  tableRow(cover, ['CELKEM', rows.length, qty(totals.quantity), money(totals.revenue), money(totals.cash), money(totals.cashless), '100,0 %'], summaryWidths, summaryY, false, true)

  const detailWidths = [70, 292, 85, 105, 90, 90]
  groups.forEach((group) => {
    const chunks = []
    for (let index = 0; index < group.rows.length; index += 20) chunks.push(group.rows.slice(index, index + 20))
    if (!chunks.length) chunks.push([])
    chunks.forEach((chunk, chunkIndex) => {
      const page = addPage('DETAIL PRODUKTŮ')
      text(page, group.label, 34, 514, { size: 20, font: bold })
      text(page, `${group.rows.length.toLocaleString('cs-CZ')} položek · ${qty(group.totals.quantity)} ks · tržba ${money(group.totals.revenue)}${chunks.length > 1 ? ` · část ${chunkIndex + 1}/${chunks.length}` : ''}`, 34, 493, { size: 10, color: muted })
      tableRow(page, ['SKU', 'Produkt', 'Výdeje', 'Tržba s DPH', 'Hotově', 'Kartou'], detailWidths, 460, true)
      let y = 438
      chunk.forEach((row) => {
        tableRow(page, [row.sku || '', row.label, qty(row.quantity), money(row.revenue), money(row.cash), money(row.cashless)], detailWidths, y)
        y -= 22
      })
      if (chunkIndex === chunks.length - 1) tableRow(page, ['', `Mezisoučet · ${group.label}`, qty(group.totals.quantity), money(group.totals.revenue), money(group.totals.cash), money(group.totals.cashless)], detailWidths, y, false, true)
    })
  })
  pages.forEach((page, index) => {
    text(page, 'OLVEND · Účetní podklad · Tržby včetně DPH', 34, 18, { size: 8, color: muted })
    rightText(page, `Strana ${index + 1} z ${pages.length}`, size[0] - 34, 18, { size: 8, color: muted })
  })
  return new Uint8Array(await doc.save())
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  if (req.method !== 'POST') return json({ error: 'Method not allowed.' }, 405)
  const supabaseUrl = Deno.env.get('SUPABASE_URL') || ''
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''
  const resendKey = Deno.env.get('RESEND_API_KEY') || ''
  const emailFrom = Deno.env.get('EMAIL_FROM') || ''
  if (!supabaseUrl || !serviceRoleKey || !resendKey || !emailFrom) return json({ error: 'Chybí serverová konfigurace.' }, 500)
  const admin = createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false, autoRefreshToken: false } })
  if (!await authorize(req, admin)) return json({ error: 'Unauthorized.' }, 401)
  let runId: number | null = null
  try {
    const payload = await req.json().catch(() => ({}))
    const automatic = !payload?.period
    const dryRun = payload?.dry_run === true
    const period = automatic ? previousMonthPeriod() : periodFromMonth(payload.period)
    const { data: settings, error: settingsError } = await admin.from('accounting_report_settings').select('*').eq('id', 1).single()
    if (settingsError) throw new Error(settingsError.message)
    if (automatic && !settings.enabled) return json({ ok: true, skipped: 'disabled' })
    const { data: payroll } = await admin.from('payroll_settings').select('accountant_email').eq('id', 1).maybeSingle()
    const recipient = String(settings.recipient_email || payroll?.accountant_email || '').trim()
    const cc = String(settings.cc_email || '').trim()
    if (!recipient.includes('@')) throw new Error('V nastavení chybí platný e-mail účetní.')
    if (!dryRun) {
      const { data: existing } = await admin.from('accounting_report_runs').select('id,status,sent_at').eq('period_month', period.period).maybeSingle()
      if (existing?.status === 'sent' && !payload?.force) return json({ ok: true, already_sent: true, period: period.period, sent_at: existing.sent_at })
      const { data: run, error: runError } = await admin.from('accounting_report_runs').upsert({ period_month: period.period, recipient_email: recipient, cc_email: cc || null, status: 'processing', error_message: null, started_at: new Date().toISOString() }, { onConflict: 'period_month' }).select('id').single()
      if (runError) throw new Error(runError.message)
      runId = Number(run.id)
    }
    const fromIso = zonedMidnightUtc(period.period)
    const toIso = zonedMidnightUtc(period.nextPeriod)
    const salesRows = await fetchPaged((from, to) => admin.from('telemetry_sales_events')
      .select('id,provider,machine_id,selection_code,product_name,product_sku,quantity,total_amount_czk,cash_amount_czk,cashless_amount_czk,unknown_payment_amount_czk,source_event_at')
      .gte('source_event_at', fromIso).lt('source_event_at', toIso).order('source_event_at', { ascending: false }).order('id', { ascending: false }).range(from, to))
    const { data: products, error: productsError } = await admin.from('products').select('sku,name,product_category,usage_type,note,active')
    if (productsError) throw new Error(productsError.message)
    const aggregateRows = aggregateProductRows(salesRows, products || [])
    const appUrl = String(Deno.env.get('OLVEND_APP_URL') || 'https://olvend.onrender.com').replace(/\/$/, '')
    const pdf = await buildPdf(aggregateRows, period, appUrl)
    const totals = reportTotals(aggregateRows)
    if (dryRun) return json({
      ok: true,
      dry_run: true,
      recipient,
      cc: cc || null,
      period: period.period,
      rows: aggregateRows.length,
      revenue: totals.revenue,
      pdf_bytes: pdf.length,
      pdf_base64: payload?.return_pdf === true ? bytesToBase64(pdf) : undefined,
    })
    const mailPayload: Record<string, unknown> = {
      from: emailFrom, to: [recipient], subject: `OLVEND: Prodej podle produktů za ${period.label}`,
      html: `<p>Dobrý den,</p><p>v příloze zasíláme automaticky vytvořený účetní přehled prodejů podle produktů za <strong>${period.label}</strong>.</p><p>Tržba včetně DPH: <strong>${money(totals.revenue)}</strong><br>Výdeje: <strong>${qty(totals.quantity)} ks</strong></p><p>S pozdravem<br>OLVEND</p>`,
      attachments: [{ filename: `OLVEND-prodej-podle-produktu-${period.period.slice(0, 7)}.pdf`, content: bytesToBase64(pdf) }],
    }
    if (cc) mailPayload.cc = [cc]
    const response = await fetch('https://api.resend.com/emails', { method: 'POST', headers: { Authorization: `Bearer ${resendKey}`, 'Content-Type': 'application/json', 'Idempotency-Key': `monthly-accounting-product-report-${period.period}` }, body: JSON.stringify(mailPayload) })
    const result = await response.json().catch(async () => ({ error: await response.text() }))
    if (!response.ok) throw new Error(String(result?.message || result?.error || 'E-mailová služba zprávu odmítla.'))
    await admin.from('accounting_report_runs').update({ status: 'sent', provider_id: result?.id || null, sent_at: new Date().toISOString(), row_count: aggregateRows.length, total_revenue_czk: totals.revenue, error_message: null }).eq('id', runId)
    return json({ ok: true, sent: true, recipient, cc: cc || null, period: period.period, rows: aggregateRows.length, revenue: totals.revenue })
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Neznámá chyba.'
    if (runId) await admin.from('accounting_report_runs').update({ status: 'failed', error_message: message }).eq('id', runId)
    return json({ error: message }, 500)
  }
})
