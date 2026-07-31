import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

export const supabaseUrl = 'https://rerjlkrhiytgscjerqgs.supabase.co'
export const supabaseAnonKey = 'sb_publishable_A8OxCcapdNXAzQLjLsW5iA_XtGvBZ0S'

const OFFLINE_QUEUE_KEY = 'olvendOfflineRequestQueueV1'

function readOfflineQueue() {
  try { return JSON.parse(localStorage.getItem(OFFLINE_QUEUE_KEY) || '[]') }
  catch (_) { return [] }
}

function writeOfflineQueue(queue) {
  localStorage.setItem(OFFLINE_QUEUE_KEY, JSON.stringify(queue))
  window.dispatchEvent(new CustomEvent('olvend-offline-queue', { detail: { pending: queue.length } }))
}

function canQueueRequest(url, init) {
  const method = String(init?.method || 'GET').toUpperCase()
  if (method === 'PATCH' || method === 'DELETE') return true
  if (method !== 'POST') return false
  const prefer = new Headers(init?.headers || {}).get('prefer') || ''
  return new URL(String(url), window.location.href).searchParams.has('on_conflict') && !prefer.includes('return=representation')
}

async function offlineAwareFetch(input, init = {}) {
  const request = input instanceof Request ? input : null
  const url = request?.url || String(input)
  const requestInit = {
    method: init.method || request?.method || 'GET',
    headers: init.headers || request?.headers,
    body: init.body
  }
  const controller = new AbortController()
  const timer = window.setTimeout(() => controller.abort(), 12000)
  try {
    return await fetch(input, { ...init, signal: init.signal || controller.signal })
  } catch (error) {
    if (!canQueueRequest(url, requestInit)) throw error
    const queue = readOfflineQueue()
    queue.push({
      id: crypto.randomUUID(),
      url,
      method: requestInit.method,
      headers: Object.fromEntries(new Headers(requestInit.headers || {}).entries()),
      body: requestInit.body || null,
      queuedAt: new Date().toISOString()
    })
    writeOfflineQueue(queue)
    return new Response('', {
      status: String(requestInit.method).toUpperCase() === 'DELETE' ? 204 : 201,
      headers: { 'content-type': 'application/json', 'x-olvend-offline': 'queued' }
    })
  } finally {
    window.clearTimeout(timer)
  }
}

export async function syncOfflineRequests() {
  if (!navigator.onLine) return { pending: readOfflineQueue().length, synced: 0 }
  const queue = readOfflineQueue()
  const remaining = []
  for (const item of queue) {
    try {
      const response = await fetch(item.url, { method: item.method, headers: item.headers, body: item.body })
      if (!response.ok) remaining.push(item)
    } catch (_) {
      remaining.push(item)
    }
  }
  writeOfflineQueue(remaining)
  return { pending: remaining.length, synced: queue.length - remaining.length }
}

export function getOfflineRequestCount() { return readOfflineQueue().length }

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  global: { fetch: offlineAwareFetch }
})

window.setTimeout(() => syncOfflineRequests(), 0)
