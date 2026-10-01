// Calendar arithmetic is independent of the browser's timezone.
export const dayNumber = s => Date.parse(`${s}T00:00:00Z`) / 86400000;
export const addDays = (s, n) => new Date((dayNumber(s) + n) * 86400000).toISOString().slice(0,10);
export function pragueDay(value = new Date()) {
  const parts = Object.fromEntries(new Intl.DateTimeFormat('en-GB', {timeZone:'Europe/Prague',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date(value)).map(p=>[p.type,p.value]));
  return `${parts.year}-${parts.month}-${parts.day}`;
}
export function pragueMidnight(s) {
  const utc = Date.parse(`${s}T00:00:00Z`);
  let candidate = utc;
  for(let i=0;i<3;i++) {
    const p=Object.fromEntries(new Intl.DateTimeFormat('en-GB',{timeZone:'Europe/Prague',year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',second:'2-digit',hourCycle:'h23'}).formatToParts(new Date(candidate)).map(p=>[p.type,p.value]));
    candidate += utc-Date.parse(`${p.year}-${p.month}-${p.day}T${p.hour}:${p.minute}:${p.second}Z`);
  }
  return new Date(candidate);
}
export function validateRange(r) {
  const valid = s => /^\d{4}-\d{2}-\d{2}$/.test(s || '') && Number.isFinite(dayNumber(s)) && addDays(s,0)===s;
  if(!r || !valid(r.from) || !valid(r.to) || r.from>r.to) throw new Error('Vyber platné období: datum Od nesmí být později než Do.');
  if(dayNumber(r.to)-dayNumber(r.from)>731) throw new Error('Vyber období nejvýše dvou let.');
  return r;
}
function shiftMonth(s,n) {
  const [y,m,d]=s.split('-').map(Number), first=new Date(Date.UTC(y,m-1+n,1));
  const end=new Date(Date.UTC(first.getUTCFullYear(),first.getUTCMonth()+1,0)).getUTCDate();
  first.setUTCDate(Math.min(d,end)); return first.toISOString().slice(0,10);
}
export function comparisonRange(r,mode,custom) {
  validateRange(r);
  if(mode==='none') return null;
  if(mode==='custom') return validateRange(custom);
  if(mode==='previous_period') {
    const n=dayNumber(r.to)-dayNumber(r.from)+1;
    return {from:addDays(r.from,-n),to:addDays(r.from,-1)};
  }
  if(mode==='previous_year') return {from:shiftMonth(r.from,-12),to:shiftMonth(r.to,-12)};
  if(mode==='previous_month') {
    const first=shiftMonth(r.from.slice(0,7)+'-01',-1);
    return {from:first,to:addDays(r.from.slice(0,7)+'-01',-1)};
  }
  return {from:shiftMonth(r.from,-1),to:shiftMonth(r.to,-1)};
}
export function mergeComparison(current,previous) {
  const now=new Map(current.map(r=>[r.key,r])), old=new Map(previous.map(r=>[r.key,r]));
  const numeric=['quantity','revenue','revenueNet','vatAmount','cash','cashless','unknown','events','cost','profit','margin','avgCost','vendsPerDay','machineCount','productCount','missingCost','vatFallback','unvaluedRevenue','unpricedQuantity'];
  return [...new Set([...now.keys(),...old.keys()])].map(key=>{
    const prev=old.get(key), row=now.get(key) || {...prev,...Object.fromEntries(numeric.map(k=>[k,0])),machines:new Set(),products:new Set(),_previousOnly:true};
    const result={...row};
    for(const [field,prefix] of [['quantity','Quantity'],['revenue','Revenue'],['revenueNet','RevenueNet'],['profit','Profit']]) {
      const before=prev ? prev[field] : 0;
      result['compare'+prefix]=before;
      result[field+'Delta']=row[field]==null || before==null ? null : row[field]-before;
    }
    result.changePercent=result.compareRevenue ? result.revenueDelta/result.compareRevenue*100 : null;
    return result;
  });
}
export function matchesFilter(value,query) {
  if(!query?.trim()) return true;
  const q=query.trim(), match=q.match(/^(>=|<=|>|<|=)\s*(-?\d+(?:[.,]\d+)?)$/);
  if(match && typeof value==='number') {
    const n=Number(match[2].replace(',','.'));
    return ({'>':value>n,'<':value<n,'>=':value>=n,'<=':value<=n,'=':value===n})[match[1]];
  }
  return String(value??'').toLocaleLowerCase('cs').includes(q.toLocaleLowerCase('cs'));
}
export function csvCell(value) {
  const v=typeof value==='number'?String(value).replace('.',','):String(value??'');
  return '"'+(typeof value==='string' && /^[\s]*[=+@-]/.test(v)?"'"+v:v).replaceAll('"','""')+'"';
}
