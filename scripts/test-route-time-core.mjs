import assert from 'node:assert/strict'
import { calculateCanonicalRouteTiming } from '../route-time-core.mjs'

const base = {
  plannedStart: '2026-11-27T05:30:00+01:00',
  startedAt: '2026-11-27T05:40:00+01:00',
  plannedDriveMinutes: 120,
  plannedServiceMinutes: 40,
  preparationMinutes: 30,
  returnToStart: true,
  googleStops: [
    { id: 10, machineId: 10, googleLegDurationSeconds: 3600 },
    { id: 20, machineId: 20, googleLegDurationSeconds: 1800 },
  ],
  stops: [
    { id: 1, machineId: 10, order: 1, label: 'A', status: 'done', serviceMinutes: 20, arrivedAt: '2026-11-27T06:40:00+01:00', completedAt: '2026-11-27T07:05:00+01:00' },
    { id: 2, machineId: 20, order: 2, label: 'B', status: 'planned', serviceMinutes: 20 },
  ],
}

{
  const timing = calculateCanonicalRouteTiming({
    ...base,
    now: '2026-11-27T07:10:00+01:00',
    recalculation: {
      updated_at: '2026-11-27T07:08:00+01:00',
      estimated_return_at: '2026-11-27T09:10:00+01:00',
      duration_seconds: 4200,
      static_duration_seconds: 3600,
      stop_schedule: [{ stop_id: 2 }],
    },
  })
  assert.equal(timing.forecastSource, 'google_live')
  assert.equal(timing.projectedFieldMinutes, 210)
  assert.equal(timing.deviationMinutes, 20)
  assert.equal(timing.liveTrafficDelayMinutes, 10)
  assert.equal(timing.breakdown.travelDeltaMinutes, -30)
  assert.equal(timing.breakdown.serviceDeltaMinutes, 5)
}

{
  const timing = calculateCanonicalRouteTiming({
    ...base,
    now: '2026-11-27T07:10:00+01:00',
    recalculation: {
      updated_at: '2026-11-27T07:08:00+01:00',
      estimated_return_at: '2026-11-27T08:40:00+01:00',
      stop_schedule: [{ stop_id: 999 }],
    },
  })
  assert.notEqual(timing.forecastSource, 'google_live')
}

{
  const timing = calculateCanonicalRouteTiming({
    ...base,
    now: '2026-11-27T07:30:00+01:00',
    recalculation: {
      updated_at: '2026-11-27T07:00:00+01:00',
      estimated_return_at: '2026-11-27T08:40:00+01:00',
      stop_schedule: [{ stop_id: 2 }],
    },
  })
  assert.notEqual(timing.forecastSource, 'google_live')
}

console.log('route-time-core: ok')
