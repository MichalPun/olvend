# OLVEND

OLVEND je interni system pro spravu vendingovych automatu firmy OLMIKA.

Aktualni stav projektu:

- frontend bezi jako staticka aplikace
- nasazeni je planovane pres GitHub -> Render
- aplikace je pripravena i jako interni PWA instalace do mobilu
- architektura je pripravena na pozdejsi rozdeleni do samostatnych casti
- prvni prioritni modul je `Servis`

## Struktura projektu

```text
/
|- frontend/   # webova aplikace
|- backend/    # budouci API a business logika
|- database/   # schema, migrace a datove navrhy
|- docs/       # architektura a produktova dokumentace
|- index.html  # docasny vstupni dashboard pro Render Static Site
```

## Doporuceny dalsi postup

1. Postavit servisni dashboard a seznam zasahu jako prvni realny workflow.
2. Navrhnout datovy model pro servisni ticket, stav zasahu a vazbu na automat.
3. Udelat z `frontend/` hlavni zdroj UI.
4. Pripravit backend API pro evidenci a planovani.

Podrobnejsi navrh je v `docs/architecture.md` a `docs/service-module.md`.

## Interni mobilni spusteni

Projekt ted umi bez App Store a Google Play fungovat jako interni PWA aplikace:

- otevrit nasazenou URL v Safari nebo Chrome na telefonu
- prihlasit se do OLVEND
- pridat aplikaci na plochu
- spoustet ji z ikonky jako samostatnou appku

Co je pripravene:

- `manifest.webmanifest`
- `sw.js`
- `pwa.js`
- instalacni ikony v `icons/`

Poznamka:

- pri dalsi zmene shellu aplikace je dobre zvednout verzi cache v `sw.js`
