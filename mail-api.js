import { supabase } from './supabase.js'

export const MAIL_API_URL = String(window.OLVEND_MAIL_API_URL || localStorage.getItem('olvendMailApiUrl') || 'https://olvend-mail-service.onrender.com').replace(/\/$/, '')

export async function mailApi(path, options = {}) {
  const { data: { session } } = await supabase.auth.getSession()
  if (!session?.access_token) throw new Error('Nejste přihlášeni.')
  const response = await fetch(`${MAIL_API_URL}${path}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${session.access_token}`,
      ...(options.body ? { 'Content-Type': 'application/json' } : {}),
      ...(options.headers || {})
    }
  })
  const payload = await response.json().catch(() => ({}))
  if (!response.ok) throw new Error(payload.error || `Poštovní služba vrátila chybu ${response.status}.`)
  return payload
}

export async function currentEmployee() {
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Nejste přihlášeni.')
  const { data, error } = await supabase.from('employees').select('id,name,surname,email').eq('auth_user_id', user.id).maybeSingle()
  if (error) throw error
  if (!data) throw new Error('Účet není propojený se zaměstnancem.')
  return data
}
