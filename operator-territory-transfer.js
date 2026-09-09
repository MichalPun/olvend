import { supabase } from './supabase.js';
const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const today = () => new Intl.DateTimeFormat('en-CA', {timeZone:'Europe/Prague',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());

export function openTerritoryTransfer({employees, locations, machines, onSaved}) {
  const dialog = document.createElement('dialog');
  dialog.className = 'territory-transfer';
  const name = id => { const e=employees.find(e=>String(e.id)===String(id)); return e ? `${e.name||''} ${e.surname||''}`.trim() : 'Bez operátora'; };
  const options = '<option value="">Vyberte operátora</option>'+employees.map(e=>`<option value="${esc(e.id)}">${esc(name(e.id))}</option>`).join('');
  dialog.innerHTML = `<form><header><h2>Předat rajón</h2><button type="button" data-close class="btn">Zavřít</button></header>
    <p>Vyberte datum, původního operátora a lokality. Můžete postupně připravit více předání a uložit je společně.</p>
    <div class="transfer-controls"><label>Platnost od<input name="date" type="date" min="${today()}" value="${today()}" required></label><label>Původní operátor<select name="source">${options}</select></label><label>Nový operátor<select name="target">${options}</select></label><label>Hledat město nebo lokalitu<input name="search" type="search" placeholder="Např. Bruntál"></label></div>
    <div data-editor><p><button class="btn" type="button" data-select>Vybrat zobrazené</button> <button class="btn" type="button" data-unselect>Zrušit výběr</button> <button class="btn primary" type="button" data-add>Přidat vybrané do návrhu</button></p><div class="transfer-scroll"><table><thead><tr><th>Vybrat</th><th>Lokalita / město</th><th>Operátor k datu předání</th><th>Automaty</th><th>Návrh</th></tr></thead><tbody data-rows></tbody></table></div></div>
    <section><h3>Návrh předání</h3><div data-draft>Žádné změny.</div><div data-counts></div></section>
    <label>Důvod předání<input name="reason" required minlength="3" placeholder="Např. předání rajónu po odchodu operátorky"></label>
    <p>Ukládá se odpovědnost za lokality a jejich stávající rozsah automatů. Náhradník zůstane zachován; pokud se stává hlavním operátorem, jeho role náhradníka se zruší. Již založené ani rozjeté trasy se tím nepřeřadí.</p>
    <p data-error role="alert"></p><footer><button class="btn" type="button" data-back hidden>Zpět k výběru</button><button class="btn primary" type="submit" disabled>Zkontrolovat předání</button></footer></form>`;
  document.body.append(dialog);
  const $=s=>dialog.querySelector(s), field=n=>dialog.querySelector(`[name="${n}"]`);
  let assignments=[], draft=new Map(), selected=new Set(), review=false, busy=false, loadVersion=0;
  const error=message=>{$('[data-error]').textContent=message;};
  const visible=()=>locations.filter(l=>{
    const a=assignments.find(a=>String(a.location_id)===String(l.id));
    return a && a.primary_employee_id && (!field('source').value || String(a.primary_employee_id)===field('source').value) && `${l.name} ${l.city} ${l.address}`.toLocaleLowerCase('cs').includes(field('search').value.trim().toLocaleLowerCase('cs'));
  });
  const machineCount=a=>a.assignment_scope==='machines' ? (a.selected_machine_ids||[]).length : machines.filter(m=>String(m.location_id)===String(a.location_id)).length;
  function render() {
    $('[data-rows]').innerHTML=visible().map(l=>{
      const a=assignments.find(a=>String(a.location_id)===String(l.id));
      return `<tr><td><input aria-label="Vybrat ${esc(l.name)}" type="checkbox" data-pick="${l.id}" ${selected.has(String(l.id))?'checked':''}></td><td><b>${esc(l.name)}</b><br>${esc(l.city)} · ${esc(l.address)}</td><td>${esc(name(a.primary_employee_id))}</td><td>${machineCount(a)}${a.assignment_scope==='machines'?' (část lokality)':''}</td><td>${draft.has(String(l.id))?esc(name(draft.get(String(l.id)).target_employee_id)):'—'}</td></tr>`;
    }).join('') || '<tr><td colspan="5">Žádné přiřazené lokality pro tento výběr.</td></tr>';
    $('[data-draft]').innerHTML=draft.size ? `<ul>${[...draft].map(([id,c])=>`<li>${esc(locations.find(l=>String(l.id)===id)?.name)}: ${esc(name(c.expected_owner_id))} → <b>${esc(name(c.target_employee_id))}</b> <button class="btn" type="button" data-remove="${id}" ${review?'hidden':''}>Odebrat</button></li>`).join('')}</ul>` : 'Žádné změny.';
    const counts=new Map();
    assignments.filter(a=>locations.some(l=>String(l.id)===String(a.location_id))).forEach(a=>{
      const before=String(a.primary_employee_id||''),after=draft.get(String(a.location_id))?.target_employee_id||before;
      for(const id of [before,after]) if(!counts.has(id))counts.set(id,{before:0,after:0,machinesBefore:0,machinesAfter:0});
      counts.get(before).before++; counts.get(before).machinesBefore+=machineCount(a);
      counts.get(after).after++; counts.get(after).machinesAfter+=machineCount(a);
    });
    $('[data-counts]').innerHTML=draft.size ? '<h3>Zatížení po předání</h3>'+[...counts].filter(([id,c])=>c.before!==c.after||[...draft.values()].some(d=>d.expected_owner_id===id||d.target_employee_id===id)).map(([id,c])=>`<p><b>${esc(name(id))}</b>: ${c.before} → ${c.after} lokalit, ${c.machinesBefore} → ${c.machinesAfter} automatů</p>`).join('') : '';
    $('[type="submit"]').disabled=busy||!draft.size;
    $('[type="submit"]').textContent=busy?'Ukládám…':review?`Uložit předání ${draft.size} lokalit`:'Zkontrolovat předání';
    $('[data-editor]').hidden=review;
    $('[data-back]').hidden=!review;
    for(const n of ['source','target','search','date'])field(n).disabled=review||busy;
  }
  async function reload() {
    const version=++loadVersion;
    assignments=[];draft.clear();selected.clear();busy=true;error('Načítám rozdělení k vybranému datu…');render();
    const {data,error:failure}=await supabase.rpc('get_operator_territories_v51',{p_date:field('date').value});
    if(version!==loadVersion||!dialog.isConnected)return;
    busy=false; assignments=data||[];error(failure?failure.message:'');render();
  }
  dialog.addEventListener('cancel',e=>{if(busy)e.preventDefault();});
  dialog.addEventListener('close',()=>dialog.remove());
  $('[data-close]').onclick=()=>{if(!busy)dialog.close();};
  field('date').onchange=reload;
  field('source').onchange=()=>{selected.clear();render();};
  field('search').oninput=()=>{selected.clear();render();};
  $('[data-select]').onclick=()=>{visible().forEach(l=>selected.add(String(l.id)));render();};
  $('[data-unselect]').onclick=()=>{selected.clear();render();};
  dialog.addEventListener('change',e=>{if(e.target.dataset.pick){const id=e.target.dataset.pick;e.target.checked?selected.add(id):selected.delete(id);}});
  dialog.addEventListener('click',e=>{if(e.target.dataset.remove&&!busy){draft.delete(e.target.dataset.remove);render();}});
  $('[data-add]').onclick=()=>{
    if(busy)return;
    const target=field('target').value;
    if(!target||!selected.size)return error('Vyberte nového operátora a alespoň jednu lokalitu.');
    const rows=assignments.filter(a=>selected.has(String(a.location_id)));
    if(rows.some(a=>String(a.primary_employee_id)===target))return error('Vybraná lokalita už tomuto operátorovi patří.');
    rows.forEach(a=>draft.set(String(a.location_id),{location_id:a.location_id,expected_owner_id:a.primary_employee_id,expected_updated_at:a.updated_at,target_employee_id:target}));
    selected.clear();error('');render();
  };
  $('[data-back]').onclick=()=>{if(!busy){review=false;render();}};
  $('form').onsubmit=async e=>{
    e.preventDefault();if(busy||!draft.size)return;
    if(!review){review=true;error('Zkontrolujte seznam, datum a výsledné rozdělení.');render();return;}
    busy=true;render();error('');
    const {error:failure}=await supabase.rpc('transfer_operator_territories_v51',{p_changes:[...draft.values()],p_effective_from:field('date').value,p_reason:field('reason').value});
    busy=false;
    if(failure){error(failure.message);render();return;}
    dialog.close();await onSaved(field('date').value);
  };
  dialog.showModal();reload();
}
