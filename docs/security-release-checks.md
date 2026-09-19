# Kontrola zabezpečení před vydáním

Kontrola funkčnosti jako administrátor nestačí. Před vydáním musí projít
odmítnutí nepovolených operací pro anonymního návštěvníka, aktivního operátora
a neaktivní účet; zároveň musí zůstat funkční vedení a veřejný QR formulář.

## Lokální a CI kontroly

Z kořene repozitáře (Node 22+):

```sh
node --experimental-vm-modules scripts/test_security_boundary.mjs
node scripts/check_anonymous_boundary.mjs --self-test
node scripts/check_anonymous_boundary.mjs --live
```

Poslední příkaz používá pouze veřejný klíč. Posílá GET s limit=0 do 12 interních
endpointů, nečte řádky a nic nemění. Vyžaduje skutečné databázové zamítnutí;
chybný klíč, síťová chyba, přesměrování, 404 ani 500 nejsou úspěšný test.
Není to test všech oprávnění ani kontrola přihlášených rolí.

## Po každé změně databáze nebo oprávnění

V SQL editoru spustit `database/assert_security_configuration.sql` a potom
`database/test_security_boundary_20260919.sql`. Druhý soubor provádí zkušební
zápisy uvnitř transakce zakončené ROLLBACK. Zachovat tuto transakci, nevyjímat
jednotlivé zápisy a nespouštět ji proti nově zavedeným externím vedlejším účinkům
bez jejich kontroly. Výsledky musí obsahovat PASS; chyba či chybějící výsledek
nejsou schválením vydání.

Nová interní tabulka vyžaduje RLS, restrictive `security_active_employee_gate`
a oprávnění podle vlastníka/role. U nové privilegované funkce je nutné ověřit
identitu i oprávnění uvnitř funkce. Nové API nesmí spoléhat na skryté tlačítko.
Veřejné RPC má explicitní, minimální kontrakt. Zálohy a úložiště nejsou veřejné.

Historické SQL soubory nejsou instalační manifest. Nenahrávat je plošně znovu.
`employees_auth_setup.sql` nyní vyžaduje bezpečnostní pomocné funkce a neposkytuje
anonymní přístup ani neomezenou změnu rolí. Po obnově provést současné bezpečnostní
migrace a oba SQL testy před zpřístupněním aplikace.

## Vynucení

GitHub Actions musí být skutečně aktivní a úspěšné kontroly povinné pro slučování
do main. Render musí čekat na kontroly nebo spouštět kontrolní příkazy jako build
command. Samotný soubor workflow ani zelený lokální test nasazení neblokují.
Přímé změny v SQL editoru GitHub nevidí; proto je databázový audit povinnou součástí
každé migrace. Omezení práv pro produkční migrace a audit jejich provádění je další
provozní opatření, ne vlastnost těchto skriptů.

Žádný test nedává záruku nulového budoucího rizika. Pro změny přístupových pravidel
je požadována samostatná kontrola oprávnění a nezávislé posouzení složitých změn.
