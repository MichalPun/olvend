import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const ALLOWED_DEVICES = new Set(['635456', '635457', '635458'])

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8' }
  })
}

function text(value: unknown) {
  return String(value ?? '').trim()
}

function normalizeSelection(value: unknown) {
  const raw = text(value).replace(/\.0$/, '')
  if (!/^\d+$/.test(raw)) return raw
  const numeric = Number(raw)
  return numeric >= 32768 && numeric <= 65535 ? String(numeric - 32768) : raw
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'Method not allowed.' }, 405)
  const expectedToken = Deno.env.get('TELEMETRY_INGEST_TOKEN')?.trim()
  const providedToken = req.headers.get('x-olvend-telemetry-token') || ''
  if (expectedToken && providedToken !== expectedToken) return json({ error: 'Unauthorized.' }, 401)

  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!supabaseUrl || !serviceRoleKey) return json({ error: 'Missing Supabase environment.' }, 500)
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false }
  })

  const body = await req.json().catch(() => ({})) as { rows?: Record<string, unknown>[] }
  if (!Array.isArray(body.rows)) return json({ error: 'rows must be an array.' }, 400)
  if (body.rows.length > 500) return json({ error: 'Too many rows.' }, 413)

  const counts: Record<string, number> = {}
  const problems: Record<string, unknown>[] = []
  let accepted = 0
  for (const row of body.rows) {
    const transactionId = text(row.transactionId)
    const deviceUid = text(row.deviceUid)
    const selection = normalizeSelection(row.selection)
    const occurredAt = text(row.occurredAt)
    if (!transactionId || !ALLOWED_DEVICES.has(deviceUid) || !selection || !occurredAt) {
      counts.invalid = (counts.invalid || 0) + 1
      continue
    }
    const { data, error } = await admin.rpc('apply_ima_a5_sale', {
      p_event_key: `${deviceUid}:${transactionId}`,
      p_transaction_id: transactionId,
      p_device_uid: deviceUid,
      p_device_acronym: text(row.deviceAcronym) || deviceUid,
      p_selection_code: selection,
      p_product_name: text(row.productName) || null,
      p_quantity: Number(row.quantity || 1),
      p_unit_price_czk: row.unitPrice == null ? null : Number(row.unitPrice),
      p_payment_method: text(row.paymentMethod) || null,
      p_source_event_at: occurredAt
    })
    if (error) return json({ error: error.message, accepted, counts }, 500)
    if (text(row.paymentMethod)) {
      const { error: paymentError } = await admin.rpc('apply_ima_a5_payment_method', {
        p_event_key: `${deviceUid}:${transactionId}`,
        p_payment_method: text(row.paymentMethod)
      })
      if (paymentError) return json({ error: paymentError.message, accepted, counts }, 500)
    }
    const status = text(data?.status) || 'unknown'
    counts[status] = (counts[status] || 0) + 1
    accepted += 1
    if (['unmatched_machine', 'unmatched_slot', 'ignored_device', 'unknown'].includes(status)) {
      problems.push({ transactionId, deviceUid, selection, status })
    }
  }

  return json({ ok: problems.length === 0, received: body.rows.length, accepted, counts, problems }, problems.length ? 409 : 200)
})
