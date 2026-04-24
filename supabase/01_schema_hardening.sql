-- ============================================================================
-- ReflectIt — Schema Hardening für DSGVO / NRW-Schuldatenschutz
-- ============================================================================
-- Auszuführen im Supabase SQL Editor (Dashboard → SQL Editor → New query)
-- Reihenfolge: 01 → 02 → 03
--
-- Voraussetzung: Tabellen `sessions` und `responses` existieren bereits.
-- Falls Schema abweicht, Spaltennamen unten anpassen.
-- ============================================================================

-- 1) Check-Constraints: technische Grenzen erzwingen
--    Begrenzt Payload-Größe, Code-Format, Freitext-Länge auf DB-Ebene
--    (Defense-in-Depth zusätzlich zur Frontend-Validierung)
-- ----------------------------------------------------------------------------

-- Session-Code: exakt 6 Zeichen, Alphabet wie im Frontend (keine 0/1/I/O/etc.)
alter table public.sessions
  drop constraint if exists sessions_code_format;
alter table public.sessions
  add constraint sessions_code_format
  check (code ~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$');

-- Session-Payload (JSON): max 16 KB — verhindert DB-Bloat durch Missbrauch
alter table public.sessions
  drop constraint if exists sessions_payload_size;
alter table public.sessions
  add constraint sessions_payload_size
  check (octet_length(payload::text) <= 16384);

-- Response-Code muss auf gültige Session referenzieren (Format-Check)
alter table public.responses
  drop constraint if exists responses_code_format;
alter table public.responses
  add constraint responses_code_format
  check (session_code ~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$');

-- Response-Payload: max 8 KB pro Antwort
-- Freitext ist im Frontend auf 240 Zeichen begrenzt → 8 KB sind großzügig
alter table public.responses
  drop constraint if exists responses_payload_size;
alter table public.responses
  add constraint responses_payload_size
  check (octet_length(payload::text) <= 8192);

-- 2) IP-Adressen nicht speichern
--    Falls irgendwo ip / client_ip / user_agent Spalten existieren: droppen.
--    (Vorher prüfen: select column_name from information_schema.columns
--     where table_name in ('sessions','responses');)
-- ----------------------------------------------------------------------------

-- Beispiel — nur ausführen, falls Spalten existieren:
-- alter table public.sessions  drop column if exists ip;
-- alter table public.sessions  drop column if exists user_agent;
-- alter table public.responses drop column if exists ip;
-- alter table public.responses drop column if exists user_agent;

-- 3) Hinweis: Nach Abschluss dieses Skripts Datei 02_rls_policies.sql ausführen.
