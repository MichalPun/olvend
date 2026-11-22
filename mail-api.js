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

export async function mailApiDownload(path, options = {}) {
  const { data: { session } } = await supabase.auth.getSession()
  if (!session?.access_token) throw new Error('Nejste přihlášeni.')
  const response = await fetch(`${MAIL_API_URL}${path}`, {
    ...options,
    headers: { Authorization: `Bearer ${session.access_token}`, ...(options.headers || {}) }
  })
  if (!response.ok) {
    const payload = await response.json().catch(() => ({}))
    throw new Error(payload.error || `Stažení podkladu selhalo (${response.status}).`)
  }
  const disposition = response.headers.get('content-disposition') || ''
  const fileName = disposition.match(/filename="([^"]+)"/i)?.[1] || 'faktura-evidence.pdf'
  return { blob: await response.blob(), fileName }
}

export async function financeMailboxStatus() {
  const { data, error } = await supabase.rpc('get_finance_mailbox_status_v1')
  if (!error) return { ...(data || {}), verified_by: 'database' }

  try {
    return { ...(await mailApi('/finance/account')), verified_by: 'mail_service', database_error: error.message }
  } catch (apiError) {
    throw new Error(`Stav schránky nelze ověřit: ${error.message || apiError.message}`)
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
