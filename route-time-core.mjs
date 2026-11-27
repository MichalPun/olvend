const MINUTE_MS = 60 * 1000
// A live forecast is tied to the exact set and order of remaining stops. Keep it
// for the working day instead of discarding it after a few minutes and falling
// back to a projection from the last completed stop.
const LIVE_RECALC_MAX_AGE_MS = 12 * 60 * MINUTE_MS

function asDate(value) {
  if (!value) return null
  const date = value instanceof Date ? new Date(value.getTime()) : new Date(value)
  return Number.isNaN(date.getTime()) ? null : date
}

function number(value, fallback = 0) {
  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : fallback
}

function minutesBetween(start, end, { signed = false } = {}) {
  const from = asDate(start)
  const to = asDate(end)
  if (!from || !to || (!signed && to < from)) return null
  const value = Math.round((to.getTime() - from.getTime()) / MINUTE_MS)
  return signed ? value : Math.max(0, value)
}

function stopIsClosed(stop) {
  return ['done', 'completed', 'skipped'].includes(String(stop?.status || '').toLowerCase())
    || Boolean(stop?.completedAt || stop?.skippedAt)
}

function sameOrder(left, right) {
  return left.length === right.length && left.every((value, index) => String(value) === String(right[index]))
}

function normalizeRecalculation(recalculation, openStopIds, now) {
  if (!recalculation || !Array.isArray(recalculation.stop_schedule)) return null
  const scheduleIds = recalculation.stop_schedule.map((item) => item.stop_id).filter((value) => value != null)
  const updatedAt = asDate(recalculation.updated_at)
  const estimatedReturnAt = asDate(recalculation.estimated_return_at)
  if (!sameOrder(scheduleIds, openStopIds) || !updatedAt || !estimatedReturnAt) return null
  const ageMs = Math.max(0, now.getTime() - updatedAt.getTime())
  if (ageMs > LIVE_RECALC_MAX_AGE_MS) return null
  return { ...recalculation, updatedAt, estimatedReturnAt, ageMs }
}

function haversineKm(left, right) {
  const lat1 = number(left?.latitude, NaN)
  const lon1 = number(left?.longitude, NaN)
  const lat2 = number(right?.latitude, NaN)
  const lon2 = number(right?.longitude, NaN)
  if (![lat1, lon1, lat2, lon2].every(Number.isFinite)) return 0
  const radians = (value) => value * Math.PI / 180
  const dLat = radians(lat2 - lat1)
  const dLon = radians(lon2 - lon1)
  const a = Math.sin(dLat / 2) ** 2
    + Math.cos(radians(lat1)) * Math.cos(radians(lat2)) * Math.sin(dLon / 2) ** 2
  return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}

function getGoogleLegs(stops, googleStops, plannedDriveMinutes, returnToStart, startPoint) {
  const stopIds = stops.map((stop) => String(stop.machineId ?? ''))
  const googleIds = googleStops.map((stop) => String(stop.machineId ?? stop.id ?? ''))
  const exactOrder = googleStops.length === stops.length
    && stopIds.every((id, index) => id && id === googleIds[index])
  if (exactOrder) {
    const legs = googleStops.map((stop) => Math.max(0, number(stop.googleLegDurationSeconds) / 60))
    const returnMinutes = returnToStart
      ? Math.max(0, plannedDriveMinutes - legs.reduce((sum, value) => sum + value, 0))
      : 0
    return { legs, returnMinutes, exact: true }
  }
  const points = [startPoint, ...stops]
  const weights = stops.map((stop, index) => haversineKm(points[index], stop))
  const returnWeight = returnToStart && stops.length ? haversineKm(stops[stops.length - 1], startPoint) : 0
  const totalWeight = weights.reduce((sum, value) => sum + value, 0) + returnWeight
  if (totalWeight > 0 && plannedDriveMinutes > 0) {
    return {
      legs: weights.map((weight) => plannedDriveMinutes * weight / totalWeight),
      returnMinutes: returnToStart ? plannedDriveMinutes * returnWeight / totalWeight : 0,
      exact: false,
    }
  }
  const legCount = Math.max(1, stops.length + (returnToStart ? 1 : 0))
  const fallback = Math.max(0, plannedDriveMinutes) / legCount
  return {
    legs: stops.map(() => fallback),
    returnMinutes: returnToStart ? fallback : 0,
    exact: false,
  }
}

function buildSegments(stops, actualStart, now, googleLegs, preparationMinutes = 0) {
  const segments = []
  let previousDeparture = actualStart
  let previousLabel = 'výjezd'
  let stoppedAtOpenStop = false

  stops.forEach((stop, index) => {
    const arrival = asDate(stop.arrivedAt)
    const completed = asDate(stop.completedAt || stop.skippedAt)
    const label = stop.label || `Zastávka ${index + 1}`
    // Route started_at vzniká už při zahájení trasy, tedy před ranní přípravou.
    // Přípravu proto připočítáváme k prvnímu úseku; jinak by se celý přehled
    // systematicky tvářil o plánovanou přípravu pomalejší.
    const plannedTravel = Math.max(0, number(googleLegs[index])) + (index === 0 ? preparationMinutes : 0)
    if (arrival && previousDeparture) {
      const actualTravel = minutesBetween(previousDeparture, arrival)
      segments.push({
        type: 'travel',
        label: `${previousLabel} → ${label}`,
        actualMinutes: actualTravel,
        plannedMinutes: plannedTravel,
        deltaMinutes: actualTravel == null ? null : Math.round(actualTravel - plannedTravel),
        completed: true,
      })
    }
    if (arrival) {
      const serviceEnd = completed || now
      const actualService = minutesBetween(arrival, serviceEnd)
      const plannedService = Math.max(0, number(stop.serviceMinutes))
      segments.push({
        type: 'service',
        label,
        actualMinutes: actualService,
        plannedMinutes: plannedService,
        deltaMinutes: actualService == null ? null : Math.round(actualService - plannedService),
        completed: Boolean(completed),
      })
      if (completed) {
        previousDeparture = completed
        previousLabel = label
      } else {
        previousDeparture = null
        stoppedAtOpenStop = true
      }
    }
  })

  if (!stoppedAtOpenStop && previousDeparture) {
    const nextIndex = stops.findIndex((stop) => !stopIsClosed(stop) && !stop.arrivedAt)
    if (nextIndex >= 0) {
      const actualTravel = minutesBetween(previousDeparture, now)
      const next = stops[nextIndex]
      segments.push({
        type: 'travel',
        label: `${previousLabel} → ${next.label || `Zastávka ${nextIndex + 1}`}`,
        actualMinutes: actualTravel,
        plannedMinutes: Math.max(0, number(googleLegs[nextIndex])) + (nextIndex === 0 ? preparationMinutes : 0),
        deltaMinutes: actualTravel == null ? null : Math.round(actualTravel - (Math.max(0, number(googleLegs[nextIndex])) + (nextIndex === 0 ? preparationMinutes : 0))),
        completed: false,
      })
    }
  }
  return segments
}

function summarizeSegments(segments, actualElapsedMinutes) {
  const typed = (type) => segments.filter((segment) => segment.type === type)
  const actual = (type) => typed(type).reduce((sum, segment) => sum + Math.max(0, number(segment.actualMinutes)), 0)
  // Probíhající úsek nesmí vytvářet falešnou zápornou odchylku jen proto,
  // že jeho plánovaný čas ještě celý neuplynul.
  const planned = (type) => typed(type).reduce((sum, segment) => {
    const actualMinutes = Math.max(0, number(segment.actualMinutes))
    const plannedMinutes = Math.max(0, number(segment.plannedMinutes))
    return sum + (segment.completed ? plannedMinutes : Math.min(actualMinutes, plannedMinutes))
  }, 0)
  const travelActualMinutes = actual('travel')
  const travelPlannedMinutes = planned('travel')
  const serviceActualMinutes = actual('service')
  const servicePlannedMinutes = planned('service')
  const accounted = travelActualMinutes + serviceActualMinutes
  const unclassifiedMinutes = actualElapsedMinutes == null ? 0 : Math.max(0, actualElapsedMinutes - accounted)
  const overruns = segments
    .filter((segment) => number(segment.deltaMinutes) > 0)
    .sort((a, b) => number(b.deltaMinutes) - number(a.deltaMinutes))
  return {
    travelActualMinutes,
    travelPlannedMinutes,
    travelDeltaMinutes: Math.round(travelActualMinutes - travelPlannedMinutes),
    serviceActualMinutes,
    servicePlannedMinutes,
    serviceDeltaMinutes: Math.round(serviceActualMinutes - servicePlannedMinutes),
    unclassifiedMinutes,
    overruns,
  }
}

export function calculateCanonicalRouteTiming(input) {
  const now = asDate(input.now) || new Date()
  const stops = [...(input.stops || [])].sort((a, b) => number(a.order) - number(b.order))
  const plannedDriveMinutes = Math.max(0, number(input.plannedDriveMinutes))
  const stopServiceMinutes = stops.reduce((sum, stop) => sum + Math.max(0, number(stop.serviceMinutes)), 0)
  const plannedServiceMinutes = Math.max(0, number(input.plannedServiceMinutes, stopServiceMinutes) || stopServiceMinutes)
  const preparationMinutes = Math.max(0, number(input.preparationMinutes))
  const plannedStart = asDate(input.plannedStart)
  const plannedFieldMinutes = preparationMinutes + plannedDriveMinutes + plannedServiceMinutes
  const plannedEnd = plannedStart
    ? new Date(plannedStart.getTime() + plannedFieldMinutes * MINUTE_MS)
    : null
  const firstArrival = stops.map((stop) => asDate(stop.arrivedAt)).find(Boolean) || null
  const actualStart = asDate(input.startedAt) || firstArrival
  const completedAt = asDate(input.completedAt)
  const actualEnd = completedAt || (actualStart ? now : null)
  const actualElapsedMinutes = minutesBetween(actualStart, actualEnd)
  const openStops = stops.filter((stop) => !stopIsClosed(stop))
  const openStopIds = openStops.map((stop) => stop.id)
  const recalculation = normalizeRecalculation(input.recalculation, openStopIds, now)
  const google = getGoogleLegs(
    stops,
    input.googleStops || [],
    plannedDriveMinutes,
    input.returnToStart !== false,
    { latitude: input.startLatitude, longitude: input.startLongitude },
  )
  const segments = actualStart ? buildSegments(stops, actualStart, now, google.legs, preparationMinutes) : []
  const breakdown = summarizeSegments(segments, actualElapsedMinutes)

  let forecastEnd = completedAt || null
  let forecastSource = completedAt ? 'actual' : 'none'
  if (!forecastEnd && actualStart && recalculation) {
    forecastEnd = recalculation.estimatedReturnAt
    forecastSource = 'google_live'
  }
  if (!forecastEnd && actualStart) {
    const lastClosedAt = [...stops].reverse().map((stop) => asDate(stop.completedAt || stop.skippedAt)).find(Boolean)
    const activeStop = stops.find((stop) => stop.arrivedAt && !stopIsClosed(stop))
    let cursor = activeStop ? now : (lastClosedAt || actualStart)
    let remainingMinutes = 0
    openStops.forEach((stop) => {
      const index = stops.indexOf(stop)
      if (!stop.arrivedAt) remainingMinutes += Math.max(0, number(google.legs[index]))
      remainingMinutes += stop.arrivedAt
        ? Math.max(0, number(stop.serviceMinutes) - number(minutesBetween(stop.arrivedAt, now)))
        : Math.max(0, number(stop.serviceMinutes))
    })
    remainingMinutes += google.returnMinutes
    forecastEnd = new Date(cursor.getTime() + remainingMinutes * MINUTE_MS)
    forecastSource = google.exact ? 'stored_google' : 'fallback'
  }
  if (!forecastEnd) forecastEnd = plannedEnd

  const projectedFieldMinutes = actualStart && forecastEnd ? minutesBetween(actualStart, forecastEnd) : null
  const deviationMinutes = projectedFieldMinutes == null ? null : Math.round(projectedFieldMinutes - plannedFieldMinutes)
  const trafficSeconds = Math.max(0, number(recalculation?.duration_seconds))
  const staticSeconds = Math.max(0, number(recalculation?.static_duration_seconds))
  const liveTrafficDelayMinutes = trafficSeconds && staticSeconds
    ? Math.max(0, Math.round((trafficSeconds - staticSeconds) / 60))
    : null

  return {
    now,
    plannedStart,
    plannedEnd,
    actualStart,
    actualEnd,
    forecastEnd,
    forecastSource,
    plannedFieldMinutes,
    projectedFieldMinutes,
    deviationMinutes,
    actualElapsedMinutes,
    preparationMinutes,
    plannedDriveMinutes,
    plannedServiceMinutes,
    breakdown,
    segments,
    recalculation,
    liveTrafficDelayMinutes,
    googleOrderExact: google.exact,
    openStopIds,
  }
}

export function routeTimingStatus(diff, tolerance = 10) {
  if (diff == null) return { cls: 'neutral', label: 'Čeká' }
  const rounded = Math.round(diff)
  if (Math.abs(rounded) <= tolerance) return { cls: 'good', label: 'Podle plánu' }
  return rounded > 0
    ? { cls: 'bad', label: `+${rounded} min` }
    : { cls: 'warn', label: `${rounded} min` }
}

export { minutesBetween, sameOrder }
