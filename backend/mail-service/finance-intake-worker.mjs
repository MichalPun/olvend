import { PDFParse } from 'pdf-parse'
import { extractInvoiceFields, findUniqueInvoiceMatch, isLikelyInlineImage } from './finance-intake-core.mjs'

const invoiceColumns = 'id,internal_number,document_number,variable_symbol,money_internal_number,total_amount,supplier_name'

function isPdf(row) {
  return String(row?.mime_type || '').toLowerCase() === 'application/pdf' || /\.pdf$/i.test(String(row?.file_name || ''))
}

function originalKind(row) {
  return /(upom|remind|vyzva|výzva)/i.test(String(row?.file_name || '')) ? 'supporting' : 'original'
}

async function updateQueue(admin, id, values) {
  const { error } = await admin.from('finance_document_intake_queue').update({ ...values, processed_at:new Date().toISOString() }).eq('id',id)
  if (error) throw error
}

async function attachToInvoice(admin, row, invoice, extracted) {
  const attachment = {
    invoice_id:invoice.id,kind:originalKind(row),storage_bucket:'finance-private',storage_path:row.storage_path,
    file_name:row.file_name,mime_type:row.mime_type,size_bytes:row.size_bytes,sha256:row.sha256,immutable:true,uploaded_by:null
  }
  const { error:attachmentError } = await admin.from('finance_invoice_attachments').upsert(attachment,{onConflict:'invoice_id,sha256',ignoreDuplicates:true})
  if (attachmentError) throw attachmentError
  await updateQueue(admin,row.id,{
    invoice_id:invoice.id,status:'invoice_created',extraction_confidence:99,
    extracted_payload:{...extracted,text_excerpt:undefined,matched_by:'pdf_text_exact_key',matched_invoice:invoice.internal_number},
    warnings:[],error_message:null
  })
  return 'invoice_created'
}

async function extractPdf(admin, row) {
  const { data,error } = await admin.storage.from('finance-private').download(row.storage_path)
  if (error) throw error
  const parser = new PDFParse({data:new Uint8Array(await data.arrayBuffer())})
  try {
    const result = await parser.getText({first:8})
    return extractInvoiceFields(result.text,{file_name:row.file_name,subject:row.subject})
  } finally {
    await parser.destroy().catch(()=>{})
  }
}

async function claim(admin, id) {
  const { data,error } = await admin.from('finance_document_intake_queue')
    .update({status:'extracting',processing_started_at:new Date().toISOString(),error_message:null})
    .eq('id',id).eq('status','queued').select('*').maybeSingle()
  if (error) throw error
  return data
}

async function processRow(admin, sourceRow, invoices) {
  const row = await claim(admin,sourceRow.id)
  if (!row) return 'skipped'
  try {
    if (isLikelyInlineImage(row)) {
      await updateQueue(admin,row.id,{status:'ignored',extraction_confidence:100,extracted_payload:{classification:'inline_image'},warnings:['Drobný vložený obrázek nebo logo'],error_message:null})
      return 'ignored'
    }
    if (!isPdf(row)) {
      await updateQueue(admin,row.id,{status:'needs_review',extraction_confidence:0,extracted_payload:{classification:'image_document'},warnings:['Obrazová příloha vyžaduje OCR nebo ruční kontrolu'],error_message:null})
      return 'needs_review'
    }
    const extracted = await extractPdf(admin,row)
    if (!extracted.text_excerpt.trim()) extracted.warnings.push('PDF nemá čitelnou textovou vrstvu; bude potřeba OCR')
    const match = findUniqueInvoiceMatch(extracted,invoices)
    if (match) return await attachToInvoice(admin,row,match,extracted)
    await updateQueue(admin,row.id,{
      status:'needs_review',extraction_confidence:extracted.confidence,extracted_payload:extracted,
      warnings:extracted.warnings,error_message:null
    })
    return 'needs_review'
  } catch (error) {
    await updateQueue(admin,row.id,{status:'failed',extraction_confidence:0,warnings:['Automatické čtení přílohy selhalo'],error_message:String(error?.message || error).slice(0,1000)}).catch(()=>{})
    return 'failed'
  }
}

export async function processFinanceIntake(admin,{limit=8}={}) {
  const [{data:rows,error:queueError},{data:invoices,error:invoiceError}] = await Promise.all([
    admin.from('finance_document_intake_queue').select('*').eq('status','queued').order('discovered_at',{ascending:true}).limit(limit),
    admin.from('finance_received_invoices').select(invoiceColumns)
  ])
  if (queueError) throw queueError
  if (invoiceError) throw invoiceError
  const summary={processed:0,invoice_created:0,needs_review:0,ignored:0,failed:0,skipped:0}
  for (const row of rows || []) {
    const status=await processRow(admin,row,invoices || [])
    summary.processed+=status==='skipped'?0:1
    summary[status]=(summary[status]||0)+1
  }
  return summary
}
