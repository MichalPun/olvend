import { PDFParse } from 'pdf-parse'
import { extractInvoiceFields, extractInvoiceLineItems, findUniqueInvoiceMatch, isLikelyInlineImage, normalizeMatchKey } from './finance-intake-core.mjs'

const invoiceColumns = 'id,internal_number,document_number,variable_symbol,money_internal_number,total_amount,supplier_name'

function isPdf(row) {
  return String(row?.mime_type || '').toLowerCase() === 'application/pdf' || /\.pdf$/i.test(String(row?.file_name || ''))
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
    const textResult = await parser.getText({first:8})
    const tableResult = await parser.getTable({first:8}).catch(()=>({pages:[]}))
    return {...extractInvoiceFields(textResult.text,{file_name:row.file_name,subject:row.subject}),line_items:extractInvoiceLineItems(tableResult.pages)}
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

async function processRow(admin, sourceRow, invoices, catalog) {
  const row = await claim(admin,sourceRow.id)
  if (!row) return 'skipped'
  try {
    if (isLikelyInlineImage(row)) {
      await updateQueue(admin,row.id,{status:'ignored',document_class:'other',extraction_confidence:100,extracted_payload:{classification:'inline_image'},warnings:['Drobný vložený obrázek nebo logo'],error_message:null})
      return 'ignored'
    }
    if (!isPdf(row)) {
      await updateQueue(admin,row.id,{status:'needs_review',document_class:'other',extraction_confidence:0,extracted_payload:{classification:'image_document'},warnings:['Obrazová příloha vyžaduje OCR nebo ruční kontrolu'],error_message:null})
      return 'needs_review'
    }
    const extracted = await extractPdf(admin,row)
    if (!extracted.text_excerpt.trim()) extracted.warnings.push('PDF nemá čitelnou textovou vrstvu; bude potřeba OCR')
    if (['accounting_report','contract'].includes(extracted.document_class)) {
      await updateQueue(admin,row.id,{status:'ignored',document_class:extracted.document_class,extraction_confidence:95,extracted_payload:{...extracted,text_excerpt:undefined},warnings:['Dokument není přijatá faktura ani upomínka'],error_message:null})
      return 'ignored'
    }
    const match = findUniqueInvoiceMatch(extracted,invoices)
    if (match) return await attachToInvoice(admin,row,match,extracted,catalog)
    if (extracted.document_class==='reminder') extracted.warnings.unshift('Upomínka nebyla jednoznačně spojena s původní fakturou; nová faktura se nevytvořila')
    if (extracted.line_items.length) extracted.warnings.push(`Rozpoznáno ${extracted.line_items.length} položek; před naskladněním je nutné potvrdit jejich skladové karty`)
    await updateQueue(admin,row.id,{
      status:'needs_review',document_class:extracted.document_class,extraction_confidence:extracted.confidence,extracted_payload:extracted,
      warnings:extracted.warnings,error_message:null
    })
    return 'needs_review'
  } catch (error) {
    await updateQueue(admin,row.id,{status:'failed',extraction_confidence:0,warnings:['Automatické čtení přílohy selhalo'],error_message:String(error?.message || error).slice(0,1000)}).catch(()=>{})
    return 'failed'
  }
}

export async function processFinanceIntake(admin,{limit=8}={}) {
  const [{data:rows,error:queueError},{data:invoices,error:invoiceError},{data:products,error:productError},{data:suppliers,error:supplierError},{data:mappings,error:mappingError}] = await Promise.all([
    admin.from('finance_document_intake_queue').select('*').eq('status','queued').order('discovered_at',{ascending:true}).limit(limit),
    admin.from('finance_received_invoices').select(invoiceColumns),
    admin.from('products').select('id,name,ean,sku').eq('active',true),
    admin.from('purchase_suppliers').select('id,name'),
    admin.from('supplier_product_mappings').select('supplier_id,product_id,supplier_item_code,ean,supplier_item_name').eq('active',true)
  ])
  if (queueError) throw queueError
  if (invoiceError) throw invoiceError
  if (productError) throw productError
  if (supplierError) throw supplierError
  if (mappingError) throw mappingError
  const catalog={products:products||[],suppliers:suppliers||[],mappings:mappings||[]}
  const summary={processed:0,invoice_created:0,needs_review:0,ignored:0,failed:0,skipped:0}
  for (const row of rows || []) {
    const status=await processRow(admin,row,invoices || [],catalog)
    summary.processed+=status==='skipped'?0:1
    summary[status]=(summary[status]||0)+1
  }
  return summary
}
