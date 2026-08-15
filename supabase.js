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
  const queueable = canQueueRequest(url, requestInit)
  const method = String(requestInit.method || 'GET').toUpperCase()
  const maxAttempts = !queueable && (method === 'GET' || method === 'HEAD') && !init.signal ? 2 : 1
  let lastError = null

  for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
    const controller = new AbortController()
    const timeoutMs = queueable ? 3000 : (attempt === 0 ? 18000 : 25000)
    const timer = window.setTimeout(() => controller.abort(), timeoutMs)
    try {
      return await fetch(input, { ...init, signal: init.signal || controller.signal })
    } catch (error) {
      lastError = error
      const wasAborted = error?.name === 'AbortError' || /abort/i.test(String(error?.message || error || ''))
      if (attempt + 1 < maxAttempts && wasAborted) {
        await new Promise((resolve) => window.setTimeout(resolve, 400))
        continue
      }
      break
    } finally {
      window.clearTimeout(timer)
    }
  }

  if (queueable) {
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
  }
  throw lastError
}

export async function syncOfflineRequests() {
  if (!navigator.onLine) return { pending: readOfflineQueue().length, synced: 0 }
  const queue = readOfflineQueue()
  const remaining = []
  let accessToken = null
  try {
    const { data } = await supabase.auth.getSession()
    accessToken = data?.session?.access_token || null
  } catch (_) {}
  for (const item of queue) {
    try {
      const headers = new Headers(item.headers || {})
      if (accessToken) headers.set('authorization', `Bearer ${accessToken}`)
      headers.delete('content-length')
      const response = await fetch(item.url, { method: item.method, headers, body: item.body })
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
