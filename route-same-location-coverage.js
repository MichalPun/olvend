function locationKey(candidate) {
  const locationId = candidate?.locationId ?? candidate?.location_id
  return locationId == null || locationId === '' ? '' : String(locationId)
}

function isMachineCandidate(candidate) {
  return candidate?.machineId != null || candidate?.machine_id != null
}

export function getActionableSameLocationSiblings(candidate, candidates = [], options = {}) {
  if (!isMachineCandidate(candidate)) return []
  const targetLocationKey = locationKey(candidate)
  if (!targetLocationKey) return []

  const isActionable = options.isActionable || (() => false)
  const isAvailable = options.isAvailable || (() => true)

  return candidates.filter((other) => (
    isMachineCandidate(other)
    && String(other?.key || '') !== String(candidate?.key || '')
    && locationKey(other) === targetLocationKey
    && isActionable(other)
    && isAvailable(other)
  ))
}

export function getSameLocationCoverageGaps(candidates = [], selectedKeys = new Set(), options = {}) {
  const selected = selectedKeys instanceof Set ? selectedKeys : new Set(selectedKeys || [])
  const isActionable = options.isActionable || (() => false)
  const isAvailable = options.isAvailable || (() => true)
  const selectedLocationKeys = new Set(
    candidates
      .filter((candidate) => isMachineCandidate(candidate) && selected.has(String(candidate.key)))
      .map(locationKey)
      .filter(Boolean)
  )

  return candidates.filter((candidate) => (
    isMachineCandidate(candidate)
    && selectedLocationKeys.has(locationKey(candidate))
    && !selected.has(String(candidate.key))
    && isActionable(candidate)
    && isAvailable(candidate)
  ))
}
