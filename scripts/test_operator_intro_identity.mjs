import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const read = path => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8')
const manifest = JSON.parse(read('olvend-operator/manifest.webmanifest'))
const pwa = read('olvend-operator/pwa.js')
const serviceWorker = read('olvend-operator/sw.js')
const installablePages = ['index.html', 'prihlaseni.html', 'uvod.html', 'trasa.html', 'sklad.html', 'profil.html', 'pokyny.html', 'vozidlo.html']

assert.equal(manifest.name, 'OLVEND Operátor')
assert.equal(manifest.short_name, 'OLVEND Operátor')
assert.equal(manifest.id, '/olvend-operator/')
assert.equal(manifest.start_url, '/olvend-operator/uvod.html')
assert.equal(manifest.scope, '/olvend-operator/')

for (const page of installablePages) {
  const html = read(`olvend-operator/${page}`)
  assert.match(html, /name="application-name" content="OLVEND Operátor"/, page)
  assert.match(html, /name="apple-mobile-web-app-title" content="OLVEND Operátor"/, page)
  assert.match(html, /manifest\.webmanifest\?v=20261117-full-name-v1/, page)
  assert.match(html, /pwa\.js\?v=20261117-full-name-v1/, page)
}

const intro = read('olvend-operator/uvod.html')
assert.match(intro, /<title>OLVEND Operátor · Před směnou<\/title>/)
assert.match(intro, /id="olvend-before-shift-tiles"/)
assert.match(intro, /id="ot-vehicle"/)
assert.match(intro, /id="ot-instructions"/)
assert.match(intro, /id="ot-start"/)
assert.match(pwa, /sw\.js\?v=20261117-full-name-v1/)
assert.match(pwa, /scope:\s*'\.\/'/)
assert.match(serviceWorker, /olvend-operator-v27-full-name/)

console.log('OLVEND Operátor tiled intro and install identity checks passed')
