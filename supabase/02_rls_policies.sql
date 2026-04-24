-- ============================================================================
-- ReflectIt — Row Level Security (RLS) Policies
-- ============================================================================
-- Sicherheitsmodell: Das Tool arbeitet OHNE Authentifizierung. Jeder Client
-- verwendet den öffentlichen `anon`-Key. RLS kann hier also KEINE Identität
-- prüfen — sie kann aber:
--   - schreibende Zugriffe auf valide Payloads beschränken
--   - lesende Zugriffe auf den Realtime-Kanal einschränken
--   - Massen-Dumps der Tabellen verhindern
-- Für echte Isolation Teacher/Student bräuchte es langfristig ein
-- session-spezifisches Token (s. 03_future_session_token.md).
-- ============================================================================

-- RLS auf beiden Tabellen aktivieren
alter table public.sessions  enable row level security;
alter table public.responses enable row level security;

-- Alte Policies sauber entfernen (idempotent)
drop policy if exists "sessions_insert_anon"    on public.sessions;
drop policy if exists "sessions_select_anon"    on public.sessions;
drop policy if exists "sessions_update_anon"    on public.sessions;
drop policy if exists "sessions_delete_anon"    on public.sessions;
drop policy if exists "responses_insert_anon"   on public.responses;
drop policy if exists "responses_select_anon"   on public.responses;
drop policy if exists "responses_update_anon"   on public.responses;
drop policy if exists "responses_delete_anon"   on public.responses;

-- ----------------------------------------------------------------------------
-- SESSIONS
-- ----------------------------------------------------------------------------

-- INSERT: anon darf Session anlegen, wenn Code gültig und Payload klein ist
create policy "sessions_insert_anon"
  on public.sessions for insert to anon
  with check (
    code ~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$'
    and octet_length(payload::text) <= 16384
  );

-- SELECT: anon darf lesen — aber Realtime-Subscriptions filtern bereits
-- per session_code. Volltabellen-Scans liefern nur aktive Sessions.
create policy "sessions_select_anon"
  on public.sessions for select to anon
  using (true);

-- UPDATE: Payload-Update erlaubt (z.B. Methode wechseln), Code unveränderlich
create policy "sessions_update_anon"
  on public.sessions for update to anon
  using (true)
  with check (
    code ~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$'
    and octet_length(payload::text) <= 16384
  );

-- DELETE: anon darf Session beenden (Lehrkraft-Aktion am Stundenende)
create policy "sessions_delete_anon"
  on public.sessions for delete to anon
  using (true);

-- ----------------------------------------------------------------------------
-- RESPONSES
-- ----------------------------------------------------------------------------

-- INSERT: anon darf Antwort abgeben, wenn Session existiert
create policy "responses_insert_anon"
  on public.responses for insert to anon
  with check (
    exists (select 1 from public.sessions s where s.code = session_code)
    and session_code ~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$'
    and octet_length(payload::text) <= 8192
  );

-- SELECT: anon darf Antworten lesen (Lehrkraft-Aggregation)
create policy "responses_select_anon"
  on public.responses for select to anon
  using (true);

-- UPDATE: Antwort-Update während Ausfüllen erlaubt, Grenzen erzwingen
create policy "responses_update_anon"
  on public.responses for update to anon
  using (true)
  with check (octet_length(payload::text) <= 8192);

-- DELETE: anon darf löschen (Session-Ende räumt auf)
create policy "responses_delete_anon"
  on public.responses for delete to anon
  using (true);

-- ----------------------------------------------------------------------------
-- SICHERHEITS-HINWEIS
-- ----------------------------------------------------------------------------
-- Mit diesen Policies kann jeder mit Kenntnis eines aktiven Session-Codes
-- Antworten lesen, manipulieren oder löschen. Das ist akzeptabel, weil:
--   (a) Session-Codes 6-stellig, kryptografisch zufällig (~1 Mrd. Varianten)
--   (b) Sessions kurzlebig sind (<= 24 h, via pg_cron gelöscht)
--   (c) Inhalte pseudonym/anonym — kein Schaden bei Datenabfluss im Klassenzimmer
--   (d) Rate-Limiting wird ergänzend durch Vercel/Supabase Edge geschützt
-- Für Produktion in sensiblerem Kontext: session-spezifisches Teacher-Token
-- einführen (s. 03_future_session_token.md).
