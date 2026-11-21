function escapeRegExp(value) { return String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&') }
function blocks(xml, tag) {
  const safe=escapeRegExp(tag)
  return Array.from(String(xml||'').matchAll(new RegExp(`<${safe}(?:\\s[^>]*)?>([\\s\\S]*?)<\\/${safe}>`,'gi')),m=>m[1])
}
function decodeXml(value) {
  return String(value??'').replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g,'$1')
    .replace(/&#x([0-9a-f]+);/gi,(_,c)=>String.fromCodePoint(Number.parseInt(c,16)))
    .replace(/&#([0-9]+);/g,(_,c)=>String.fromCodePoint(Number(c)))
    .replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&quot;/g,'"').replace(/&apos;/g,"'").replace(/&amp;/g,'&').trim()
}
function text(xml,tag){return decodeXml(blocks(xml,tag)[0]||'')}
function attribute(xml,tag,name){return decodeXml(String(xml||'').match(new RegExp(`<${escapeRegExp(tag)}\\b[^>]*\\b${escapeRegExp(name)}=["']([^"']*)["']`,'i'))?.[1]||'')}
function number(value){const n=Number(String(value??'').replace(/\s/g,'').replace(',','.'));return Number.isFinite(n)?Math.round(n*100)/100:0}
function date(value){return String(value||'').match(/\d{4}-\d{2}-\d{2}/)?.[0]||null}

export function parseMoneyLiabilitiesXml(xml){
  const source=String(xml||'').replace(/^\uFEFF/,'').trim()
  if(!/<MoneyData\b/i.test(source))throw new Error('Soubor není nativní XML export Money S3.')
  const items=blocks(source,'Zavazek')
  if(!items.length)throw new Error('XML neobsahuje žádné záznamy Zavazek.')
  const rows=items.map((row,index)=>{
    const total=number(text(row,'Celkem'))
    const actual=number(text(row,'UhZbyva'))
    const orderable=number(text(row,'PUZbyva'))
    return {
      internal_number:text(row,'Doklad')||`ZAVAZEK-${index+1}`,
      series:text(row,'DRada')||null,
      series_number:Number(text(row,'DCislo')||0)||null,
      description:text(row,'Popis')||'Bez popisu',
      accounting_date:date(text(row,'DatUcPr')),
      issue_date:date(text(row,'DatVyst')),
      due_date:date(text(row,'DatSpl')),
      taxable_date:date(text(row,'DatPln')),
      received_date:date(text(row,'Doruceno')),
      currency:'CZK',
      total_amount:total,
      actual_remaining_amount:actual,
      orderable_remaining_amount:orderable,
      ordered_amount:Math.max(0,Math.round((actual-orderable)*100)/100),
      money_payment_date:date(text(row,'UhDatum')),
      money_payment_document:text(row,'UhDokl')||null,
    }
  })
  const actualPaid=rows.filter(r=>Math.abs(r.actual_remaining_amount)<.01&&Math.abs(r.total_amount)>=.01).length
  const ordered=rows.filter(r=>r.ordered_amount>.01).length
  const partial=rows.filter(r=>Math.abs(r.actual_remaining_amount)>=.01&&Math.abs(r.actual_remaining_amount)<Math.abs(r.total_amount)-.01).length
  return {
    format:'money_s3_liabilities',exported_at:date(attribute(source,'MoneyData','ExpDate')),
    accounting_year_start:date(attribute(source,'MoneyData','HospRokOd')),accounting_year_end:date(attribute(source,'MoneyData','HospRokDo')),
    rows,warnings:[],summary:{
      liabilities:rows.length,paid:actualPaid,ordered,partial,
      total_amount:Math.round(rows.reduce((s,r)=>s+r.total_amount,0)*100)/100,
      actual_remaining_amount:Math.round(rows.reduce((s,r)=>s+r.actual_remaining_amount,0)*100)/100,
      orderable_remaining_amount:Math.round(rows.reduce((s,r)=>s+r.orderable_remaining_amount,0)*100)/100,
      ordered_amount:Math.round(rows.reduce((s,r)=>s+r.ordered_amount,0)*100)/100,
    }
  }
}

export async function sha256Hex(buffer){
  const digest=await crypto.subtle.digest('SHA-256',buffer)
  return Array.from(new Uint8Array(digest),b=>b.toString(16).padStart(2,'0')).join('')
}
