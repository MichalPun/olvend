# OLVEND · T-Mobile Motion

Konektor běží pouze v Edge profilu uživatele. Z přihlášeného portálu T-Mobile Motion čte aktuální vozidla a do OLVENDU posílá sanitizovanou polohu a provozní stav. Heslo ani přístupový token T-Mobile neopouští prohlížeč.

## Instalace v Microsoft Edge

1. Otevřít `edge://extensions`.
2. Zapnout **Režim pro vývojáře**.
3. Zvolit **Načíst rozbalené** a vybrat tuto složku.
4. Jednou otevřít přihlášenou nástěnku OLVEND a T-Mobile Motion.

Konektor synchronizuje jednou za minutu. Před vypršením relace se pokusí v neaktivní kartě relaci obnovit; pokud přihlášení poskytovatele vyprší úplně, stav v ikoně konektoru vyzve k novému přihlášení.
