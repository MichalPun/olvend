import assert from 'node:assert/strict'
import fs from 'node:fs'

const html = fs.readFileSync(new URL('../mobile.html', import.meta.url), 'utf8')
const pwa = fs.readFileSync(new URL('../pwa.js', import.meta.url), 'utf8')
const serviceWorker = fs.readFileSync(new URL('../sw.js', import.meta.url), 'utf8')

assert.match(html, /Novinky 1\.10/)
assert.match(html, /Nová práce u kávy/)
assert.match(html, /Každá zásoba samostatně/)
assert.match(html, /Kelímky počítáš po tyčích/)
assert.match(html, /Fyzická kontrola je povinná i tehdy, když systém navrhne nulu/)
assert.match(html, /Další části budou následovat/)
assert.match(html, /olvendSeenMobileReleaseNotesV110/)
assert.match(html, /localStorage\.getItem\(MOBILE_RELEASE_KEY\) !== '1\.10'/)
assert.match(html, /localStorage\.setItem\(MOBILE_RELEASE_KEY, '1\.10'\)/)
assert.doesNotMatch(html, /olvendSeenMobileReleaseNotesV19/)
assert.match(pwa, /20261013-coffee-release-v1/)
assert.match(serviceWorker, /olvend-v202-coffee-release-v1/)

console.log('mobile release notes v1.10 checks passed')
