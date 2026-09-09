// The RPC commits both vehicle logs and the attendance assignment together.
export function createVehicleShiftSwitch({ supabase, onSaved }) {
  const dialog = document.createElement('dialog')
  dialog.setAttribute('aria-labelledby', 'vehicleSwitchTitle')
  dialog.style.cssText = 'width:min(540px,calc(100vw - 32px));border:1px solid #ddd;border-radius:16px;padding:24px;color:#18212f'
  dialog.innerHTML = `
    <form style="display:grid;gap:16px">
      <h2 id="vehicleSwitchTitle" style="margin:0">Vyměnit auto ve směně</h2>
      <p data-summary style="margin:0"></p>
      <label style="display:grid;gap:6px">Konečný stav km původního auta
        <input name="endKm" type="number" min="0" step="1" required></label>
      <button type="button" data-plan class="btn secondary" hidden>Použít km podle plánu</button>
      <p data-source style="margin:0;font-size:13px"></p>
      <label style="display:grid;gap:6px">Nové vozidlo
        <select name="vehicle" required><option value="">Vyber vozidlo</option></select></label>
      <label style="display:grid;gap:6px">Počáteční stav km nového auta
        <input name="startKm" type="number" min="0" step="1" required></label>
      <label style="display:grid;gap:6px">Poznámka
        <input name="note" maxlength="1000" placeholder="Např. převzetí auta pro inventuru"></label>
      <p style="margin:0;font-size:13px">Původní výjezd se uzavře a začne nový. Směna pokračuje. Zásoby zůstávají ve svých autech.</p>
      <p data-error role="alert" style="margin:0;color:#b42318"></p>
      <div style="display:flex;gap:12px;justify-content:flex-end">
        <button type="button" data-cancel class="btn secondary">Zrušit</button>
        <button type="submit" class="btn">Uzavřít výjezd a přiřadit auto</button>
      </div>
    </form>`
  document.body.append(dialog)
  const form = dialog.querySelector('form')
  const field = (name) => form.elements.namedItem(name)
  const errorLine = dialog.querySelector('[data-error]')
  const sourceLine = dialog.querySelector('[data-source]')
  const planButton = dialog.querySelector('[data-plan]')
  let context = null
  let selectedPlan = null
  let saving = false
  dialog.querySelector('[data-cancel]').onclick = () => { if (!saving) dialog.close() }
  dialog.addEventListener('cancel', (event) => { if (saving) event.preventDefault() })
  field('endKm').addEventListener('input', () => {
    selectedPlan = null
    sourceLine.textContent = 'Zdroj km: ručně zadaný tachometr.'
  })
  planButton.onclick = () => {
    selectedPlan = context.plan
    field('endKm').value = Number(context.log.start_odometer_km) + Math.round(Number(selectedPlan.estimated_distance_km))
    sourceLine.textContent = `Odhad podle plánu: ${Number(selectedPlan.estimated_distance_km).toLocaleString('cs-CZ')} km, zaokrouhleno na celé km tachometru.`
  }
  field('vehicle').addEventListener('change', () => {
    const vehicle = context.vehicles.find((item) => String(item.id) === field('vehicle').value)
    field('startKm').value = vehicle?.current_odometer_km ?? ''
    field('startKm').min = vehicle?.current_odometer_km ?? 0
  })
  form.addEventListener('submit', async (event) => {
    event.preventDefault()
    if (saving || !context || !form.reportValidity()) return
    saving = true
    errorLine.textContent = ''
    const controls = [...form.querySelectorAll('input,select,button')]
    controls.forEach((control) => { control.disabled = true })
    let committed = false
    try {
      const { error } = await supabase.rpc('switch_shift_vehicle_v48', {
        p_attendance_day_id: context.day.id,
        p_previous_log_id: context.log.id,
        p_vehicle_id: Number(field('vehicle').value),
        p_end_odometer_km: Number(field('endKm').value),
        p_start_odometer_km: Number(field('startKm').value),
        p_route_plan_id: selectedPlan?.id ?? null,
        p_note: field('note').value.trim() || null
      })
      if (error) throw error
      committed = true
      dialog.close()
      await onSaved()
    } catch (error) {
      if (committed) {
        dialog.showModal()
        errorLine.textContent = 'Výměna je uložená, ale přehled se nepodařilo obnovit. Zavři dialog a obnov stránku.'
        context = null // Never resubmit a successful transaction.
      } else {
        errorLine.textContent = /PGRST202|schema cache|function.*not.*exist/i.test(`${error.code} ${error.message}`)
          ? 'Výměna auta ještě není na serveru připravená. Kontaktuj správce aplikace.'
          : error.message || 'Uložení se nepodařilo. Obnov přehled a zkontroluj stav výjezdů.'
      }
    } finally {
      saving = false
      controls.forEach((control) => { control.disabled = false })
      if (!context) form.querySelector('[type="submit"]').disabled = true
    }
  })
  return {
    async open(vehicle) {
      if (saving) return
      const { data: days, error: dayError } = await supabase.from('attendance_days')
        .select('id, employee_id, attendance_date, vehicle_id, actual_start, actual_end, status')
        .eq('vehicle_id', vehicle.id).is('actual_end', null).not('actual_start', 'is', null)
        .eq('attendance_date', new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Prague' }))
      if (dayError) throw dayError
      if (days?.length !== 1) throw new Error('Pro auto musí existovat právě jedna otevřená směna.')
      const day = days[0]
      const [logs, vehicles, plans, employee] = await Promise.all([
        supabase.from('vehicle_operation_logs').select('id, vehicle_id, start_odometer_km, end_odometer_km, status, ended_at')
          .eq('attendance_day_id', day.id).not('start_odometer_km', 'is', null),
        supabase.from('vehicles').select('id, name, plate, current_odometer_km').eq('active', true).neq('id', vehicle.id),
        supabase.from('route_plans').select('id, title, estimated_distance_km')
          .eq('planned_employee_id', day.employee_id).eq('planning_date', day.attendance_date)
          .eq('vehicle_id', vehicle.id).eq('execution_status', 'done'),
        supabase.from('employees').select('name, surname').eq('id', day.employee_id).single()
      ])
      for (const result of [logs, vehicles, plans, employee]) if (result.error) throw result.error
      const open = logs.data.filter((log) => log.status === 'open' && !log.ended_at)
      if (open.length !== 1 || String(open[0].vehicle_id) !== String(vehicle.id)) {
        throw new Error('Směna nemá jednoznačný otevřený výjezd tohoto auta.')
      }
      const log = open[0]
      const plan = plans.data.length === 1 && plans.data[0].estimated_distance_km != null
        && logs.data.filter((item) => String(item.vehicle_id) === String(vehicle.id)).length === 1
        && log.end_odometer_km == null ? plans.data[0] : null
      context = { day, log, vehicles: vehicles.data, plan }
      selectedPlan = null
      form.reset()
      form.querySelector('[type="submit"]').disabled = false
      errorLine.textContent = ''
      dialog.querySelector('[data-summary]').textContent = `${employee.data.name} ${employee.data.surname} · ${vehicle.name} · ${vehicle.plate} · start ${log.start_odometer_km.toLocaleString('cs-CZ')} km`
      field('endKm').value = log.end_odometer_km ?? ''
      field('endKm').min = Math.max(log.start_odometer_km, vehicle.current_odometer_km ?? 0)
      field('endKm').readOnly = log.end_odometer_km != null
      planButton.hidden = !plan
      sourceLine.textContent = log.end_odometer_km != null ? 'Konečný stav km je už uložený.' : 'Zadej tachometr nebo použij odhad podle dokončené trasy.'
      field('vehicle').replaceChildren(new Option('Vyber vozidlo', ''))
      vehicles.data.forEach((item) => field('vehicle').add(new Option(`${item.name} · ${item.plate}`, item.id)))
      dialog.showModal()
    }
  }
}
