# Nákupní potřeba JIP — nasazení 29. 9. 2026

Databázová migrace `database/jip_demand_recommendations_20260929.sql` musí být nasazena před frontendem. Přidává pouze view se security_invoker a odebraným přístupem anon, nemění zásoby ani objednávky. Vrácení frontendové změny vrací původní chování; view lze ponechat bez použití.

Rozsah: potvrzený dodavatel JIP 3, sklad Blučina 1, aktivní kusové produkty s aktivním JIP párováním. Ručně vypnuté profily se respektují, chybějící profily se zobrazují virtuálně z katalogu. Balení musí být jednoznačné, neznámá jednotka zablokuje export.

Výpočet: max(ruční cíl, plné otevřené požadavky, denní potřeba × horizont) + max(ruční bezpečnostní zásoba, potřeba × 3) − Blučina − otevřené objednané dodávky v horizontu. Žádné drafty. Minimum nákupu zároveň kryje deficit před odjezdy; dodávky stejného dne bez času nejsou jisté ranní pokrytí. Zaokrouhlení nahoru na balení. Výsledek 0 nenahrazuje běžné množství automaticky.

Opakované otevřené snímky jedné trasy se seskupují po produktu/datu a bere se maximum, dílčí šarže v jednom dokladu se nejprve sečtou. Potvrzené a zrušené doklady nevytvářejí druhý nárok. Trasy bez auta používají aktuální chybějící kusy plánovaných pozic, každou pozici pouze jednou na nejbližší termín.

Dostupnost je rekonstrukce z aktuálního skladu a pohybů za 28 dokončených dnů; není to měření hodin skutečné dostupnosti. Denní odhad je maximum čistého výdeje na rekonstruovaný dostupný den a položkových prodejů / 28. Přímé výdeje skladu do stroje patří do výdeje. Chyby ve skladových pohybech mohou ovlivnit předpověď; náhled tento odhad označuje.

Ověření na produkčních datech v transakci s rollback: 42 položek, 0 neznámých převodů, žádný aktivní JIP profil nevynechán. Pepsi 288, Alaska 144, Dupetky 126 ks; urgentně 96, 48 a 21. Přidaný duplicitní snímek #494 nezměnil výsledek. Simulace 500 ks Pepsi s dodáním v den zítřejší trasy stále vykázala ranní deficit 96 ks, nikoli falešné pokrytí. Simulace proběhly jako CTE, nikoli změnou produkčních dokladů.

Objednáno vs. přijato: u uzavřeného dokladu se ukáže rozdíl, pokud je v něm původní objednané množství. Samostatný import faktury bez původní objednávky neumí doložit, co dodavatel nedodal. Externí potvrzení dodavatele není zaměňováno za stav ordered v OLVENDu.
