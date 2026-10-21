/**
 * Shared route and stop lifecycle rules for the mobile application.
 *
 * Coffee and food screens use the same ordered stops and visit status. Keeping
 * that decision here prevents the two workflows from drifting apart.
 */
export function createRouteDomain({
  getRoutePlans,
  getVisits,
  getAddRequests,
  getMachine,
  getTodayIso
}) {
  function getAssignedRoutePlan() {
    const activeStatuses = ['assigned', 'in_progress', 'started', 'open', 'draft']
    const doneStatuses = ['done', 'completed']
    const todayPlans = getRoutePlans().filter((plan) => (
      String(plan.planning_date || '') === String(getTodayIso())
      && String(plan.execution_status || '') !== 'cancelled'
    ))
    return todayPlans.find((plan) => activeStatuses.includes(String(plan.execution_status || 'assigned')))
      || todayPlans.find((plan) => doneStatuses.includes(String(plan.execution_status || '')))
      || todayPlans[0]
      || null
  }

  function getRouteVisitForStop(stop) {
    return getVisits().find((visit) => String(visit.route_plan_stop_id || '') === String(stop?.id || ''))
      || getVisits().find((visit) => (
        String(visit.machine_id || '') === String(stop?.machine_id || '')
        && String(visit.route_plan_id || '') === String(stop?.route_plan_id || '')
      ))
      || null
  }

  function getRouteStopStatus(stop) {
    const visit = getRouteVisitForStop(stop)
    if (visit?.status === 'completed' || ['done', 'completed'].includes(String(stop?.status || '')) || stop?.completed_at) return 'completed'
    if (visit?.status === 'skipped' || stop?.status === 'skipped') return 'skipped'
    if (visit?.status === 'arrived' || stop?.status === 'arrived' || stop?.arrived_at) return 'arrived'
    return 'pending'
  }

  function isRouteStopClosed(stop) {
    return ['completed', 'skipped'].includes(getRouteStopStatus(stop))
  }

  function getRouteStops(plan) {
    const stops = Array.isArray(plan?.route_plan_stops) ? plan.route_plan_stops : []
    const ordered = [...stops].sort((a, b) => Number(a.stop_order || 0) - Number(b.stop_order || 0))
    if (ordered.some((stop) => !isRouteStopClosed(stop) && getRouteStopStatus(stop) === 'arrived')) return ordered

    const pinnedRequest = getAddRequests()
      .filter((request) => (
        String(request.route_plan_id || '') === String(plan?.id || '')
        && request.status === 'approved'
        && request.added_route_plan_stop_id
      ))
      .sort((a, b) => String(b.decided_at || b.requested_at || '').localeCompare(String(a.decided_at || a.requested_at || '')))
      .find((request) => ordered.some((stop) => (
        String(stop.id) === String(request.added_route_plan_stop_id)
        && !isRouteStopClosed(stop)
      )))
    if (!pinnedRequest) return ordered

    const pinnedId = String(pinnedRequest.added_route_plan_stop_id)
    const closed = ordered.filter(isRouteStopClosed)
    const open = ordered.filter((stop) => !isRouteStopClosed(stop))
    const pinned = open.find((stop) => String(stop.id) === pinnedId)
    return pinned ? [...closed, pinned, ...open.filter((stop) => String(stop.id) !== pinnedId)] : ordered
  }

  function getRouteStopLocationKey(stop) {
    const machine = getMachine(stop)
    const locationId = stop?.location_id ?? machine?.location_id
    return locationId != null && String(locationId) !== '' ? `location:${locationId}` : `stop:${stop?.id || ''}`
  }

  function getCurrentRouteLocationStops(plan) {
    const stops = getRouteStops(plan)
    const firstOpen = stops.find((stop) => !isRouteStopClosed(stop))
    if (!firstOpen) return []
    const locationKey = getRouteStopLocationKey(firstOpen)
    return stops.filter((stop) => !isRouteStopClosed(stop) && getRouteStopLocationKey(stop) === locationKey)
  }

  function isCurrentRouteLocationStop(plan, stop) {
    return getCurrentRouteLocationStops(plan).some((item) => String(item.id) === String(stop?.id))
  }

  function findRouteStop(stopId) {
    for (const plan of getRoutePlans()) {
      const stop = getRouteStops(plan).find((item) => String(item.id) === String(stopId))
      if (stop) return { plan, stop }
    }
    return { plan: null, stop: null }
  }

  return {
    findRouteStop,
    getAssignedRoutePlan,
    getCurrentRouteLocationStops,
    getRouteStopLocationKey,
    getRouteStops,
    getRouteStopStatus,
    getRouteVisitForStop,
    isCurrentRouteLocationStop,
    isRouteStopClosed
  }
}

export async function ensureRouteVisitRecord({
  client,
  plan,
  stop,
  machine,
  existing,
  employeeId,
  vehicleId,
  visitDate,
  machineKind,
  nowIso = new Date().toISOString()
}) {
  if (!client?.from) throw new Error('Databázové připojení pro návštěvu není dostupné.')
  if (!plan?.id || !stop?.id || !machine?.id) throw new Error('Zastávka nemá jednoznačně navázaný automat.')

  if (existing?.id) {
    if (existing.status !== 'completed' && !existing.arrived_at) {
      const { error } = await client
        .from('route_machine_visits')
        .update({ status: 'arrived', arrived_at: nowIso, synced_at: nowIso })
        .eq('id', existing.id)
      if (error) throw error
    }
    return existing.id
  }

  const { data, error } = await client
    .from('route_machine_visits')
    .insert([{
      route_plan_id: plan.id,
      route_plan_stop_id: stop.id,
      machine_id: machine.id,
      employee_id: employeeId || null,
      vehicle_id: vehicleId || null,
      visit_date: visitDate,
      machine_kind: machineKind,
      status: 'arrived',
      arrived_at: nowIso,
      offline_created_at: nowIso,
      synced_at: nowIso
    }])
    .select('id')
    .single()
  if (error) throw error
  if (!data?.id) throw new Error('Server nepotvrdil vytvoření návštěvy.')
  return data.id
}
