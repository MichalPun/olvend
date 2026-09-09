import { supabase } from './supabase.js'
const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))
const list = x => Array.isArray(x) ? x : []
const number = x => Number(x ?? 0)
const localTime = v => { if(!v)return ''; const d=new Date(v); return new Date(d.getTime()-d.getTimezoneOffset()*60000).toISOString().slice(0,16) }
const expiry = b => b?.best_before_date || b?.use_by_date || ''
async function read(query) { const {data,error}=await query; if(error) throw error; return data }
function historyChanges(h) {
 const result=[]
 const compare=(label,a,b,fields)=>{for(const [key,title] of Object.entries(fields))if(String(a?.[key]??'')!==String(b?.[key]??''))result.push(`${label} · ${title}: ${a?.[key]??'—'} → ${b?.[key]??'—'}`)}
 compare('Návštěva',h.before_data?.visit,h.after_data?.visit,{status:'stav',arrived_at:'příjezd',completed_at:'dokončení',operator_note:'poznámka'})
 compare('Hotovost',h.before_data?.cash,h.after_data?.cash,{operator_collected_confirmed:'vybráno',operator_bag_label:'sáček',supervisor_counted_cash_czk:'přepočítáno Kč',note:'poznámka'})
 for(const type of ['items','fills','waste']){
  const a=list(h.before_data?.[type]),b=list(h.after_data?.[type])
  for(const id of new Set([...a,...b].map(x=>x.id))){const old=a.find(x=>x.id===id),next=b.find(x=>x.id===id),row=next||old
   compare(row.physical_position_label?`Pozice ${row.physical_position_label}`:row.product_name||'Doplnění',old,next,type==='items'?{actual_before_quantity:'před doplněním',actual_add_quantity:'doplněno',removed_quantity:'odebráno',final_quantity:'po doplnění',capacity_quantity:'kapacita',operator_note:'poznámka'}:{product_name:'produkt',quantity:'množství',expiry_date:'trvanlivost',sale_price_czk:'cena Kč',reason:'důvod'})
  }
 }
 return result.map(line=>`<li>${esc(line)}</li>`).join('')
}
export async function openRouteVisitCorrection(visitId, onSaved) {
 const dialog=document.createElement('dialog')
 dialog.className='route-correction-dialog'
 dialog.innerHTML='<p>Načítám aktuální zápis návštěvy…</p><button type="button" data-close>Zavřít</button>'
 document.body.append(dialog); dialog.showModal()
 dialog.addEventListener('close',()=>dialog.remove())
 dialog.addEventListener('click',e=>{if(e.target.closest('[data-close]'))dialog.close()})
 try {
  const [visit,items,fills,cash,products,batches,movements,history,wastes]=await Promise.all([
   read(supabase.from('route_machine_visits').select('*').eq('id',visitId).single()),
   read(supabase.from('route_machine_visit_items').select('*').eq('visit_id',visitId).order('physical_position_label')),
   read(supabase.from('route_machine_visit_food_fills').select('*').eq('visit_id',visitId).order('load_order')),
   read(supabase.from('route_machine_cash_reports').select('*').eq('visit_id',visitId).maybeSingle()),
   read(supabase.from('products').select('id,name,sku,base_unit,active').eq('active',true).order('name')),
   read(supabase.from('inventory_batches').select('id,product_id,best_before_date,use_by_date').order('id',{ascending:false}).limit(1000)),
   read(supabase.from('stock_movements_v13').select('product_id,batch_id,quantity_base_units,from_stock_location_id,to_stock_location_id,reference_id').like('reference_id',`route_visit_${visitId}_%`).limit(1000)),
   read(supabase.from('route_visit_corrections').select('id,reason,created_at,actor_id,before_data,after_data,employees(name,surname)').eq('visit_id',visitId).order('id',{ascending:false})),
   read(supabase.from('route_vehicle_waste_items').select('*').eq('route_machine_visit_id',visitId))
  ])
  if(!['completed','skipped'].includes(visit.status))throw Error('Operátor musí nejdřív dokončit nebo přeskočit návštěvu. Potom lze zápis opravit.')
  const productOptions=id=>products.filter(p=>p.base_unit==='ks').map(p=>`<option value="${p.id}" ${String(p.id)===String(id)?'selected':''}>${esc(p.name)} · ${esc(p.sku)}</option>`).join('')
  const sources=f=>f.correction_sources || movements.filter(m=>m.reference_id===f.stock_reference_id&&m.product_id===f.product_id).map(m=>({product_id:m.product_id,batch_id:m.batch_id,quantity:m.quantity_base_units}))
  const batchOptions=(productId,batchId)=>'<option value="">Vyber šarži</option>'+batches.filter(b=>String(b.product_id)===String(productId)).map(b=>`<option value="${b.id}" ${String(b.id)===String(batchId)?'selected':''}>${esc(expiry(b)||'Expirace neznámá')} · šarže ${b.id}</option>`).join('')
  let nextFillId=-1
  const fillForm=f=>{
   const src=sources(f); const batchId=src.length===1?src[0].batch_id:null
   return `<fieldset data-fill="${f.id}"><legend>${esc(f.product_name)} · původně ${f.quantity} ks</legend><div class="correction-fields"><label>Produkt<select data-product>${productOptions(f.product_id)}</select></label><label>Skutečně vloženo (ks)<input data-quantity type="number" min="0" max="10000" step="1" value="${f.quantity}" required></label><label>Šarže / trvanlivost<select data-batch>${batchOptions(f.product_id,batchId)}</select></label><label>Cena potvrzená na automatu (Kč)<input data-price type="number" min="0" max="10000" step="0.01" value="${esc(f.sale_price_czk)}" required></label></div><p class="correction-impact" data-impact></p></fieldset>`
  }
  dialog.innerHTML=`<form><header><div><h2>Opravit návštěvu</h2><p>Návštěva #${visit.id} · ${esc(new Date(visit.visit_date+'T12:00:00').toLocaleDateString('cs-CZ',{weekday:'long',day:'numeric',month:'numeric',year:'numeric'}))}</p></div><button type="button" data-close aria-label="Zavřít">×</button></header>
  <p>Označ údaje, které chceš změnit. Sklad se upraví společně se zápisem. Datum šarže vybírej podle fyzického balení.</p>
  <section><h3>Zápis a stav návštěvy</h3><div class="correction-fields"><label>Stav<select data-status><option value="completed" ${visit.status==='completed'?'selected':''}>Dokončeno</option><option value="skipped" ${visit.status==='skipped'?'selected':''}>Přeskočeno</option></select></label><label>Důvod přeskočení<input data-skip value="${esc(visit.skip_reason)}"></label></div><div class="correction-fields"><label>Příjezd<input type="datetime-local" data-arrived value="${localTime(visit.arrived_at)}"></label><label>Skutečné dokončení<input type="datetime-local" data-completed value="${localTime(visit.completed_at)}"></label></div><label>Poznámka k návštěvě<textarea data-note>${esc(visit.operator_note)}</textarea></label></section>
  <section><h3>Doplnění a kapacity</h3>${items.filter(i=>['food_slot','coffee_container'].includes(i.item_kind)).map(i=>`<details data-item="${i.id}"><summary>${esc(i.physical_position_label)} · ${esc(i.actual_product_name||i.planned_product_name)} · vloženo ${number(i.actual_add_quantity)} ${esc(i.unit)}</summary><label class="correction-check"><input type="checkbox" data-edit> Upravit tuto položku</label><div class="correction-fields"><label>Kapacita (${esc(i.unit)})<input data-capacity type="number" min="${i.item_kind==='food_slot'?'1':'0.001'}" step="${i.item_kind==='food_slot'?'1':'0.001'}" value="${esc(i.capacity_quantity)}"></label><label>Skutečný stav před doplněním (${esc(i.unit)})<input data-before type="number" min="0" step="${i.item_kind==='food_slot'?'1':'0.001'}" value="${number(i.actual_before_quantity)}"></label><p>Odebráno: ${number(i.removed_quantity)} · po doplnění: ${number(i.final_quantity)} ${esc(i.unit)}</p></div>${i.item_kind==='food_slot'?fills.filter(f=>f.visit_item_id===i.id).map(fillForm).join('')||'<p>U této pozice není uložené doplnění.</p>':`<label>Skutečně doplněno (${esc(i.unit)})<input data-added type="number" min="0" step="0.001" value="${number(i.actual_add_quantity)}"></label>`}${i.item_kind==='food_slot'?'<button type="button" data-add-fill>Přidat chybějící doplnění</button>':''}<label>Poznámka k položce<textarea data-item-note>${esc(i.operator_note)}</textarea></label></details>`).join('')||'<p>Návštěva nemá uložené skladové položky.</p>'}</section>
  <section><h3>Odpisy svezené z automatu</h3>${wastes.map(w=>`<details data-waste="${w.id}"><summary>${esc(w.product_name)} · ${number(w.quantity)} ${esc(w.unit)} · ${w.status==='pending'?'čeká na předání skladu':'předáno skladu'}</summary>${w.status==='pending'?`<label class="correction-check"><input type="checkbox" data-edit-waste> Upravit odpis</label><div class="correction-fields"><label>Skutečně odepsáno (ks)<input data-waste-quantity type="number" min="0" step="1" value="${number(w.quantity)}"></label><label>Důvod<select data-waste-reason>${Object.entries({expired:'Prošlé',shaken:'Poškozené výdejem',damaged:'Poškozené',opened:'Otevřené',other:'Jiný důvod'}).map(([k,v])=>`<option value="${k}" ${w.reason===k?'selected':''}>${v}</option>`).join('')}</select></label></div>`:'<p>Odpis je součástí uzavřeného skladového dokladu.</p>'}</details>`).join('')||'<p>Žádné evidované odpisy.</p>'}</section>
  <section><h3>Hotovost</h3><label class="correction-check"><input type="checkbox" data-edit-cash> Upravit zápis hotovosti</label><div class="correction-fields"><label class="correction-check"><input data-collected type="checkbox" ${cash?.operator_collected_confirmed?'checked':''}> Hotovost byla vybrána</label><label>Označení sáčku<input data-bag value="${esc(cash?.operator_bag_label)}"></label><label>Skutečně přepočítáno (Kč)<input data-cash type="number" min="0" step="0.01" value="${esc(cash?.supervisor_counted_cash_czk)}"></label></div><label>Poznámka k hotovosti<textarea data-cash-note>${esc(cash?.note)}</textarea></label></section>
  <section><label><strong>Důvod opravy</strong><textarea data-reason minlength="3" required placeholder="Co operátor potvrdil a proč zápis opravujeme"></textarea></label><p data-message role="status"></p></section>
  <footer><button type="button" data-close>Zrušit</button><button type="submit" class="primary">Uložit opravu a srovnat evidenci</button></footer>
  ${history.length?`<details><summary>Historie oprav (${history.length})</summary>${history.map(h=>`<details><summary>${esc(new Date(h.created_at).toLocaleString('cs-CZ'))} · ${esc([h.employees?.name,h.employees?.surname].filter(Boolean).join(' '))} · ${esc(h.reason)} · oprava #${h.id}</summary><ul>${historyChanges(h)}</ul></details>`).join('')}</details>`:''}</form>`
  const editState=()=>dialog.querySelectorAll('[data-item]').forEach(row=>row.querySelectorAll('input,select,textarea,button').forEach(el=>{if(!el.matches('[data-edit]'))el.disabled=!row.querySelector('[data-edit]').checked}))
  dialog.addEventListener('click',e=>{
   const button=e.target.closest('[data-add-fill]');if(!button)return
   const row=button.closest('[data-item]'),item=items.find(i=>String(i.id)===row.dataset.item)
   const f={id:nextFillId--,visit_item_id:item.id,product_id:item.actual_product_id||item.planned_product_id,product_name:item.actual_product_name||item.planned_product_name,quantity:0,sale_price_czk:item.sale_price_czk,correction_sources:[]}
   fills.push(f);button.insertAdjacentHTML('beforebegin',fillForm(f));updateImpacts()
  })
  dialog.addEventListener('change',editState);editState()
  const updateImpacts=()=>dialog.querySelectorAll('[data-fill]').forEach(el=>{const f=fills.find(f=>String(f.id)===el.dataset.fill),q=number(el.querySelector('[data-quantity]').value),same=String(f.product_id)===el.querySelector('[data-product]').value,d=q-f.quantity;el.querySelector('[data-impact]').textContent=same?(d===0?'Počet kusů beze změny.':d>0?`Automat +${d} ks, auto −${d} ks.`:`Automat ${d} ks, auto +${-d} ks.`):`Vrátí se evidence ${f.quantity} ks původního produktu do auta a zapíše se ${q} ks nového produktu do automatu.`})
  dialog.addEventListener('change',e=>{const row=e.target.closest('[data-fill]');if(row&&e.target.matches('[data-product]'))row.querySelector('[data-batch]').innerHTML=batchOptions(e.target.value,null);updateImpacts()})
  dialog.addEventListener('input',updateImpacts);updateImpacts()
  dialog.querySelector('form').addEventListener('submit',async e=>{
   e.preventDefault();const msg=dialog.querySelector('[data-message]'),submit=dialog.querySelector('[type=submit]');submit.disabled=true;msg.textContent='Ukládám opravu…'
   try{
    const patch={status:dialog.querySelector('[data-status]').value,note:dialog.querySelector('[data-note]').value,skip_reason:dialog.querySelector('[data-skip]').value,items:[]}
    for (const [key,selector] of [['arrived_at','[data-arrived]'],['completed_at','[data-completed]']]) {
      const raw=dialog.querySelector(selector).value
      if(raw!==localTime(visit[key]))patch[key]=raw?new Date(raw).toISOString():null
    }
    for(const row of dialog.querySelectorAll('[data-item]')){
     if(!row.querySelector('[data-edit]').checked)continue
     const item=items.find(i=>String(i.id)===row.dataset.item)
     const change={id:item.id,capacity:number(row.querySelector('[data-capacity]').value),before:number(row.querySelector('[data-before]').value),note:row.querySelector('[data-item-note]').value}
     if(item.item_kind==='food_slot')change.fills=[...row.querySelectorAll('[data-fill]')].map(el=>{
      const batch=batches.find(b=>String(b.id)===el.querySelector('[data-batch]').value)
      const q=number(el.querySelector('[data-quantity]').value)
      if(q>0&&!batch)throw Error('Vyber šarži u každého doplnění, které opravuješ.')
      return {id:Number(el.dataset.fill),product_id:number(el.querySelector('[data-product]').value),quantity:q,batch_id:batch?.id||null,expiry:expiry(batch),price:number(el.querySelector('[data-price]').value)}
     });else change.added=number(row.querySelector('[data-added]').value)
     patch.items.push(change)
    }
    patch.wastes=[...dialog.querySelectorAll('[data-waste]')].filter(row=>row.querySelector('[data-edit-waste]')?.checked).map(row=>({id:Number(row.dataset.waste),quantity:number(row.querySelector('[data-waste-quantity]').value),reason:row.querySelector('[data-waste-reason]').value}))
    if(dialog.querySelector('[data-edit-cash]').checked)patch.cash={collected:dialog.querySelector('[data-collected]').checked,bag:dialog.querySelector('[data-bag]').value,counted:dialog.querySelector('[data-cash]').value,note:dialog.querySelector('[data-cash-note]').value}
    if(!patch.items.length&&!patch.wastes.length&&!patch.cash&&!('arrived_at' in patch)&&!('completed_at' in patch)&&patch.status===visit.status&&patch.note===(visit.operator_note||'')&&patch.skip_reason===(visit.skip_reason||''))throw Error('Označ položku k úpravě nebo změň zápis návštěvy.')
    await read(supabase.rpc('correct_route_visit_v50',{p_visit_id:visit.id,p_expected_revision:visit.correction_revision,p_expected_updated_at:visit.updated_at,p_reason:dialog.querySelector('[data-reason]').value,p_patch:patch}))
    dialog.close();await onSaved()
   }catch(error){msg.textContent=error.message||String(error);submit.disabled=false}
  })
 }catch(error){dialog.innerHTML=`<h2>Opravu nelze otevřít</h2><p>${esc(error.message||error)}</p><button data-close type="button">Zavřít</button>`}
}
