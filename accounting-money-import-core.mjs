const MONEY_DOCUMENT_TYPES = [
  ['FaktPrij', 'received_invoice'],
  ['FaktVyd', 'issued_invoice'],
  ['IntDokl', 'internal_document'],
  ['BankDokl', 'bank_document'],
  ['PokDokl', 'cash_document'],
  ['Zavazek', 'liability'],
  ['Pohledavka', 'receivable'],
]

const ACCOUNT_KIND = {
  '1': 'balance',
  '2': 'profit_loss',
  '3': 'closing',
  '4': 'off_balance',
}

const ACCOUNT_TYPE = {
  '0': 'unspecified',
  '1': 'asset',
  '2': 'liability',
  '3': 'expense',
  '4': 'revenue',
}

function escapeRegExp(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

function decodeXml(value) {
  return String(value ?? '')
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1')
    .replace(/&#x([0-9a-f]+);/gi, (_, code) => String.fromCodePoint(Number.parseInt(code, 16)))
    .replace(/&#([0-9]+);/g, (_, code) => String.fromCodePoint(Number(code)))
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, '&')
    .trim()
}

function blocks(xml, tag) {
  const safe = escapeRegExp(tag)
  const pattern = new RegExp(`<${safe}(?:\\s[^>]*)?>([\\s\\S]*?)<\\/${safe}>`, 'gi')
  return Array.from(String(xml || '').matchAll(pattern), (match) => match[1])
}

function text(xml, tag) {
  return decodeXml(blocks(xml, tag)[0] || '')
}

function attribute(xml, tag, name) {
  const safeTag = escapeRegExp(tag)
  const safeName = escapeRegExp(name)
  const match = String(xml || '').match(new RegExp(`<${safeTag}\\b[^>]*\\b${safeName}=["']([^"']*)["']`, 'i'))
  return decodeXml(match?.[1] || '')
}

function number(value) {
  const normalized = String(value ?? '')
    .replace(/\s/g, '')
    .replace(',', '.')
  const result = Number(normalized)
  return Number.isFinite(result) ? result : 0
}

function bool(value) {
  return ['1', 'true', 'ano', 'yes'].includes(String(value || '').trim().toLowerCase())
}

function date(value) {
  const match = String(value || '').match(/\d{4}-\d{2}-\d{2}/)
  return match?.[0] || null
}

function uniqueBy(rows, key) {
  return Array.from(new Map(rows.map((row) => [row[key], row])).values())
}

function parseAccounts(xml) {
  return uniqueBy(blocks(xml, 'UcOsnova').map((row) => {
    const code = text(row, 'Ucet')
    const kindCode = text(row, 'DruhUctu') || '0'
    const typeCode = text(row, 'UcetTyp') || '0'
    const subtypeCode = text(row, 'UcetPodTyp') || '0'
    return {
      code,
      name: text(row, 'Nazev') || code,
      kind: ACCOUNT_KIND[kindCode] || 'unspecified',
      account_type: ACCOUNT_TYPE[typeCode] || 'unspecified',
      kind_code: kindCode,
      type_code: typeCode,
      subtype_code: subtypeCode,
      tracks_balance: ['1', '5', '6'].includes(subtypeCode),
      affects_income_tax: subtypeCode === '3',
      internal: bool(text(row, 'Vnitro')),
      technical: bool(text(row, 'Technicky')),
      correction: bool(text(row, 'Opravky')),
      note: text(row, 'Pozn') || null,
    }
  }).filter((row) => row.code), 'code')
}

function parsePreaccountings(xml) {
  return uniqueBy(blocks(xml, 'Predkontace').map((row) => ({
    code: text(row, 'Zkrat'),
    document_type: text(row, 'Typ') || 'NN',
    description: text(row, 'Popis') || text(row, 'Zkrat'),
    debit_account_code: text(row, 'UcMD') || null,
    credit_account_code: text(row, 'UcD') || null,
    vat_posting_code: text(row, 'ZauctDPH') || null,
    follow_up_enabled: bool(text(row, 'UctovatLed')),
    follow_up_price_type: text(row, 'TypCeny') || null,
    follow_up_debit_account_code: text(row, 'UcLedMD') || null,
    follow_up_credit_account_code: text(row, 'UcLedD') || null,
    vat_classification: text(row, 'Cleneni') || null,
    note: text(row, 'Pozn') || null,
  })).filter((row) => row.code), 'code')
}

function documentDate(row) {
  for (const field of ['DatUcPr', 'UcDatum', 'Vystaveno', 'DatSkPoh', 'PlnenoDPH', 'Datum']) {
    const result = date(text(row, field))
    if (result) return result
  }
  return null
}

function documentCurrency(row) {
  const valuty = blocks(row, 'Valuty')[0]
  return text(valuty, 'Mena') || text(valuty, 'Typ') || 'CZK'
}

function parseJournalEntries(xml) {
  const entries = []
  const warnings = []

  for (const [moneyTag, sourceType] of MONEY_DOCUMENT_TYPES) {
    for (const [index, row] of blocks(xml, moneyTag).entries()) {
      const documentNumber = text(row, 'Doklad') || text(row, 'EvCisDokl') || `${moneyTag}-${index + 1}`
      const entryDate = documentDate(row)
      const postingRows = blocks(row, 'RozuctPolozka')
      const lines = []

      postingRows.forEach((posting, postingIndex) => {
        const debit = text(posting, 'UcMD')
        const credit = text(posting, 'UcD')
        const amount = number(text(posting, 'Castka'))
        const lineDescription = text(posting, 'Popis') || text(row, 'Popis') || documentNumber
        const dimensions = {
          cost_center: text(posting, 'Stred') || null,
          job: text(posting, 'Zakazka') || null,
          activity: text(posting, 'Cinnost') || null,
          pairing_symbol: text(posting, 'ParSym') || text(posting, 'VarSym') || null,
          company_id: text(posting, 'ParICO') || text(posting, 'ICO') || null,
          vat_rate: number(text(posting, 'SazbaDPH')),
          price_type: text(posting, 'TypCena') || null,
        }

        if (amount <= 0 || !debit || !credit) {
          warnings.push(`${moneyTag} ${documentNumber}: rozúčtovací řádek ${postingIndex + 1} nemá úplný účet MD/D nebo kladnou částku.`)
          return
        }

        lines.push({
          account_code: debit,
          debit: amount,
          credit: 0,
          description: lineDescription,
          line_number: lines.length + 1,
          ...dimensions,
        })
        lines.push({
          account_code: credit,
          debit: 0,
          credit: amount,
          description: lineDescription,
          line_number: lines.length + 1,
          ...dimensions,
        })
      })

      if (!postingRows.length) continue
      if (!entryDate) warnings.push(`${moneyTag} ${documentNumber}: chybí rozpoznatelné účetní datum.`)
      if (!lines.length) continue

      entries.push({
        source_type: sourceType,
        source_key: `${moneyTag}:${documentNumber}`,
        source_document_number: documentNumber,
        external_id: attribute(row, moneyTag, 'ID') || text(row, 'GUID') || null,
        entry_date: entryDate,
        taxable_date: date(text(row, 'PlnenoDPH')) || entryDate,
        description: text(row, 'Popis') || documentNumber,
        variable_symbol: text(row, 'VarSymbol') || text(row, 'VarSym') || null,
        currency: documentCurrency(row),
        preaccounting_code: text(row, 'PredKontac') || null,
        lines,
      })
    }
  }

  return { entries, warnings }
}

export function parseMoneyS3AccountingXml(xml, options = {}) {
  const source = String(xml || '').replace(/^\uFEFF/, '').trim()
  if (!/<MoneyData\b/i.test(source)) throw new Error('Soubor není nativní XML export Money S3 (chybí MoneyData).')

  const accountingYearStart = date(attribute(source, 'MoneyData', 'HospRokOd'))
  const accountingYearEnd = date(attribute(source, 'MoneyData', 'HospRokDo'))
  const exportedAt = date(attribute(source, 'MoneyData', 'ExpDate'))
  const { entries, warnings } = parseJournalEntries(source)
  const accounts = parseAccounts(source)
  const preaccountings = parsePreaccountings(source)
  const missingAccountCodes = uniqueBy(entries.flatMap((entry) => entry.lines)
    .filter((line) => !accounts.some((account) => account.code === line.account_code))
    .map((line) => ({ code: line.account_code })), 'code').map((row) => row.code)

  if (missingAccountCodes.length) {
    warnings.push(`V deníku je ${missingAccountCodes.length} účtů, které nejsou v tomto XML obsažené v účetním rozvrhu.`)
  }

  return {
    format: 'money_s3_native_xml',
    schema_version: options.schemaVersion || '2026-11',
    agenda_id: attribute(source, 'MoneyData', 'ICAgendy') || null,
    agenda_code: attribute(source, 'MoneyData', 'KodAgendy') || null,
    description: attribute(source, 'MoneyData', 'description') || null,
    export_abbreviation: attribute(source, 'MoneyData', 'ExpZkratka') || null,
    exported_at: exportedAt,
    accounting_year_start: accountingYearStart,
    accounting_year_end: accountingYearEnd,
    accounts,
    preaccountings,
    entries,
    missing_account_codes: missingAccountCodes,
    warnings,
    summary: {
      accounts: accounts.length,
      preaccountings: preaccountings.length,
      entries: entries.length,
      lines: entries.reduce((sum, entry) => sum + entry.lines.length, 0),
      debit: entries.reduce((sum, entry) => sum + entry.lines.reduce((lineSum, line) => lineSum + number(line.debit), 0), 0),
      credit: entries.reduce((sum, entry) => sum + entry.lines.reduce((lineSum, line) => lineSum + number(line.credit), 0), 0),
    },
  }
}

export function validateMoneyAccountingPayload(payload) {
  const errors = []
  if (!payload?.accounting_year_start || !payload?.accounting_year_end) errors.push('XML neobsahuje účetní rok Money S3.')
  if (!payload?.accounts?.length && !payload?.preaccountings?.length && !payload?.entries?.length) errors.push('XML neobsahuje účetní osnovu, předkontace ani zaúčtované doklady.')
  if (Math.abs(number(payload?.summary?.debit) - number(payload?.summary?.credit)) > 0.01) errors.push('Součet MD a Dal v importu nesouhlasí.')
  for (const entry of payload?.entries || []) {
    const debit = entry.lines.reduce((sum, line) => sum + number(line.debit), 0)
    const credit = entry.lines.reduce((sum, line) => sum + number(line.credit), 0)
    if (!entry.entry_date) errors.push(`Doklad ${entry.source_document_number} nemá účetní datum.`)
    if (Math.abs(debit - credit) > 0.01) errors.push(`Doklad ${entry.source_document_number} není vyrovnaný.`)
  }
  return errors
}
