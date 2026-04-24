-- ============================================================================
-- ReflectIt — Automatische Löschung alter Sessions
-- ============================================================================
-- Löscht Sessions + Responses, die älter als 24 Stunden sind.
-- Erfüllt DSGVO Art. 5 Abs. 1 lit. e (Speicherbegrenzung) + Art. 17 (Löschung).
--
-- Voraussetzung: pg_cron Extension aktivieren
--   Dashboard → Database → Extensions → "pg_cron" einschalten
-- ============================================================================

-- 1) Löschfunktion definieren
create or replace function public.reflectit_cleanup()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  cutoff timestamptz := now() - interval '24 hours';
  deleted_responses int;
  deleted_sessions  int;
begin
  -- Zuerst Antworten, die zu alten Sessions gehören
  with del as (
    delete from public.responses r
    using public.sessions s
    where r.session_code = s.code
      and s.created_at < cutoff
    returning 1
  )
  select count(*) into deleted_responses from del;

  -- Dann die Sessions selbst
  with del as (
    delete from public.sessions
    where created_at < cutoff
    returning 1
  )
  select count(*) into deleted_sessions from del;

  -- Orphan-Responses ohne Session (Safety-Net)
  delete from public.responses r
  where not exists (
    select 1 from public.sessions s where s.code = r.session_code
  );

  raise notice 'reflectit_cleanup: removed % sessions, % responses',
    deleted_sessions, deleted_responses;
end;
$$;

-- 2) Cron-Job: jede Stunde zur vollen Stunde ausführen
--    (Supabase pg_cron läuft in UTC)
select cron.unschedule('reflectit-cleanup') where exists (
  select 1 from cron.job where jobname = 'reflectit-cleanup'
);

select cron.schedule(
  'reflectit-cleanup',
  '0 * * * *',                     -- stündlich
  $$select public.reflectit_cleanup();$$
);

-- 3) Prüfen, dass Job angelegt wurde:
-- select * from cron.job where jobname = 'reflectit-cleanup';
-- select * from cron.job_run_details where jobname = 'reflectit-cleanup'
--   order by start_time desc limit 5;

-- ============================================================================
-- HINWEIS ZUR RETENTION
-- ============================================================================
-- 24 h ist ein pragmatischer Wert für Unterrichtsreflexion: genug Zeit für
-- eine Nachbesprechung am nächsten Tag, kurz genug für Datenschutz.
-- Falls kürzer gewünscht: `interval '4 hours'` oder `'8 hours'`.
-- Die tatsächliche Retention muss in der Datenschutzerklärung dokumentiert
-- werden (Kriterien für Speicherdauer, Art. 13 Abs. 2 lit. a DSGVO).
