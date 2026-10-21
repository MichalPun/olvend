import assert from 'node:assert/strict'
import fs from 'node:fs'

const html = fs.readFileSync(new URL('../mobile.html', import.meta.url), 'utf8')
const pwa = fs.readFileSync(new URL('../pwa.js', import.meta.url), 'utf8')
const serviceWorker = fs.readFileSync(new URL('../sw.js', import.meta.url), 'utf8')

assert.match(html, /Novinky 1\.10/)
assert.match(html, /Jednodušší práce u kávy/)
assert.match(html, /Stav zásobníku nastavíš posuvníkem/)
assert.match(html, /Chybějící automat si vyžádáš do trasy/)
assert.match(html, /Kelímky správně po tyčích/)
assert.match(html, /Kontrola i při nulovém návrhu/)
assert.match(html, /Další části budou následovat/)
assert.match(html, /olvendSeenMobileReleaseNotesV110R2/)
assert.match(html, /localStorage\.getItem\(MOBILE_RELEASE_KEY\) !== '1\.10'/)
assert.match(html, /localStorage\.setItem\(MOBILE_RELEASE_KEY, '1\.10'\)/)
assert.doesNotMatch(html, /olvendSeenMobileReleaseNotesV19/)
assert.match(pwa, /20261021-mobile-coffee-domain-v1/)
assert.match(serviceWorker, /olvend-v223-mobile-coffee-domain-module/)
assert.match(serviceWorker, /mobile-route-completion\.js\?v=20261021-route-completion-v1/)
assert.match(serviceWorker, /mobile-coffee-visit\.js\?v=20261021-coffee-visit-v1/)
assert.match(serviceWorker, /mobile-coffee-domain\.js\?v=20261021-coffee-domain-v1/)

console.log('mobile release notes v1.10 checks passed')
