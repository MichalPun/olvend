import assert from 'node:assert/strict'
import crypto from 'node:crypto'
import { writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { PDFDocument, StandardFonts } from 'pdf-lib'
import { PDFParse } from 'pdf-parse'
import { stampInvoicePdf, stampedInvoiceFileName } from './finance-invoice-stamp.mjs'

const source = await PDFDocument.create()
const font = await source.embedFont(StandardFonts.Helvetica)
const sourcePage = source.addPage([595, 842])
sourcePage.drawText('ORIGINAL INVOICE 2026-991', { x: 40, y: 790, size: 16, font })
const sourceBytes = new Uint8Array(await source.save({ useObjectStreams: false }))
const originalHash = crypto.createHash('sha256').update(sourceBytes).digest('hex')

const stampedBytes = await stampInvoicePdf(sourceBytes, { internalNumber: 'FP260573', documentNumber: '2026-991' })
await writeFile(join(tmpdir(), 'olvend-stamp-demo.pdf'), stampedBytes)
assert.notEqual(crypto.createHash('sha256').update(stampedBytes).digest('hex'), originalHash)
assert.equal(crypto.createHash('sha256').update(sourceBytes).digest('hex'), originalHash, 'Original PDF must remain unchanged')

const stamped = await PDFDocument.load(stampedBytes)
assert.equal(stamped.getPageCount(), 1)
assert.equal(stamped.getPage(0).getHeight(), 884)

const parser = new PDFParse({ data: stampedBytes })
try {
  const text = await parser.getText()
  assert.match(text.text, /FP260573/)
  assert.match(text.text, /ORIGINAL INVOICE 2026-991/)
} finally {
  await parser.destroy().catch(() => {})
}

assert.equal(stampedInvoiceFileName('FP260573', 'Faktura 991.pdf'), 'FP260573-Faktura-991-evidence.pdf')
console.log('Finance invoice stamp tests passed.')
