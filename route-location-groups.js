function normalizedToken(value) {
  return String(value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
}

function priorityRank(value) {
  const priority = String(value || 'normal').toLowerCase()
  if (['critical', 'sold_out', 'fixed_window'].includes(priority)) return 0
  if (['high', 'stockout_risk', 'urgent'].includes(priority)) return 1
  if (priority === 'normal') return 2
  return 3
}

export function routeLocationGroupKey(stop) {
  const locationId = stop?.locationId ?? stop?.location_id
  if (locationId !== null && locationId !== undefined && String(locationId).trim()) {
    return `location:${String(locationId).trim()}`
  }

  const latitude = Number(stop?.latitude)
  const longitude = Number(stop?.longitude)
  if (Number.isFinite(latitude) && Number.isFinite(longitude)) {
    return `coordinates:${latitude.toFixed(5)}:${longitude.toFixed(5)}`
  }

  const address = normalizedToken(stop?.address ?? stop?.address_snapshot)
  const city = normalizedToken(stop?.city ?? stop?.city_snapshot)
  if (address || city) return `address:${city}:${address}`

  const machineId = stop?.machineId ?? stop?.machine_id ?? stop?.id ?? stop?.key
  const label = normalizedToken(stop?.name || stop?.title || 'unknown-stop')
  return `single:${String(machineId || label)}`
}

export function groupRouteStopsByLocation(stops, options = {}) {
  const estimateServiceMinutes = options.estimateServiceMinutes || ((stop) => Number(stop?.estimatedServiceMinutes || stop?.estimated_service_minutes || 0))
  const groupsByKey = new Map()

  ;(Array.isArray(stops) ? stops : []).forEach((stop) => {
    const groupKey = routeLocationGroupKey(stop)
    if (!groupsByKey.has(groupKey)) groupsByKey.set(groupKey, { groupKey, members: [] })
    groupsByKey.get(groupKey).members.push(stop)
  })

  return [...groupsByKey.values()].map(({ groupKey, members }) => {
    const first = members[0]
    const strongest = [...members].sort((a, b) => priorityRank(a?.effectivePriority) - priorityRank(b?.effectivePriority))[0] || first
    const serviceWindows = [...new Set(members.map((member) => String(member?.serviceWindow || '').trim()).filter(Boolean))]
    const routeNotes = [...new Set(members.map((member) => String(member?.routeNote || '').trim()).filter(Boolean))]
    const groupId = `location-group:${groupKey}`

    return {
      ...first,
      id: groupId,
      key: groupId,
      machineId: null,
      stopKind: 'location_group',
      optimizationGroupKey: groupKey,
      name: first?.parentLocationName || first?.locationName || first?.name || 'Společná lokalita',
      estimatedServiceMinutes: members.reduce((sum, member) => sum + Math.max(0, Number(estimateServiceMinutes(member)) || 0), 0),
      effectivePriority: strongest?.effectivePriority || 'normal',
      serviceWindow: serviceWindows[0] || '',
      routeNote: routeNotes.join(' · '),
      openRequestCount: members.reduce((sum, member) => sum + Math.max(0, Number(member?.openRequestCount) || 0), 0),
      groupMembers: members,
    }
  })
}

export function expandGroupedRouteStops(orderedGroups, sourceGroups, options = {}) {
  const estimateServiceMinutes = options.estimateServiceMinutes || ((stop) => Number(stop?.estimatedServiceMinutes || stop?.estimated_service_minutes || 0))
  const legScale = Math.max(0, Number(options.legScale) || 1)
  const groups = Array.isArray(sourceGroups) ? sourceGroups : []

  return (Array.isArray(orderedGroups) ? orderedGroups : []).flatMap((orderedGroup) => {
    const key = orderedGroup?.optimizationGroupKey || routeLocationGroupKey(orderedGroup)
    const sourceGroup = groups.find((group) => (
      String(group.optimizationGroupKey || '') === String(key)
      || String(group.id || '') === String(orderedGroup?.id || '')
      || String(group.key || '') === String(orderedGroup?.key || '')
    ))
    if (!sourceGroup) throw new Error(`Optimalizace vrátila neznámou lokalitu ${String(orderedGroup?.name || orderedGroup?.id || '')}.`)

    const legDistanceMeters = Math.max(0, Number(
      orderedGroup?.googleLegDistanceMeters
      ?? (Number(orderedGroup?.distanceFromPreviousKm || 0) * 1000)
    ) || 0)
    const legDurationSeconds = Math.max(0, Number(
      orderedGroup?.googleLegDurationSeconds
      ?? (Number(orderedGroup?.driveMinutesFromPrevious || 0) * 60)
    ) || 0)

    return sourceGroup.groupMembers.map((member, memberIndex) => {
      const isFirstAtLocation = memberIndex === 0
      const memberDistanceMeters = isFirstAtLocation ? legDistanceMeters : 0
      const memberDurationSeconds = isFirstAtLocation ? legDurationSeconds : 0
      return {
        ...member,
        optimizationGroupKey: sourceGroup.optimizationGroupKey,
        locationGroupSize: sourceGroup.groupMembers.length,
        googleLegDistanceMeters: memberDistanceMeters,
        googleLegDurationSeconds: memberDurationSeconds,
        distanceFromPreviousKm: memberDistanceMeters / 1000,
        driveMinutesFromPrevious: Math.round((memberDurationSeconds / 60) * legScale),
        estimatedServiceMinutes: Math.max(0, Number(estimateServiceMinutes(member)) || 0),
      }
    })
  })
}
