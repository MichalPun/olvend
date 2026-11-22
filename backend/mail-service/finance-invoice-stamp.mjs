import { PDFDocument, StandardFonts, rgb } from 'pdf-lib'

const BAND_HEIGHT = 42

function safePdfText(value, fallback = '') {
  const normalized = String(value ?? fallback)
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^\x20-\x7e]/g, '?')
    .trim()
  return normalized || fallback
}

export function stampedInvoiceFileName(internalNumber, originalName = 'faktura.pdf') {
  const number = safePdfText(internalNumber, 'OLVEND').replace(/[^A-Za-z0-9_-]+/g, '-')
  const original = safePdfText(originalName, 'faktura.pdf').replace(/[^A-Za-z0-9._-]+/g, '-')
  const base = original.replace(/\.pdf$/i, '') || 'faktura'
  return `${number}-${base}-evidence.pdf`
}

export async function stampInvoicePdf(sourceBytes, { internalNumber, documentNumber } = {}) {
  if (!internalNumber) throw new Error('Chybí evidenční číslo OLVEND / Money.')
  const pdf = await PDFDocument.load(sourceBytes, { updateMetadata: false })
  const [page] = pdf.getPages()
  if (!page) throw new Error('PDF faktury neobsahuje žádnou stránku.')

  const regular = await pdf.embedFont(StandardFonts.Helvetica)
  const bold = await pdf.embedFont(StandardFonts.HelveticaBold)
  const { width, height } = page.getSize()
  page.setSize(width, height + BAND_HEIGHT)
  page.drawRectangle({
    x: 0,
    y: height,
    width,
    height: BAND_HEIGHT,
    color: rgb(0.985, 0.985, 0.99),
    borderColor: rgb(0.83, 0.05, 0.08),
    borderWidth: 1.5
  })

  const label = 'OLVEND / MONEY - EVIDENCNI CISLO:'
  const number = safePdfText(internalNumber)
  const document = safePdfText(documentNumber)
  page.drawText(label, { x: 14, y: height + 24, size: 8.5, font: regular, color: rgb(0.18, 0.2, 0.25) })
  page.drawText(number, { x: 14, y: height + 8, size: 13, font: bold, color: rgb(0.83, 0.05, 0.08) })
  if (document) {
    const text = `DOKLAD DODAVATELE: ${document}`
    const textWidth = regular.widthOfTextAtSize(text, 8.5)
    page.drawText(text, { x: Math.max(14, width - textWidth - 14), y: height + 12, size: 8.5, font: regular, color: rgb(0.18, 0.2, 0.25) })
  }

  pdf.setProducer('OLVEND Finance')
  pdf.setCreator('OLVEND Finance')
  pdf.setSubject(`Evidencni cislo OLVEND / Money: ${number}`)
  return new Uint8Array(await pdf.save({ useObjectStreams: false }))
}
