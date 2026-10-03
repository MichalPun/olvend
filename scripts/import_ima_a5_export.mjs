#!/usr/bin/env node
import fs from 'node:fs'
import path from 'node:path'
import crypto from 'node:crypto'
import * as XLSX from 'xlsx'

const ALLOWED_DEVICES = new Set(['635456', '635457', '635458'])
const inputPath = process.argv[2]
const outputPath = process.argv[3] || '/private/tmp/ima_a5_import.sql'

if (!inputPath) {
  console.error('Použití: node scripts/import_ima_a5_export.mjs <export.xlsx> [vystup.sql]')
  process.exit(2)
}

function normalize(value) {
  return String(value ?? '')
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/[–—−]/g, '-')
    .replace(/\s+/g, ' ')
    .trim().toLowerCase()
}

function text(value) { return String(value ?? '').trim() }

function number(value) {
  if (typeof value === 'number' && Number.isFinite(value)) return value
  const parsed = Number(text(value).replace(/\s/g, '').replace(/Kč/gi, '').replace(',', '.'))
  return Number.isFinite(parsed) ? parsed : null
}

function sqlText(value) {
  if (value == null || text(value) === '') return 'null'
  return `'${text(value).replaceAll("'", "''")}'`
}

function sqlNumber(value) {
  return Number.isFinite(value) ? String(value) : 'null'
}

function normalizeSelection(value) {
  const raw = text(value).replace(/\.0$/, '')
  if (!/^\d+$/.test(raw)) return raw
  const numeric = Number(raw)
  return numeric >= 32768 && numeric <= 65535 ? String(numeric - 32768) : raw
}

function wallClockToIso(parts) {
  const local = `${String(parts.year).padStart(4,'0')}-${String(parts.month).padStart(2,'0')}-${String(parts.day).padStart(2,'0')}T${String(parts.hour).padStart(2,'0')}:${String(parts.minute).padStart(2,'0')}:${String(Math.floor(parts.second || 0)).padStart(2,'0')}`
  const guess = new Date(`${local}Z`)
  const values = Object.fromEntries(new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Prague', year:'numeric', month:'2-digit', day:'2-digit',
    hour:'2-digit', minute:'2-digit', second:'2-digit', hourCycle:'h23'
  }).formatToParts(guess).map((part) => [part.type, part.value]))
  const represented = Date.UTC(Number(values.year), Number(values.month)-1, Number(values.day), Number(values.hour), Number(values.minute), Number(values.second))
  return new Date(guess.getTime() - (represented - guess.getTime())).toISOString()
}

function timestamp(value) {
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return wallClockToIso({
      year:value.getUTCFullYear(), month:value.getUTCMonth()+1, day:value.getUTCDate(),
      hour:value.getUTCHours(), minute:value.getUTCMinutes(), second:value.getUTCSeconds()
    })
  }
  if (typeof value === 'number' && Number.isFinite(value)) {
    const parts = XLSX.SSF.parse_date_code(value)
    if (parts) return wallClockToIso({year:parts.y,month:parts.m,day:parts.d,hour:parts.H,minute:parts.M,second:parts.S})
  }
  const raw = text(value)
  if (!raw) return null
  const match = raw.match(/^(\d{1,2})[.\/-](\d{1,2})[.\/-](\d{4})[ ,T]+(\d{1,2}):(\d{2})(?::(\d{2}))?/)
  if (match) return wallClockToIso({
    day:Number(match[1]), month:Number(match[2]), year:Number(match[3]),
    hour:Number(match[4]), minute:Number(match[5]), second:Number(match[6] || 0)
  })
  const date = new Date(raw)
  return Number.isNaN(date.getTime()) ? null : date.toISOString()
}

const aliases = {
  transactionId: ['transakce - id','id transakce','transaction id'],
  occurredAt: ['datum - transakce','datum transakce','transaction date'],
  deviceUid: ['zarizeni - uid','uid zarizeni','device uid'],
  deviceAcronym: ['zarizeni - akronym','akronym zarizeni','device acronym'],
  selection: ['volba','selection'],
  unitPrice: ['cena - konecna','cena konecna','cena - ze zarizeni','cena ze zarizeni','final price','device price'],
  product: ['zbozi - nazev','nazev zbozi','product name'],
  quantity: ['mnozstvi','quantity'],
  payment: ['transakce - zpusob porizeni','typ porizeni','zpusob porizeni','acquisition type','payment method'],
  cardHint: ['karta - cislo','emv - cislo karty','card number'],
  transactionType: ['transakce - typ','typ transakce','transaction type'],
  transactionState: ['transakce - stav','stav transakce','transaction state']
}

function indexFor(headers, names) {
  for (const name of names) {
    const index = headers.indexOf(name)
    if (index >= 0) return index
  }
  return -1
}

const workbook = XLSX.readFile(path.resolve(inputPath), { cellDates:true, raw:true })
const sheet = workbook.Sheets[workbook.SheetNames[0]]
if (!sheet) throw new Error('Export IMA neobsahuje žádný list.')
const rows = XLSX.utils.sheet_to_json(sheet, { header:1, raw:true, defval:'' })

let headerRow = -1
let indexes = null
for (let rowIndex=0; rowIndex<Math.min(rows.length, 60); rowIndex += 1) {
  const headers = rows[rowIndex].map(normalize)
  const candidate = Object.fromEntries(Object.entries(aliases).map(([key,names]) => [key,indexFor(headers,names)]))
  if (candidate.transactionId >= 0 && candidate.occurredAt >= 0 && candidate.deviceUid >= 0 && candidate.selection >= 0) {
    headerRow = rowIndex
    indexes = candidate
    break
  }
}
if (headerRow < 0) throw new Error('V exportu IMA nebyla nalezena očekávaná hlavička transakcí.')

const calls = []
const seen = new Set()
const stats = { rows:0, accepted:0, outsideDevices:0, invalid:0, cancelled:0, duplicates:0 }

for (const row of rows.slice(headerRow + 1)) {
  if (!Array.isArray(row) || !row.some((value) => text(value))) continue
  stats.rows += 1
  const get = (key) => indexes[key] >= 0 ? row[indexes[key]] : ''
  const deviceUid = text(get('deviceUid')).replace(/\.0$/, '')
  if (!ALLOWED_DEVICES.has(deviceUid)) { stats.outsideDevices += 1; continue }
  const transactionId = text(get('transactionId')).replace(/\.0$/, '')
  const occurredAt = timestamp(get('occurredAt'))
  const selection = normalizeSelection(get('selection'))
  const quantity = number(get('quantity')) ?? 1
  const unitPrice = number(get('unitPrice'))
  const type = normalize(get('transactionType'))
  const state = normalize(get('transactionState'))
  if (/zrus|storn|vrac|chyb|zam[ií]tn/.test(`${type} ${state}`)) { stats.cancelled += 1; continue }
  if (type && !/(vydej|prodej|sale|vend)/.test(type)) { stats.cancelled += 1; continue }
  if (!transactionId || !occurredAt || !selection || quantity <= 0) { stats.invalid += 1; continue }
  const eventKey = `${deviceUid}:${transactionId}`
  if (seen.has(eventKey)) { stats.duplicates += 1; continue }
  seen.add(eventKey)
  let payment = text(get('payment'))
  if (!payment && text(get('cardHint'))) payment = 'EMV karta'
  const product = text(get('product'))
  const acronym = text(get('deviceAcronym'))
  calls.push(`select public.apply_ima_a5_sale(${[
    sqlText(eventKey), sqlText(transactionId), sqlText(deviceUid), sqlText(acronym),
    sqlText(selection), sqlText(product), sqlNumber(quantity), sqlNumber(unitPrice),
    sqlText(payment), `${sqlText(occurredAt)}::timestamptz`
  ].join(', ')});`)
  stats.accepted += 1
}

const sql = [
  '-- Generated from an IMA A5Web export. Card identifiers are not included.',
  'begin;', ...calls, 'commit;',''
].join('\n')
fs.writeFileSync(outputPath, sql, { mode:0o600 })
console.log(JSON.stringify({ ...stats, output:outputPath }))
