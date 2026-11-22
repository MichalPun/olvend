import { PDFParse } from 'pdf-parse'
import { assessAutoEvidence, extractInvoiceFields, extractInvoiceLineItems, findUniqueInvoiceMatch, isLikelyInlineImage, normalizeMatchKey } from './finance-intake-core.mjs'
import { createFinanceOcrSession, needsInvoiceOcr } from './finance-intake-ocr.mjs'

const invoiceColumns = 'id,internal_number,document_number,variable_symbol,money_internal_number,total_amount,supplier_name,supplier_company_id,supplier_tax_id'

function isPdf(row) {
  return String(row?.mime_type || '').toLowerCase() === 'application/pdf' || /\.pdf$/i.test(String(row?.file_name || ''))
}

function isImage(row) {
  return String(row?.mime_type||'').toLowerCase().startsWith('image/')||/\.(png|jpe?g|tiff?)$/i.test(String(row?.file_name||''))
}

function originalKind(row,extracted) {
  return extracted?.document_class==='reminder'||/(upom|remind|vyzva|výzva)/i.test(String(row?.file_name || '')) ? 'supporting' : 'original'
}

async function updateQueue(admin, id, values) {
  const { error } = await admin.from('finance_document_intake_queue').update({ ...values, processed_at:new Date().toISOString() }).eq('id',id)
  if (error) throw error
}

function unique(items) { return items.length===1?items[0]:null }
function mappedProduct(line,invoice,catalog) {
  const ean=String(line.ean||'').replace(/\D/g,'')
  if(ean){
    const product=unique(catalog.products.filter(item=>String(item.ean||'').replace(/\D/g,'')===ean))
    if(product)return {product_id:product.id,confidence:100,method:'product_ean'}
    const mapping=unique(catalog.mappings.filter(item=>String(item.ean||'').replace(/\D/g,'')===ean))
    if(mapping)return {product_id:mapping.product_id,confidence:100,method:'supplier_ean'}
  }
  const supplier=unique(catalog.suppliers.filter(item=>{const a=normalizeMatchKey(item.name),b=normalizeMatchKey(invoice.supplier_name);return a&&b&&(a===b||a.includes(b)||b.includes(a))}))
  if(supplier&&line.supplier_item_code){
    const code=normalizeMatchKey(line.supplier_item_code)
    const mapping=unique(catalog.mappings.filter(item=>Number(item.supplier_id)===Number(supplier.id)&&normalizeMatchKey(item.supplier_item_code)===code))
    if(mapping)return {product_id:mapping.product_id,confidence:99,method:'supplier_code'}
  }
  const description=normalizeMatchKey(line.description)
  if(description.length>=5){
    const product=unique(catalog.products.filter(item=>normalizeMatchKey(item.name)===description))
    if(product)return {product_id:product.id,confidence:92,method:'product_name'}
    if(supplier){
      const mapping=unique(catalog.mappings.filter(item=>Number(item.supplier_id)===Number(supplier.id)&&normalizeMatchKey(item.supplier_item_name)===description))
      if(mapping)return {product_id:mapping.product_id,confidence:94,method:'supplier_name'}
    }
  }
  return null
}

async function saveInvoiceLines(admin,invoice,extracted,catalog) {
  if(extracted.document_class!=='invoice'||!extracted.line_items?.length)return
  const rows=extracted.line_items.map((line,index)=>{
    const match=mappedProduct(line,invoice,catalog),rawTotal=line.total_amount??(Number(line.quantity||0)*Number(line.unit_price||0)),total=Number(rawTotal||0)
    return {invoice_id:invoice.id,line_number:index+1,description:line.description,quantity:line.quantity,unit_code:line.unit_code,unit_price:line.unit_price,supplier_item_code:line.supplier_item_code,ean:line.ean,product_id:match?.product_id||null,stock_relevant:Boolean(match),mapping_confidence:match?.confidence||null,net_amount:total,vat_amount:0,total_amount:total,source_payload:{mapping_method:match?.method||null}}
  })
  const {error}=await admin.from('finance_invoice_allocations').upsert(rows,{onConflict:'invoice_id,line_number'})
  if(error)throw error
  const mapped=rows.filter(item=>item.product_id).length
  if(mapped){
    const {error:updateError}=await admin.from('finance_received_invoices').update({stock_receipt_status:mapped===rows.length?'ready':'needs_mapping'}).eq('id',invoice.id).neq('stock_receipt_status','ordered').neq('stock_receipt_status','received')
    if(updateError)throw updateError
  }
}

async function attachToInvoice(admin, row, invoice, extracted, catalog) {
  const attachment = {
    invoice_id:invoice.id,kind:originalKind(row,extracted),storage_bucket:'finance-private',storage_path:row.storage_path,
    file_name:row.file_name,mime_type:row.mime_type,size_bytes:row.size_bytes,sha256:row.sha256,immutable:true,uploaded_by:null
  }
  const { error:attachmentError } = await admin.from('finance_invoice_attachments').upsert(attachment,{onConflict:'invoice_id,sha256',ignoreDuplicates:true})
  if (attachmentError) throw attachmentError
  await saveInvoiceLines(admin,invoice,extracted,catalog)
  await updateQueue(admin,row.id,{
    invoice_id:invoice.id,status:'invoice_created',document_class:extracted.document_class,extraction_confidence:99,
    extracted_payload:{...extracted,text_excerpt:undefined,matched_by:'existing_invoice_exact_key',matched_invoice:invoice.internal_number},
    warnings:[],error_message:null
  })
  return 'invoice_created'
}

async function downloadOriginal(admin,row){
  const { data,error } = await admin.storage.from('finance-private').download(row.storage_path)
  if (error) throw error
  return new Uint8Array(await data.arrayBuffer())
}

function mergeOcrExtraction(textExtracted,ocrExtracted,useOcr){
  const preferred=useOcr?ocrExtracted:textExtracted,fallback=useOcr?textExtracted:ocrExtracted
  const merged={...preferred}
  for(const key of ['supplier_name','supplier_company_id','supplier_tax_id','document_number','issue_date','taxable_date','due_date','currency','net_amount','vat_amount','total_amount','bank_account','iban','variable_symbol']){
    if(merged[key]==null||merged[key]==='')merged[key]=fallback[key]
  }
  merged.reference_numbers=[...new Set([...(preferred.reference_numbers||[]),...(fallback.reference_numbers||[])])]
  merged.confidence=Math.max(Number(preferred.confidence||0),Number(fallback.confidence||0))
  return merged
}

async function extractPdf(admin, row, ocr) {
  const bytes=await downloadOriginal(admin,row)
  const parser = new PDFParse({data:bytes})
  try {
    const textResult = await parser.getText({first:8})
    const tableResult = await parser.getTable({first:8}).catch(()=>({pages:[]}))
    const textExtracted=extractInvoiceFields(textResult.text,{file_name:row.file_name,subject:row.subject})
    const lineItems=extractInvoiceLineItems(tableResult.pages)
    if(!needsInvoiceOcr(textResult.text))return {...textExtracted,line_items:lineItems,extraction_method:'pdf_text'}
    try{
      const screenshots=await parser.getScreenshot({first:Math.min(4,Math.max(1,Number(process.env.FINANCE_OCR_PDF_PAGES||3))),desiredWidth:1800,imageDataUrl:false,imageBuffer:true})
      const results=[]
      for(const page of screenshots.pages)results.push(await ocr.recognize(page.data))
      const ocrText=results.map(result=>result.text).join('\n\n')
      const ocrExtracted=extractInvoiceFields(ocrText,{file_name:row.file_name,subject:row.subject})
      const average=results.length?results.reduce((sum,result)=>sum+result.confidence,0)/results.length:0
      const merged=mergeOcrExtraction(textExtracted,ocrExtracted,true)
      merged.line_items=lineItems
      merged.text_excerpt=ocrText.slice(0,12000)
      merged.extraction_method='pdf_ocr'
      merged.ocr_confidence=Math.round(average*10)/10
      merged.ocr_pages=results.length
      if(average<55)merged.warnings=[...(merged.warnings||[]),'OCR má nízkou jistotu; porovnejte údaje s originálem']
      return merged
    }catch(error){
      return {...textExtracted,line_items:lineItems,extraction_method:'pdf_text',warnings:[...(textExtracted.warnings||[]),`OCR se nepodařilo dokončit: ${String(error?.message||error).slice(0,180)}`]}
    }
  } finally {
    await parser.destroy().catch(()=>{})
  }
}

async function extractImage(admin,row,ocr){
  const bytes=await downloadOriginal(admin,row)
  const result=await ocr.recognize(bytes)
  const extracted=extractInvoiceFields(result.text,{file_name:row.file_name,subject:row.subject})
  return {...extracted,line_items:[],text_excerpt:result.text.slice(0,12000),extraction_method:'image_ocr',ocr_confidence:Math.round(result.confidence*10)/10,ocr_pages:1,warnings:result.confidence<55?[...(extracted.warnings||[]),'OCR má nízkou jistotu; porovnejte údaje s originálem']:extracted.warnings}
}

async function claim(admin, id, expectedStatus = 'queued') {
  const { data,error } = await admin.from('finance_document_intake_queue')
    .update({status:'extracting',processing_started_at:new Date().toISOString(),error_message:null})
    .eq('id',id).eq('status',expectedStatus).select('*').maybeSingle()
  if (error) throw error
  return data
}

function automaticValues(extracted) {
  return {
    evidence_mode:'automatic',supplier_name:extracted.supplier_name,supplier_company_id:extracted.supplier_company_id,
    supplier_tax_id:extracted.supplier_tax_id,document_number:extracted.document_number,document_class:extracted.document_class,
    total_amount:extracted.total_amount,net_amount:extracted.net_amount,vat_amount:extracted.vat_amount,currency:extracted.currency,
    variable_symbol:extracted.variable_symbol,issue_date:extracted.issue_date,taxable_date:extracted.taxable_date,
    due_date:extracted.due_date,bank_account:extracted.bank_account,iban:extracted.iban
  }
}

async function autoEvidenceInvoice(admin,row,extracted,invoices,catalog,assessment) {
  const payload={...extracted,auto_evidence:assessment}
  await updateQueue(admin,row.id,{status:'needs_review',document_class:extracted.document_class,extraction_confidence:extracted.confidence,extracted_payload:payload,warnings:extracted.warnings||[],error_message:null})
  const {data,error}=await admin.rpc('finance_review_intake_document_v1',{p_queue_id:row.id,p_action:'create',p_invoice_id:null,p_values:automaticValues(extracted)})
  if(error){
    const reason=`Automatické zaevidování nebylo dokončeno: ${String(error.message||error).slice(0,220)}`
    await updateQueue(admin,row.id,{status:'needs_review',document_class:extracted.document_class,extraction_confidence:extracted.confidence,extracted_payload:{...payload,auto_evidence:{...assessment,eligible:false,reasons:[...assessment.reasons,reason]}},warnings:[...(extracted.warnings||[]),reason],error_message:null})
    return 'needs_review'
  }
  const {data:invoice,error:invoiceError}=await admin.from('finance_received_invoices').select(invoiceColumns).eq('id',data.invoice_id).single()
  if(!invoiceError&&invoice){
    invoices.push(invoice)
    await saveInvoiceLines(admin,invoice,extracted,catalog).catch(error=>console.error('Automatic invoice stock mapping failed:',error))
  }
  return 'invoice_created'
}

async function decideExtractedDocument(admin,row,extracted,invoices,catalog) {
  const match=findUniqueInvoiceMatch(extracted,invoices)
  if(match)return attachToInvoice(admin,row,match,extracted,catalog)
  const assessment=assessAutoEvidence(extracted,invoices,{received_at:row.message_received_at||row.discovered_at})
  if(assessment.eligible)return autoEvidenceInvoice(admin,row,extracted,invoices,catalog,assessment)
  if(extracted.document_class==='reminder')extracted.warnings.unshift('Upomínka nebyla jednoznačně spojena s původní fakturou; nová faktura se nevytvořila')
  if(extracted.line_items.length)extracted.warnings.push(`Rozpoznáno ${extracted.line_items.length} položek; před naskladněním je nutné potvrdit jejich skladové karty`)
  await updateQueue(admin,row.id,{
    status:'needs_review',document_class:extracted.document_class,extraction_confidence:extracted.confidence,
    extracted_payload:{...extracted,auto_evidence:assessment},warnings:extracted.warnings,error_message:null
  })
  return 'needs_review'
}

async function processRow(admin, sourceRow, invoices, catalog, ocr) {
  const row = await claim(admin,sourceRow.id)
  if (!row) return 'skipped'
  try {
    if (isLikelyInlineImage(row)) {
      await updateQueue(admin,row.id,{status:'ignored',document_class:'other',extraction_confidence:100,extracted_payload:{classification:'inline_image'},warnings:['Drobný vložený obrázek nebo logo'],error_message:null})
      return 'ignored'
    }
    if (!isPdf(row)&&!isImage(row)) {
      await updateQueue(admin,row.id,{status:'needs_review',document_class:'other',extraction_confidence:0,extracted_payload:{classification:'unsupported_structured_document'},warnings:['Tento typ přílohy zatím vyžaduje ruční kontrolu'],error_message:null})
      return 'needs_review'
    }
    const extracted = isPdf(row)?await extractPdf(admin,row,ocr):await extractImage(admin,row,ocr)
    if (!extracted.text_excerpt.trim()) extracted.warnings.push('V dokumentu se nepodařilo rozpoznat žádný text')
    if (['accounting_report','contract'].includes(extracted.document_class)) {
      await updateQueue(admin,row.id,{status:'ignored',document_class:extracted.document_class,extraction_confidence:95,extracted_payload:{...extracted,text_excerpt:undefined},warnings:['Dokument není přijatá faktura ani upomínka'],error_message:null})
      return 'ignored'
    }
    return await decideExtractedDocument(admin,row,extracted,invoices,catalog)
  } catch (error) {
    await updateQueue(admin,row.id,{status:'failed',extraction_confidence:0,warnings:['Automatické čtení přílohy selhalo'],error_message:String(error?.message || error).slice(0,1000)}).catch(()=>{})
    return 'failed'
  }
}

async function reconsiderReviewRow(admin,sourceRow,invoices,catalog){
  const row=await claim(admin,sourceRow.id,'needs_review')
  if(!row)return 'skipped'
  try{
    const stored=row.extracted_payload||{}
    const refreshed=stored.text_excerpt?extractInvoiceFields(stored.text_excerpt,{file_name:row.file_name,subject:row.subject}):stored
    const extracted={...stored,...refreshed,line_items:stored.line_items||[],text_excerpt:stored.text_excerpt,
      extraction_method:stored.extraction_method,ocr_confidence:stored.ocr_confidence,ocr_pages:stored.ocr_pages,
      warnings:[...(refreshed.warnings||row.warnings||[])]}
    if(!Array.isArray(extracted.line_items))extracted.line_items=[]
    return await decideExtractedDocument(admin,row,extracted,invoices,catalog)
  }catch(error){
    const reason=`Opakovaná automatická kontrola selhala: ${String(error?.message||error).slice(0,220)}`
    await updateQueue(admin,row.id,{status:'needs_review',warnings:[...(row.warnings||[]),reason],error_message:null}).catch(()=>{})
    return 'needs_review'
  }
}

export async function processFinanceIntake(admin,{limit=8}={}) {
  const [{data:rows,error:queueError},{data:reviewRows,error:reviewError},{data:invoices,error:invoiceError},{data:products,error:productError},{data:suppliers,error:supplierError},{data:mappings,error:mappingError}] = await Promise.all([
    admin.from('finance_document_intake_queue').select('*').eq('status','queued').order('discovered_at',{ascending:true}).limit(limit),
    admin.from('finance_document_intake_queue').select('*').eq('status','needs_review').order('discovered_at',{ascending:true}).limit(limit*3),
    admin.from('finance_received_invoices').select(invoiceColumns),
    admin.from('products').select('id,name,ean,sku').eq('active',true),
    admin.from('purchase_suppliers').select('id,name'),
    admin.from('supplier_product_mappings').select('supplier_id,product_id,supplier_item_code,ean,supplier_item_name').eq('active',true)
  ])
  if (queueError) throw queueError
  if (reviewError) throw reviewError
  if (invoiceError) throw invoiceError
  if (productError) throw productError
  if (supplierError) throw supplierError
  if (mappingError) throw mappingError
  const catalog={products:products||[],suppliers:suppliers||[],mappings:mappings||[]}
  const ocr=createFinanceOcrSession()
  const summary={processed:0,reconsidered:0,invoice_created:0,needs_review:0,ignored:0,failed:0,skipped:0}
  try{
    const invoiceList=invoices||[]
    const pendingReviews=(reviewRows||[]).filter(row=>!row.extracted_payload?.auto_evidence?.version)
    for(const row of pendingReviews){
      const status=await reconsiderReviewRow(admin,row,invoiceList,catalog)
      summary.reconsidered+=status==='skipped'?0:1
      summary[status]=(summary[status]||0)+1
    }
    for (const row of rows || []) {
      const status=await processRow(admin,row,invoiceList,catalog,ocr)
      summary.processed+=status==='skipped'?0:1
      summary[status]=(summary[status]||0)+1
    }
  }finally{
    await ocr.terminate()
  }
  return summary
}
