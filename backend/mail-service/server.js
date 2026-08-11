import http from 'node:http'
import crypto from 'node:crypto'
import { createClient } from '@supabase/supabase-js'
import { ImapFlow } from 'imapflow'
import nodemailer from 'nodemailer'
import { simpleParser } from 'mailparser'

const PORT = Number(process.env.PORT || 10000)
const SUPABASE_URL = process.env.SUPABASE_URL || ''
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || ''
const ENCRYPTION_KEY_HEX = process.env.MAIL_CREDENTIAL_ENCRYPTION_KEY || ''
const ALLOWED_ORIGIN = process.env.MAIL_ALLOWED_ORIGIN || 'https://olvend.onrender.com'
const BODY_LIMIT = 28 * 1024 * 1024

if (!SUPABASE_URL || !SERVICE_KEY || !/^[a-f0-9]{64}$/i.test(ENCRYPTION_KEY_HEX)) {
  console.warn('Mail service is missing SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY or a 64-character MAIL_CREDENTIAL_ENCRYPTION_KEY.')
}

const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false, autoRefreshToken: false } })
const encryptionKey = /^[a-f0-9]{64}$/i.test(ENCRYPTION_KEY_HEX) ? Buffer.from(ENCRYPTION_KEY_HEX, 'hex') : null

function cors(req) {
  const origin = String(req.headers.origin || '')
  return {
    'Access-Control-Allow-Origin': origin === ALLOWED_ORIGIN || origin.startsWith('http://localhost:') ? origin : ALLOWED_ORIGIN,
    'Access-Control-Allow-Headers': 'authorization, content-type',
    'Access-Control-Allow-Methods': 'GET, POST, PATCH, DELETE, OPTIONS',
    'Vary': 'Origin'
  }
}

function send(req, res, status, value) {
  res.writeHead(status, { ...cors(req), 'Content-Type': 'application/json; charset=utf-8' })
  res.end(JSON.stringify(value))
}

function body(req) {
  return new Promise((resolve, reject) => {
    const chunks = []; let size = 0
    req.on('data', chunk => { size += chunk.length; if (size > BODY_LIMIT) return reject(new Error('Payload is too large.')); chunks.push(chunk) })
    req.on('end', () => { try { resolve(chunks.length ? JSON.parse(Buffer.concat(chunks).toString('utf8')) : {}) } catch { reject(new Error('Invalid JSON.')) } })
    req.on('error', reject)
  })
}

function encrypt(secret) {
  if (!encryptionKey) throw new Error('Mail encryption key is not configured.')
  const iv = crypto.randomBytes(12), cipher = crypto.createCipheriv('aes-256-gcm', encryptionKey, iv)
  const encrypted = Buffer.concat([cipher.update(String(secret), 'utf8'), cipher.final()])
  return [iv.toString('base64'), cipher.getAuthTag().toString('base64'), encrypted.toString('base64')].join('.')
}

function decrypt(ciphertext) {
  if (!encryptionKey) throw new Error('Mail encryption key is not configured.')
  const [iv, tag, encrypted] = String(ciphertext).split('.').map(part => Buffer.from(part, 'base64'))
  const decipher = crypto.createDecipheriv('aes-256-gcm', encryptionKey, iv)
  decipher.setAuthTag(tag)
  return Buffer.concat([decipher.update(encrypted), decipher.final()]).toString('utf8')
}

async function currentEmployee(req) {
  const token = String(req.headers.authorization || '').replace(/^Bearer\s+/i, '')
  if (!token) throw Object.assign(new Error('Unauthorized.'), { status: 401 })
  const { data: { user }, error } = await admin.auth.getUser(token)
  if (error || !user) throw Object.assign(new Error('Unauthorized.'), { status: 401 })
  const { data: employee, error: employeeError } = await admin.from('employees').select('id,name,surname,email,active').eq('auth_user_id', user.id).maybeSingle()
  if (employeeError || !employee || employee.active === false) throw Object.assign(new Error('Employee account is not active.'), { status: 403 })
  return employee
}

function normalizeConfig(input = {}) {
  const email = String(input.email_address || '').trim().toLowerCase()
  if (!/^\S+@\S+\.\S+$/.test(email)) throw new Error('Invalid email address.')
  return {
    email_address: email,
    display_name: String(input.display_name || '').trim(),
    username: String(input.username || email).trim(),
    password: String(input.password || ''),
    imap_host: String(input.imap_host || 'imap.mail.webnode.com').trim(),
    imap_port: Number(input.imap_port || 993),
    imap_secure: input.imap_secure !== false,
    smtp_host: String(input.smtp_host || 'smtp.mail.webnode.com').trim(),
    smtp_port: Number(input.smtp_port || 465),
    smtp_secure: input.smtp_secure !== false
  }
}

async function accountFor(employeeId) {
  const { data, error } = await admin.from('mail_accounts').select('*').eq('employee_id', employeeId).eq('active', true).order('created_at').limit(1).maybeSingle()
  if (error) throw error
  if (!data) throw Object.assign(new Error('Mailbox is not connected.'), { status: 404 })
  return data
}

function accountCredentials(account) {
  return { ...account, password: decrypt(account.password_ciphertext) }
}

async function testConnections(config) {
  if (!config.password) throw new Error('Mailbox password is required.')
  const imap = new ImapFlow({ host: config.imap_host, port: config.imap_port, secure: config.imap_secure, auth: { user: config.username, pass: config.password }, logger: false })
  await imap.connect(); await imap.logout()
  const smtp = nodemailer.createTransport({ host: config.smtp_host, port: config.smtp_port, secure: config.smtp_secure, auth: { user: config.username, pass: config.password } })
  await smtp.verify()
  return { imap: true, smtp: true }
}

const addressList = addresses => (addresses || []).map(item => ({ name: item.name || '', address: item.address || '' }))
const folderName = value => String(value || 'INBOX').replace(/[\r\n]/g, '')

async function imapClient(account) {
  const config = accountCredentials(account)
  const client = new ImapFlow({ host: config.imap_host, port: config.imap_port, secure: config.imap_secure, auth: { user: config.username, pass: config.password }, logger: false })
  await client.connect()
  return client
}

async function listMessages(account, folder, limit = 50) {
  const client = await imapClient(account), messages = []
  try {
    const lock = await client.getMailboxLock(folder)
    try {
      const exists = Number(client.mailbox?.exists || 0), start = Math.max(1, exists - Math.min(limit, 100) + 1)
      for await (const item of client.fetch(`${start}:*`, { uid: true, envelope: true, flags: true, size: true, bodyStructure: true })) {
        const from = addressList(item.envelope?.from)[0] || {}
        messages.push({ uid: item.uid, subject: item.envelope?.subject || '(bez předmětu)', sender_name: from.name || from.address || '', sender_address: from.address || '', received_at: item.envelope?.date || null, is_read: item.flags?.has('\\Seen') || false, is_flagged: item.flags?.has('\\Flagged') || false, has_attachments: JSON.stringify(item.bodyStructure || '').toLowerCase().includes('attachment'), size_bytes: item.size || 0 })
      }
    } finally { lock.release() }
  } finally { await client.logout().catch(() => {}) }
  return messages.reverse()
}

async function syncIndex(account, employeeId) {
  const messages = await listMessages(account, 'INBOX', 100)
  if (messages.length) {
    const rows = messages.map(item => ({ account_id: account.id, employee_id: employeeId, folder_path: 'INBOX', ...item, recipients: [], synced_at: new Date().toISOString() }))
    const { error } = await admin.from('mail_message_index').upsert(rows, { onConflict: 'account_id,folder_path,uid' })
    if (error) throw error
  }
  await admin.from('mail_accounts').update({ last_sync_at: new Date().toISOString(), last_error: null, updated_at: new Date().toISOString() }).eq('id', account.id)
  return messages
}

async function route(req, res) {
  if (req.method === 'OPTIONS') { res.writeHead(204, cors(req)); return res.end() }
  const url = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`)
  if (req.method === 'GET' && url.pathname === '/healthz') return send(req, res, 200, { ok: true, service: 'olvend-mail-service' })
  const employee = await currentEmployee(req)

  if (req.method === 'GET' && url.pathname === '/account') {
    const { data, error } = await admin.from('mail_accounts_safe').select('*').eq('employee_id', employee.id).eq('active', true).limit(1).maybeSingle()
    if (error) throw error
    return send(req, res, 200, { account: data })
  }
  if (req.method === 'POST' && url.pathname === '/account/test') {
    const config = normalizeConfig(await body(req)); await testConnections(config)
    return send(req, res, 200, { ok: true, imap: true, smtp: true })
  }
  if (req.method === 'POST' && url.pathname === '/account') {
    const input = await body(req), config = normalizeConfig(input)
    if (!config.password) throw new Error('Mailbox password is required.')
    await testConnections(config)
    const row = { employee_id: employee.id, ...config, password_ciphertext: encrypt(config.password), password: undefined, sync_history_days: Number(input.sync_history_days || 90), sync_folders: input.sync_folders !== false, sync_deletions: input.sync_deletions !== false, download_attachments: Boolean(input.download_attachments), updated_at: new Date().toISOString() }
    delete row.password
    const { data, error } = await admin.from('mail_accounts').upsert(row, { onConflict: 'employee_id,email_address' }).select('id,email_address,display_name,last_sync_at').single()
    if (error) throw error
    return send(req, res, 200, { account: data })
  }
  const account = await accountFor(employee.id)
  if (req.method === 'POST' && url.pathname === '/sync') return send(req, res, 200, { messages: await syncIndex(account, employee.id) })
  if (req.method === 'GET' && url.pathname === '/folders') {
    const client = await imapClient(account); try { const folders = await client.list(); return send(req, res, 200, { folders: folders.map(item => ({ path: item.path, name: item.name, special_use: item.specialUse || null })) }) } finally { await client.logout().catch(() => {}) }
  }
  if (req.method === 'GET' && url.pathname === '/messages') return send(req, res, 200, { messages: await listMessages(account, folderName(url.searchParams.get('folder')), Number(url.searchParams.get('limit') || 50)) })
  if (req.method === 'GET' && url.pathname === '/message') {
    const client = await imapClient(account), folder = folderName(url.searchParams.get('folder')), uid = Number(url.searchParams.get('uid'))
    try { const lock = await client.getMailboxLock(folder); try { const item = await client.fetchOne(uid, { source: true, flags: true }, { uid: true }); if (!item?.source) throw Object.assign(new Error('Message not found.'), { status: 404 }); const parsed = await simpleParser(item.source); await client.messageFlagsAdd(uid, ['\\Seen'], { uid: true }); return send(req, res, 200, { message: { uid, subject: parsed.subject || '(bez předmětu)', from: parsed.from?.value || [], to: parsed.to?.value || [], cc: parsed.cc?.value || [], date: parsed.date || null, html: parsed.html || '', text: parsed.text || '', attachments: parsed.attachments.map((a, index) => ({ index, filename: a.filename || `priloha-${index + 1}`, content_type: a.contentType, size: a.size, content: a.content.toString('base64') })) } }) } finally { lock.release() } } finally { await client.logout().catch(() => {}) }
  }
  if (req.method === 'POST' && url.pathname === '/send') {
    const input = await body(req), config = accountCredentials(account), transport = nodemailer.createTransport({ host: config.smtp_host, port: config.smtp_port, secure: config.smtp_secure, auth: { user: config.username, pass: config.password } })
    const attachments = Array.isArray(input.attachments) ? input.attachments.map(a => ({ filename: String(a.filename || 'priloha'), content: Buffer.from(String(a.content || ''), 'base64'), contentType: a.content_type || undefined })) : []
    const result = await transport.sendMail({ from: { name: config.display_name || employee.name || '', address: config.email_address }, to: input.to, cc: input.cc || undefined, bcc: input.bcc || undefined, subject: String(input.subject || ''), text: String(input.text || ''), html: String(input.html || ''), attachments, inReplyTo: input.in_reply_to || undefined, references: input.references || undefined })
    return send(req, res, 200, { ok: true, message_id: result.messageId })
  }
  return send(req, res, 404, { error: 'Not found.' })
}

http.createServer((req, res) => route(req, res).catch(error => {
  console.error(error)
  send(req, res, Number(error.status || 500), { error: error.message || 'Mail service error.' })
})).listen(PORT, () => console.log(`OLVEND mail service listening on ${PORT}`))
