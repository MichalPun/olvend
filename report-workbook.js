import {matchesFilter,csvCell} from './report-core.js';
import {columnLetter} from './report-xlsx.js';
const esc=v=>String(v??'').replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
const number=v=>Number(v).toLocaleString('cs-CZ',{maximumFractionDigits:2});
export function createWorkbook({head,body,foot,toolbar,status,onOutput,onOpen}) {
  let columns=[],source=[],visible=[],filters={},hidden=new Set(),sort='',ascending=false,limit=200,anchor=null,end=null,view='',dragging=false;
  const value=(r,c)=>c.csv?c.csv(r):r[c.key];
  const additive=new Set(['quantity','revenue','revenueNet','cash','cashless','unknown','cost','profit','compareRevenue','compareQuantity','revenueDelta','quantityDelta','profitDelta','costDelta','movements','total_amount_czk','cash_amount_czk','cashless_amount_czk','compareRevenueNet','revenueNetDelta']);
  const cols=()=>columns.filter(c=>!hidden.has(c.key));
  function select(){
    const cs=cols(),nums=[];let count=0;
    body.querySelectorAll('[data-cell]').forEach(el=>{const [r,c]=el.dataset.cell.split(':').map(Number),picked=anchor&&end&&r>=Math.min(anchor[0],end[0])&&r<=Math.max(anchor[0],end[0])&&c>=Math.min(anchor[1],end[1])&&c<=Math.max(anchor[1],end[1]);el.classList.toggle('selected-cell',!!picked);if(picked){count++;const v=value(visible[r],cs[c]);if(typeof v==='number'&&Number.isFinite(v))nums.push(v);}});
    const formula=document.getElementById('cellValue'),address=document.getElementById('cellAddress');
    if(address)address.textContent=anchor?columnLetter(anchor[1])+(anchor[0]+3):'—';
    if(formula)formula.textContent=anchor?String(value(visible[anchor[0]],cs[anchor[1]])??'—'):'Vyber buňku; Shift + klik vybere rozsah. Dvojklik otevře prodeje řádku.';
    status.textContent=anchor?`Vybráno ${count} buněk${nums.length?' · Součet '+number(nums.reduce((a,b)=>a+b,0))+' · Průměr '+number(nums.reduce((a,b)=>a+b,0)/nums.length):''}`:`${visible.length} řádků po filtrech · součty zahrnují všechny filtrované řádky`;
  }
  function renderBody(){
    const cs=cols();
    visible=source.filter(r=>columns.every(c=>matchesFilter(value(r,c),filters[c.key])));
    if(sort){const col=columns.find(c=>c.key===sort);if(col)visible.sort((a,b)=>{const av=value(a,col),bv=value(b,col);if(av==null)return bv==null?0:1;if(bv==null)return -1;return(typeof av==='number'&&typeof bv==='number'?av-bv:String(av).localeCompare(String(bv),'cs',{numeric:true}))*(ascending?1:-1);});}
    anchor=end=null;
    body.innerHTML=visible.slice(0,limit).map((r,i)=>`<tr><th class="row-number" scope="row">${i+3}</th>${cs.map((c,j)=>`<td tabindex="0" data-cell="${i}:${j}" class="${c.num?'num ':''}${j===0?'frozen-cell':''}" title="${esc(value(r,c))}">${value(r,c)==null?'—':c.render(r)}</td>`).join('')}</tr>`).join('')||`<tr><td colspan="${cs.length+1}">Žádné řádky odpovídající filtrům.</td></tr>`;
    foot.innerHTML=`<tr><th class="row-number">Σ</th>${cs.map((c,i)=>{let total='';if(i===0)total='Celkem';else if(additive.has(c.key)){const values=visible.map(r=>value(r,c));total=values.some(v=>v==null)?'Neúplné':number(values.reduce((sum,v)=>sum+Number(v||0),0));}else if(c.key==='share')total=number(visible.reduce((sum,r)=>sum+Number(value(r,c)||0),0))+' %';return `<td class="${c.num?'num':''}">${esc(total)}</td>`;}).join('')}</tr>`;
    const totals=cs.filter(c=>additive.has(c.key)).map(c=>{const values=visible.map(r=>value(r,c));return [c.label,values.some(v=>v==null)?'Neúplné':values.reduce((sum,v)=>sum+Number(v||0),0)];});
    onOutput(visible.map(r=>Object.fromEntries(cs.map(c=>[c.label,value(r,c)]))),visible,{totals,filters:columns.filter(c=>filters[c.key]).map(c=>[c.label,filters[c.key]])});
    document.getElementById('rowCount').textContent=`${Math.min(limit,visible.length)} z ${visible.length} řádků`;
    const more=toolbar.querySelector('[data-more]');if(more)more.hidden=visible.length<=limit;
    select();
  }
  function render(){
    const cs=cols();
    head.innerHTML=`<tr class="column-letters"><th class="row-number"></th>${cs.map((c,i)=>`<th>${columnLetter(i)}</th>`).join('')}</tr><tr class="column-titles"><th class="row-number">1</th>${cs.map(c=>`<th aria-sort="${sort===c.key?(ascending?'ascending':'descending'):'none'}"><button type="button" data-sort="${esc(c.key)}">${esc(c.label)} <span>${sort===c.key?(ascending?'↑':'↓'):'↕'}</span></button></th>`).join('')}</tr><tr class="column-filters"><th class="row-number">2</th>${cs.map(c=>`<th><input data-filter="${esc(c.key)}" aria-label="Filtr ${esc(c.label)}" placeholder="${c.num?'>100':'Filtrovat…'}" value="${esc(filters[c.key]||'')}"></th>`).join('')}</tr>`;
    head.querySelectorAll('[data-sort]').forEach(b=>b.onclick=()=>{ascending=sort===b.dataset.sort?!ascending:!columns.find(c=>c.key===b.dataset.sort)?.num;sort=b.dataset.sort;render();});
    head.querySelectorAll('[data-filter]').forEach(input=>input.oninput=()=>{filters[input.dataset.filter]=input.value;limit=200;renderBody();});
    toolbar.innerHTML=`<button class="btn" type="button" data-clear>Vymazat filtry tabulky</button><details class="column-picker"><summary>Sloupce</summary><div>${columns.map((c,i)=>`<label><input type="checkbox" data-column="${esc(c.key)}" ${hidden.has(c.key)?'':'checked'} ${i===0?'disabled':''}>${esc(c.label)}</label>`).join('')}</div></details><button class="btn" type="button" data-more>Zobrazit dalších 200</button>`;
    toolbar.querySelector('[data-clear]').onclick=()=>{filters={};render();};
    toolbar.querySelector('[data-more]').onclick=()=>{limit+=200;renderBody();};
    toolbar.querySelectorAll('[data-column]').forEach(c=>c.onchange=()=>{c.checked?hidden.delete(c.dataset.column):hidden.add(c.dataset.column);delete filters[c.dataset.column];render();});
    renderBody();
  }
  body.addEventListener('pointerdown',e=>{const td=e.target.closest('[data-cell]');if(!td)return;const p=td.dataset.cell.split(':').map(Number);if(!e.shiftKey||!anchor)anchor=p;end=p;dragging=true;select();});
  body.addEventListener('pointerover',e=>{const td=e.target.closest('[data-cell]');if(dragging&&td){end=td.dataset.cell.split(':').map(Number);select();}});
  window.addEventListener('pointerup',()=>dragging=false);
  window.addEventListener('blur',()=>dragging=false);
  body.addEventListener('dblclick',e=>{const td=e.target.closest('[data-cell]');if(td)onOpen?.(visible[Number(td.dataset.cell.split(':')[0])]);});
  body.addEventListener('keydown',e=>{const td=e.target.closest('[data-cell]');if(!td)return;const pos=td.dataset.cell.split(':').map(Number),moves={ArrowDown:[1,0],ArrowUp:[-1,0],ArrowLeft:[0,-1],ArrowRight:[0,1]};if(moves[e.key]){e.preventDefault();const next=[Math.max(0,Math.min(Math.min(limit,visible.length)-1,pos[0]+moves[e.key][0])),Math.max(0,Math.min(cols().length-1,pos[1]+moves[e.key][1]))];if(!e.shiftKey||!anchor)anchor=e.shiftKey?pos:next;end=next;body.querySelector(`[data-cell="${next.join(':')}"]`)?.focus();select();}});
  body.addEventListener('copy',e=>{if(!anchor||!end)return;const cs=cols(),out=[];for(let i=Math.min(anchor[0],end[0]);i<=Math.max(anchor[0],end[0]);i++){const row=[];for(let j=Math.min(anchor[1],end[1]);j<=Math.max(anchor[1],end[1]);j++)row.push(csvCell(value(visible[i],cs[j])));out.push(row.join('\t'));}e.clipboardData.setData('text/plain',out.join('\n'));e.preventDefault();});
  return {set(nextColumns,rows,key){if(key!==view){view=key;filters={};hidden=new Set(nextColumns.filter(c=>c.hidden).map(c=>c.key));sort=nextColumns.some(c=>c.key==='revenue')?'revenue':'';ascending=false;limit=200;}columns=nextColumns;source=rows.filter(r=>!r._summary);render();},clear(){source=[];renderBody();}};
}
