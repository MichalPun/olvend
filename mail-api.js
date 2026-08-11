import { supabase } from './supabase.js'

export const MAIL_API_URL = String(window.OLVEND_MAIL_API_URL || localStorage.getItem('olvendMailApiUrl') || 'https://olvend-mail-service.onrender.com').replace(/\/$/, '')

export async function mailApi(path, options = {}) {
  const { data: { session } } = await supabase.auth.getSession()
  if (!session?.access_token) throw new Error('Nejste přihlášeni.')
  const { timeoutMs = 75000, signal, ...fetchOptions } = options
  const controller = new AbortController()
  const abort = () => controller.abort()
  if (signal?.aborted) abort()
  else signal?.addEventListener('abort', abort, { once: true })
  const timer = window.setTimeout(abort, timeoutMs)
  try {
    const response = await fetch(`${MAIL_API_URL}${path}`, {
      ...fetchOptions,
      signal: controller.signal,
      headers: {
        Authorization: `Bearer ${session.access_token}`,
        ...(fetchOptions.body ? { 'Content-Type': 'application/json' } : {}),
        ...(fetchOptions.headers || {})
      }
    })
    const payload = await response.json().catch(() => ({}))
    if (!response.ok) throw new Error(payload.error || `Poštovní služba vrátila chybu ${response.status}.`)
    return payload
  } catch (error) {
    if (error?.name === 'AbortError') throw new Error('Test připojení vypršel. Zkontrolujte servery, porty a heslo a zkuste to znovu.')
    throw error
  } finally {
    window.clearTimeout(timer)
    signal?.removeEventListener('abort', abort)
  }
}

export async function currentEmployee() {
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Nejste přihlášeni.')
  const { data, error } = await supabase.from('employees').select('id,name,surname,email').eq('auth_user_id', user.id).maybeSingle()
  if (error) throw error
  if (!data) throw new Error('Účet není propojený se zaměstnancem.')
  return data
}
