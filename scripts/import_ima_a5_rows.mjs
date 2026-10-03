#!/usr/bin/env node
import fs from 'node:fs'
import path from 'node:path'

const ALLOWED_DEVICES = new Set(['635456', '635457', '635458'])
const inputPath = process.argv[2]
const outputPath = process.argv[3] || '/private/tmp/ima_a5_import.sql'

if (!inputPath) {
  console.error('Použití: node scripts/import_ima_a5_rows.mjs <rows.json> [vystup.sql]')
  process.exit(2)
}

const text = (value) => String(value ?? '').trim()
const sqlText = (value) => value == null || text(value) === ''
  ? 'null'
  : `'${text(value).replaceAll("'", "''")}'`
const sqlNumber = (value) => Number.isFinite(Number(value)) ? String(Number(value)) : 'null'

function normalizeSelection(value) {
  const raw = text(value).replace(/\.0$/, '')
  if (!/^\d+$/.test(raw)) return raw
  const numeric = Number(raw)
  return numeric >= 32768 && numeric <= 65535 ? String(numeric - 32768) : raw
}

function pragueIso(value) {
  const raw = text(value)
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

const rows = JSON.parse(fs.readFileSync(path.resolve(inputPath), 'utf8'))
if (!Array.isArray(rows)) throw new Error('Vstup musí být JSON pole transakcí.')

const calls = []
const seen = new Set()
const stats = { rows: rows.length, accepted: 0, invalid: 0, outsideDevices: 0, duplicates: 0, normalizedSelections: 0 }

for (const row of rows) {
  const deviceUid = text(row.deviceUid)
  if (!ALLOWED_DEVICES.has(deviceUid)) { stats.outsideDevices += 1; continue }
  const transactionId = text(row.transactionId)
  const selectionRaw = text(row.selection)
  const selection = normalizeSelection(selectionRaw)
  const occurredAt = pragueIso(row.occurredAt)
  const quantity = Number(row.quantity ?? 1)
  if (!transactionId || !selection || !occurredAt || !Number.isFinite(quantity) || quantity <= 0) {
    stats.invalid += 1
    continue
  }
  const eventKey = `${deviceUid}:${transactionId}`
  if (seen.has(eventKey)) { stats.duplicates += 1; continue }
  seen.add(eventKey)
  if (selection !== selectionRaw) stats.normalizedSelections += 1
  calls.push(`select public.apply_ima_a5_sale(${[
    sqlText(eventKey), sqlText(transactionId), sqlText(deviceUid), sqlText(row.deviceAcronym || deviceUid),
    sqlText(selection), sqlText(row.productName), sqlNumber(quantity), sqlNumber(row.unitPrice),
    sqlText(row.paymentMethod), `${sqlText(occurredAt)}::timestamptz`
  ].join(', ')});`)
  stats.accepted += 1
}

const sql = [
  '-- Generated from the A5Web transaction table. No card identifiers are stored.',
  'begin;', ...calls, 'commit;', ''
].join('\n')
fs.writeFileSync(outputPath, sql, { mode: 0o600 })
console.log(JSON.stringify({ ...stats, output: outputPath }))
