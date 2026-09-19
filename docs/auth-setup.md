# OLVEND Auth Setup

## Cil

Zamestnance se nemaji zakladat rucne v Supabase Auth. Frontend OLVEND ma vytvorit zamestnance i jeho pristupovy ucet jednim krokem.

## Navrzene reseni

- login zustava pres `supabase.auth.signInWithPassword()`
- vytvoreni zamestnance s pristupem dela serverova funkce
- funkce pouziva `SUPABASE_SERVICE_ROLE_KEY`, ktera nesmi byt ve frontendu
- funkci muze volat jen prihlaseny `admin` nebo `manager`

## Co je pripraveno

### SQL

Soubor: `database/employees_auth_setup.sql`

Bezpečnostní aktualizace 19. 9. 2026: tento skript vyžaduje již nainstalované
funkce `has_manager_access()` a `security_active_employee()`. Přímý zápis smí
provádět pouze vedení, čtení úplných profilů jen příslušný zaměstnanec nebo vedení.
Anonymní přístup není povolen. Kontrola role v Edge Function sama nestačí:
stejná pravidla musí vynucovat databáze. Při obnově použít aktuální bezpečnostní
migrace a postup v `docs/security-release-checks.md`.

Doplni do `employees`:

- `auth_user_id`
- `created_by`
- `updated_at`

A pripravi zakladni trigger a RLS policy.

### Edge Function

Soubor: `backend/supabase/functions/create-employee-account/index.ts`

Funkce:

1. overi prihlaseneho uzivatele
2. nacte jeho zaznam z `employees`
3. pusti dal jen `admin` nebo `manager`
4. vytvori Auth usera
5. zalozi nebo doplni zaznam v `employees`
6. ulozi `auth_user_id`

## Potrebne env promenne ve funkci

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

## Jak bude frontend volat funkci

Z formulare `Zamestnanci` se bude posilat:

```json
{
  "name": "Michal",
  "surname": "Puncochar",
  "email": "michal@olmika.cz",
  "password": "docasne-heslo",
  "role": "admin",
  "position": "Jednatel",
  "phone": "777123456",
  "note": "Zakladni admin ucet",
  "warehouse_id": null,
  "active": true
}
```

## Dalsi krok

Po nasazeni SQL a Edge Function se upravi stranka `Zamestnanci` tak, aby:

- pri vytvareni noveho zamestnance volala tuto funkci
- pri editaci dal pouzivala bezne `update` do `employees`
- umela nastavit docasne heslo pri vytvareni pristupu
