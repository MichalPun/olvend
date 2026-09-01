const now = new Date()
const iso = now.toISOString()
const localDate = new Intl.DateTimeFormat('en-CA', { timeZone:'Europe/Prague', year:'numeric', month:'2-digit', day:'2-digit' }).format(now)

const rows = {
  employees: [{ id:'emp-tech', auth_user_id:'auth-tech', name:'Petr', surname:'Technik', role:'technik', warehouse_id:1, active:true }],
  attendance_days: [{ id:7, employee_id:'emp-tech', attendance_date:localDate, status:'open', actual_start:new Date(now.getTime()-90*60000).toISOString(), actual_end:null, break_minutes:0, vehicle_id:2, start_warehouse_id:1 }],
  attendance_events: [{ id:1, attendance_day_id:7, employee_id:'emp-tech', event_type:'shift_start', event_time:new Date(now.getTime()-90*60000).toISOString() }],
  vehicle_operation_logs: [{ id:3, attendance_day_id:7, vehicle_id:2, start_odometer_km:113822, status:'open', created_at:iso }],
  vehicles: [{ id:2, name:'Opel Combo', plate:'7Z7 1808', current_odometer_km:113822, warehouse_id:1, active:true }],
  locations: [{ id:10, name:'Sonepar Brno', city:'Brno' },{ id:20, name:'Sportisimo Modřice', city:'Modřice' },{ id:30, name:'RIGUM', city:'Brno' }],
  machines: [{ id:100, evidence_number:'58', machine_type:'Kávový automat', location_id:10 },{ id:200, evidence_number:'99', machine_type:'Potravinový automat', location_id:20 }],
  service_requests: [{ id:51, assigned_employee_id:'emp-tech', location_id:10, machine_id:100, title:'Neteče voda', description:'Kontrola přívodu', priority:'high', status:'done', created_at:iso, resolved_at:iso, service_result:'fixed', work_performed:'Vyčištěn ventil.' },{ id:52, assigned_employee_id:'emp-tech', location_id:20, machine_id:200, title:'Kontrola spirály 22', priority:'normal', status:'assigned', due_date:localDate, created_at:iso }],
  technical_jobs: [{ id:61, assigned_employee_id:'emp-tech', job_type:'transfer', status:'assigned', priority:'normal', title:'Přemístění automatu', description:'Převézt na nové místo', source_location_id:20, target_location_id:30, machine_id:200, planned_date:localDate, active:true, service_request_id:null, created_at:iso }],
  technician_day_plan_items: [{ id:1, plan_date:localDate, employee_id:'emp-tech', source_type:'service_request', source_id:51, sort_order:1 },{ id:2, plan_date:localDate, employee_id:'emp-tech', source_type:'technical_job', source_id:61, sort_order:2 },{ id:3, plan_date:localDate, employee_id:'emp-tech', source_type:'service_request', source_id:52, sort_order:3 }],
  technical_job_checklist_items: [],
  stock_locations: [{ id:80, name:'Opel Combo · 7Z7 1808', location_type:'vehicle', vehicle_id:2, active:true }],
  products: [{ id:300, name:'Ventil přívodu vody', sku:'SERV-VENTIL', base_unit:'ks', product_category:'service_material', active:true }],
  stock_location_balances: [{ id:400, stock_location_id:80, product_id:300, batch_id:null, quantity_on_hand:2, reserved_quantity:0 }]
}

class Query {
  constructor(table){ this.table=table; this.filters=[]; this.mode='select'; this.payload=null; this.singleMode=false; this.limitCount=null }
  select(){ return this }
  eq(key,value){ this.filters.push(row=>String(row[key])===String(value)); return this }
  is(key,value){ this.filters.push(row=>row[key]===value); return this }
  gt(key,value){ this.filters.push(row=>Number(row[key])>Number(value)); return this }
  in(key,values){ this.filters.push(row=>values.map(String).includes(String(row[key]))); return this }
  or(){ return this }
  order(){ return this }
  limit(value){ this.limitCount=value; return this }
  maybeSingle(){ this.singleMode=true; return this }
  single(){ this.singleMode=true; return this }
  update(payload){ this.mode='update'; this.payload=payload; return this }
  insert(payload){ this.mode='insert'; this.payload=payload; return this }
  upsert(payload){ this.mode='upsert'; this.payload=payload; return this }
  async result(){
    let data=[...(rows[this.table]||[])].filter(row=>this.filters.every(filter=>filter(row)))
    if(this.mode==='update'){ data=data.map(row=>Object.assign(row,this.payload)); return {data:this.singleMode?data[0]||null:data,error:null} }
    if(this.mode==='insert'){ const additions=Array.isArray(this.payload)?this.payload:[this.payload]; rows[this.table]=[...(rows[this.table]||[]),...additions]; return {data:additions,error:null} }
    if(this.mode==='upsert'){ const item=this.payload; rows[this.table]=[item]; data=[item] }
    if(this.limitCount!=null)data=data.slice(0,this.limitCount)
    return {data:this.singleMode?data[0]||null:data,error:null}
  }
  then(resolve,reject){ return this.result().then(resolve,reject) }
}

export const supabase = {
  auth:{ getSession:async()=>({data:{session:{user:{id:'auth-tech'}}},error:null}), signOut:async()=>({error:null}) },
  from(table){ return new Query(table) },
  rpc:async()=>({data:{inserted:1},error:null})
}
