import assert from 'node:assert/strict'
import fs from 'node:fs'

const html = fs.readFileSync('machines.html', 'utf8')

assert.match(html, /placeholder="Hledat stroj, ev\. číslo, terminál nebo lokalitu\.\.\."/)
assert.match(html, /<th style="width:120px;">Terminál \(TID\)<\/th>/)
assert.match(html, /<td data-label="Terminál \(TID\)">[\s\S]*?item\.ima_device_id \|\| '—'/)
assert.match(html, /item\.serial_number,\s*item\.ima_device_id,\s*getEvidenceNumber\(item\)/)
assert.match(html, /ima_device_id: imaLink\?\.telemetry_enabled === true \? \(imaLink\.external_machine_id \|\| null\) : null/)

console.log('Machine terminal column and TID search checks passed')
