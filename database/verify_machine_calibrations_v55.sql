-- Spouštějte až po migraci v lokální nebo staging databázi.
-- Skript nic nemění a skončí ROLLBACKem; na produkci nebyl spuštěn.

begin;

do $$
declare
  v_failed integer;
begin
  if to_regclass('public.machine_calibration_profiles') is null
     or to_regclass('public.machine_calibrations') is null
     or to_regclass('public.machine_calibration_measurements') is null
     or to_regclass('public.machine_calibration_recipe_snapshots') is null then
    raise exception 'Některá tabulka kalibračního modulu chybí.';
  end if;

  if to_regprocedure('public.start_machine_calibration(bigint)') is null
     or to_regprocedure('public.save_machine_calibration_draft(bigint,jsonb,text)') is null
     or to_regprocedure('public.complete_machine_calibration(bigint,jsonb,text)') is null
     or to_regprocedure('public.cancel_machine_calibration(bigint,text)') is null then
    raise exception 'Některé kalibrační RPC chybí.';
  end if;

  if exists(
    select 1
    from pg_class
    where oid in (
      'public.machine_calibration_profiles'::regclass,
      'public.machine_calibrations'::regclass,
      'public.machine_calibration_measurements'::regclass,
      'public.machine_calibration_recipe_snapshots'::regclass
    ) and relrowsecurity is not true
  ) then
    raise exception 'RLS není zapnuté na všech kalibračních tabulkách.';
  end if;

  select count(*) into v_failed
  from (values
    ('Káva',7.41::numeric,2.2::numeric,21::numeric),
    ('Cukr',47,6,9),
    ('Smetana',31.77,8.4,19),
    ('Čokoláda',35.24,26,52),
    ('Bílá čokoláda',41.78,25,42),
    ('Matcha malina',26.73,25.5,67),
    ('Matcha pistácie',41.86,25.5,43),
    ('Irish',31.6,22,49)
  ) as sample(ingredient,weighed_g,required_g,expected_dsec)
  where round(required_g*70/weighed_g)<>expected_dsec;

  if v_failed>0 then
    raise exception 'Kontrolní kalibrační výpočty neprošly: % chyb.',v_failed;
  end if;
end;
$$;

rollback;
