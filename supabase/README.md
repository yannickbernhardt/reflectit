# Supabase-Härtung für ReflectIt

Reihenfolge im **Supabase Dashboard → SQL Editor → New query**:

1. **`01_schema_hardening.sql`** — Check-Constraints (Code-Format, Payload-Größe)
2. **`02_rls_policies.sql`** — Row Level Security aktivieren + Policies
3. **`03_auto_cleanup.sql`** — Automatische Löschung nach 24 h via pg_cron

## Vorher prüfen

Welche Spalten haben `sessions` und `responses` tatsächlich? Falls andere Namen
als `code`, `payload`, `session_code`, `created_at` → Skripte anpassen.

```sql
select table_name, column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name in ('sessions','responses')
order by table_name, ordinal_position;
```

## pg_cron Extension aktivieren

Dashboard → **Database → Extensions** → `pg_cron` einschalten (nur 1×).

## Testen nach Ausführung

```sql
-- RLS aktiv?
select schemaname, tablename, rowsecurity
from pg_tables where schemaname = 'public';

-- Policies vorhanden?
select schemaname, tablename, policyname, cmd
from pg_policies where schemaname = 'public';

-- Cron-Job läuft?
select jobname, schedule, active from cron.job;
```

## Manuell aufräumen (für Tests)

```sql
select public.reflectit_cleanup();
```

## Wichtig für NRW-Compliance

- **Region**: Vor Schul-Einsatz **zwingend** auf `eu-central-1` (Frankfurt)
  migrieren. Supabase bietet Region-Migration via Support-Ticket an, oder
  neues Projekt anlegen + Daten portieren.
- **AVV**: Dashboard → Organization → Legal → Data Processing Agreement
  unterzeichnen.
- **Backups**: In Datenschutzerklärung dokumentieren (Supabase behält
  Point-in-Time-Recovery je nach Plan 7–30 Tage).
