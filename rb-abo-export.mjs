const digits = (value, max = 30) => String(value ?? '').replace(/\D/g, '').slice(0, max)
const ascii = (value, max = 140) => String(value ?? '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toUpperCase().replace(/[^A-Z0-9 .,:;_+\-/]/g, ' ').replace(/\s+/g, ' ').trim().slice(0, max)
const ddmmyy = value => {
  const date = value instanceof Date ? value : new Date(`${value}T12:00:00`)
  if (Number.isNaN(date.getTime())) throw new Error('Neplatné datum splatnosti.')
  return `${String(date.getDate()).padStart(2,'0')}${String(date.getMonth()+1).padStart(2,'0')}${String(date.getFullYear()).slice(-2)}`
}
const cents = value => {
  const result = Math.round(Number(value) * 100)
  if (!Number.isSafeInteger(result) || result <= 0 || String(result).length > 12) throw new Error('Částka není platná pro ABO formát.')
  return String(result)
}

export function splitCzechAccount(value, explicitBankCode = '') {
  const compact = String(value || '').replace(/\s/g, '')
  const [accountPart, suffix = ''] = compact.split('/')
  const bankCode = digits(explicitBankCode || suffix, 4)
  const match = accountPart.match(/^(?:(\d{1,6})-)?(\d{2,10})$/)
  if (!match || bankCode.length !== 4) throw new Error(`Neplatný účet ${value || '—'}.`)
  return { account: match[1] ? `${match[1]}-${match[2]}` : match[2], bankCode }
}

function modulo11Part(value, weights) {
  const padded = digits(value).padStart(weights.length, '0')
  return [...padded].reduce((sum, number, index) => sum + Number(number) * weights[index], 0) % 11 === 0
}

export function isValidCzechAccount(value) {
  const [prefix = '', main = ''] = String(value || '').split('-').length === 2 ? String(value).split('-') : ['', String(value || '')]
  return (!prefix || modulo11Part(prefix,[10,5,8,4,2,1])) && modulo11Part(main,[6,3,7,9,10,5,8,4,2,1])
}

export function validateRbPayment(item) {
  const { account, bankCode } = splitCzechAccount(item.creditor_account || item.bank_account, item.creditor_bank_code || item.bank_code)
  if (!isValidCzechAccount(account)) throw new Error(`Účet ${account}/${bankCode} neprošel kontrolou Modulo 11.`)
  const variableSymbol = digits(item.variable_symbol,10)
  const constantSymbol = digits(item.constant_symbol,4)
  const specificSymbol = digits(item.specific_symbol,10)
  return {
    ...item, account, bankCode, variableSymbol, constantSymbol, specificSymbol,
    amountCents: cents(item.amount), executionDate: ddmmyy(item.requested_execution_date || item.execution_date),
    av: ascii(item.message || item.creditor_name || 'PLATBA OLVEND',140)
  }
}

export function createRbAboKpc(batch, items, options = {}) {
  if (!Array.isArray(items) || !items.length) throw new Error('Dávka neobsahuje žádné platby.')
  const debtor = splitCzechAccount(batch.debtor_account || '6544188002/5500')
  if (debtor.bankCode !== '5500') throw new Error('ABO dávka je nastavena pro účet OLMIKA u Raiffeisenbank 5500.')
  if (!isValidCzechAccount(debtor.account)) throw new Error('Účet plátce neprošel kontrolou Modulo 11.')
  const checked = items.map(validateRbPayment)
  const created = options.createdAt || new Date()
  const clientName = ascii(options.clientName || 'OLMIKA SRO',20).padEnd(20,' ')
  const lines = [`UHL1${ddmmyy(created)}${clientName}1234567890001999111111222222`, '1 1501 111111 5500']
  const groups = new Map()
  for (const item of checked) {
    const key = item.executionDate
    if (!groups.has(key)) groups.set(key,[])
    groups.get(key).push(item)
  }
  for (const [executionDate, group] of [...groups.entries()].sort(([a],[b]) => a.localeCompare(b))) {
    const total = group.reduce((sum,item)=>sum+Number(item.amountCents),0)
    lines.push(`2 ${debtor.account} ${total} ${executionDate}`)
    for (const item of group) {
      const bankAndConstant = `${item.bankCode}${item.constantSymbol.padStart(4,'0')}`
      const symbols = `${item.account} ${item.amountCents} ${item.variableSymbol || '0'} ${bankAndConstant} ${item.specificSymbol || '0'}`
      lines.push(item.av ? `${symbols} AV: ${item.av}` : symbols)
    }
    lines.push('3 +')
  }
  lines.push('5 +')
  return `${lines.join('\r\n')}\r\n`
}

export async function sha256Hex(value) {
  const bytes = typeof value === 'string' ? new TextEncoder().encode(value) : value
  const digest = await crypto.subtle.digest('SHA-256',bytes)
  return [...new Uint8Array(digest)].map(byte=>byte.toString(16).padStart(2,'0')).join('')
}

export function rbFileName(batch) {
  const reference = ascii(batch.batch_number || 'OLVEND-PLATBY',40).replace(/[^A-Z0-9_-]+/g,'-')
  return `${reference}.kpc`
}
