import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

const html = fs.readFileSync(new URL('../mobile.html', import.meta.url), 'utf8')

for (const match of html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)) {
  if (!match[1].trim()) continue
  if (/^\s*import\s/m.test(match[1])) new vm.SourceTextModule(match[1], { identifier:'mobile.html' })
  else new vm.Script(match[1], { filename:'mobile.html' })
}

const functionMatch = html.match(/    function getBlockingService\(\) \{[\s\S]*?\n    \}\n\n    function openScreen/)
assert.ok(functionMatch, 'Chybí vyhodnocení blokujícího servisu')
const functionSource = functionMatch[0].replace(/\n\n    function openScreen$/, '')
const build = new Function('state', 'todayIso', 'isTechnicianEmployee', `${functionSource}; return getBlockingService`)
const service = {
  id: 42,
  status: 'new',
  priority: 'normal',
  due_date: '2026-10-14',
  created_at: '2026-10-13T06:00:00Z',
  created_by: 'driver-1',
  assigned_employee_id: null
}

assert.equal(
  build({ employee:{ id:'driver-1' }, services:[service] }, '2026-10-14', () => false)(),
  null,
  'Řidiče nesmí blokovat závada, kterou pouze nahlásil'
)
assert.equal(
  build({ employee:{ id:'tech-1' }, services:[service] }, '2026-10-14', () => true)(),
  undefined,
  'Technika nesmí blokovat servis, který si ještě nepřevzal'
)
assert.equal(
  build({ employee:{ id:'tech-1' }, services:[{ ...service, assigned_employee_id:'tech-1' }] }, '2026-10-14', () => true)()?.id,
  42,
  'Převzatý splatný servis má technikovi zůstat jako prioritní krok'
)

assert.match(html, /Uložit závadu a pokračovat/)
assert.match(html, /Na jejich schválení nečekáš/)

console.log('OK: nahlášená závada neblokuje obsluze trasu ani konec směny; blokuje jen převzatý servis technika')
