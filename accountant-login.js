import { supabase } from './supabase.js'

const form = document.getElementById('loginForm')
const emailInput = document.getElementById('emailInput')
const passwordInput = document.getElementById('passwordInput')
const loginBtn = document.getElementById('loginBtn')
const loginStatus = document.getElementById('loginStatus')

function showStatus(message, type = 'error') {
  loginStatus.textContent = message
  loginStatus.className = `login-status ${type}`
  loginStatus.hidden = false
}

async function verifyAccess() {
  const { data: scope, error } = await supabase.rpc('finance_portal_scope_v1')
  if (error || !['accountant', 'internal'].includes(scope)) {
    await supabase.auth.signOut({ scope: 'local' })
    throw new Error('Pro tento účet není účetní portál aktivní.')
  }
  location.replace('accountant-portal.html')
}

form.addEventListener('submit', async (event) => {
  event.preventDefault()
  loginBtn.disabled = true
  loginBtn.querySelector('span').textContent = 'Přihlašuji…'
  loginStatus.hidden = true
  try {
    const { error } = await supabase.auth.signInWithPassword({ email: emailInput.value.trim(), password: passwordInput.value })
    if (error) throw new Error('E-mail nebo heslo není správné.')
    await verifyAccess()
  } catch (error) {
    showStatus(error.message)
    loginBtn.disabled = false
    loginBtn.querySelector('span').textContent = 'Přihlásit se'
  }
})

const { data } = await supabase.auth.getSession()
if (data?.session) verifyAccess().catch((error) => showStatus(error.message))
