-- Todo-Liste: Datenbankschema für Supabase
-- Im Supabase-Dashboard unter "SQL Editor" komplett einfügen und auf "Run" klicken.
-- Das Skript kann gefahrlos mehrfach ausgeführt werden.
--
-- Jede Tabelle hat:
--   user_id    – wem die Zeile gehört (wird automatisch auf den angemeldeten User gesetzt)
--   updated_at – Zeitpunkt der letzten Änderung am Gerät
--   field_times – wann welches Feld zuletzt geändert wurde (JSON, z. B. {"title": "…", "due": "…"}).
--                 Damit gewinnt bei Konflikten je Feld der neuere Wert statt der ganzen Zeile.
--   synced_at  – wann die Zeile beim Server angekommen ist (die App lädt nur Neues herunter)
--   deleted    – "Grabstein": gelöschte Einträge bleiben kurz da, damit andere Geräte es erfahren
-- Row Level Security: jeder sieht und ändert nur seine eigenen Zeilen.

-- 1) Tabellen -----------------------------------------------------------------

create table if not exists public.categories (
  id          uuid        primary key,
  user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
  name        text        not null check (char_length(name) between 1 and 300),
  color       text        not null check (color ~ '^#[0-9A-Fa-f]{6}$'),
  offset_days smallint    not null default 0 check (offset_days between 0 and 30),
  position    integer     not null default 0,
  updated_at  timestamptz not null default now(),
  synced_at   timestamptz not null default now(),
  deleted     boolean     not null default false
);

create table if not exists public.tasks (
  id          uuid        primary key,
  user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
  title       text        not null check (char_length(title) between 1 and 2000),
  category_id uuid        not null,
  due_date    date        not null,
  due_time    time,
  done        boolean     not null default false,
  done_at     timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  synced_at   timestamptz not null default now(),
  deleted     boolean     not null default false
);

create table if not exists public.subtasks (
  id          uuid        primary key,
  user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
  task_id     uuid        not null,
  title       text        not null check (char_length(title) between 1 and 1200),
  done        boolean     not null default false,
  position    integer     not null default 0,
  updated_at  timestamptz not null default now(),
  synced_at   timestamptz not null default now(),
  deleted     boolean     not null default false
);

create table if not exists public.habits (
  id          uuid        primary key,
  user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
  name        text        not null check (char_length(name) between 1 and 400),
  color       text        not null check (color ~ '^#[0-9A-Fa-f]{6}$'),
  position    integer     not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  synced_at   timestamptz not null default now(),
  deleted     boolean     not null default false
);

create table if not exists public.habit_logs (
  habit_id    uuid        not null,
  day         date        not null,
  user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
  done        boolean     not null default true,
  updated_at  timestamptz not null default now(),
  synced_at   timestamptz not null default now(),
  primary key (habit_id, day)
);

create table if not exists public.week_blocks (
  id          uuid        primary key,
  user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
  name        text        not null check (char_length(name) between 1 and 600),
  color       text        not null check (color ~ '^#[0-9A-Fa-f]{6}$'),
  day         smallint    not null check (day between 0 and 6),
  start_min   smallint    not null check (start_min between 0 and 1439),
  end_min     smallint    not null check (end_min between 1 and 1440),
  repeat      boolean     not null default true,
  week_start  date,
  updated_at  timestamptz not null default now(),
  synced_at   timestamptz not null default now(),
  deleted     boolean     not null default false,
  check (end_min > start_min)
);

create table if not exists public.settings (
  user_id     uuid        primary key default auth.uid() references auth.users (id) on delete cascade,
  lang        text        not null default 'de' check (lang in ('de', 'en')),
  theme       text        not null default 'himmel',
  mode        text        not null default 'light' check (mode in ('light', 'dark', 'system')),
  raster      smallint    not null default 15 check (raster in (5, 15, 30)),
  day_start   smallint    not null default 6 check (day_start between 4 and 10),
  day_end     smallint    not null default 22 check (day_end between 16 and 24),
  remind      boolean     not null default true,
  updated_at  timestamptz not null default now(),
  synced_at   timestamptz not null default now()
);

-- Längen-Grenzen: Die App begrenzt auf sichtbare Zeichen (30, 200, …). Postgres zählt
-- Codepunkte, und ein Emoji kann aus bis zu ~10 bestehen – daher hier das Zehnfache als
-- reine Schutzgrenze. Auch für schon angelegte Datenbanken neu setzen:
alter table public.categories  drop constraint if exists categories_name_check;
alter table public.categories  add  constraint categories_name_check  check (char_length(name) between 1 and 300);
alter table public.tasks       drop constraint if exists tasks_title_check;
alter table public.tasks       add  constraint tasks_title_check       check (char_length(title) between 1 and 2000);
alter table public.subtasks    drop constraint if exists subtasks_title_check;
alter table public.subtasks    add  constraint subtasks_title_check    check (char_length(title) between 1 and 1200);
alter table public.habits      drop constraint if exists habits_name_check;
alter table public.habits      add  constraint habits_name_check      check (char_length(name) between 1 and 400);
alter table public.week_blocks drop constraint if exists week_blocks_name_check;
alter table public.week_blocks add  constraint week_blocks_name_check check (char_length(name) between 1 and 600);

-- Spalten, die später dazugekommen sind (für schon angelegte Datenbanken):
alter table public.tasks add column if not exists notes text not null default '';
alter table public.tasks drop constraint if exists tasks_notes_check;
alter table public.tasks add  constraint tasks_notes_check check (char_length(notes) <= 20000);
alter table public.categories add column if not exists list_from text not null default 'always';
alter table public.categories drop constraint if exists categories_list_from_check;
alter table public.categories add  constraint categories_list_from_check
  check (list_from in ('always', 'week', 'tomorrow', 'today', 'never'));

alter table public.categories  add column if not exists field_times jsonb;
alter table public.tasks       add column if not exists field_times jsonb;
alter table public.subtasks    add column if not exists field_times jsonb;
alter table public.habits      add column if not exists field_times jsonb;
alter table public.week_blocks add column if not exists field_times jsonb;

-- 2) Sync-Regeln: je Feld gewinnt der neuere Wert, synced_at setzt der Server ---
--
-- Ändern zwei Geräte dieselbe Zeile (z. B. offline am Handy den Titel, am PC das Datum),
-- sollen beide Änderungen gelten. Dafür schickt die App in field_times je Feld-Gruppe den
-- Zeitpunkt der letzten Änderung mit. Der Trigger vergleicht je Gruppe alt und neu und
-- behält den neueren Wert. Welche Spalten eine Gruppe bilden, steht unten beim Anlegen der
-- Trigger (Datum und Uhrzeit gehören zusammen, ebenso "erledigt" und "erledigt am").
--
-- Dieselbe Regel steht in der App in lib/data/field_merge.dart – beide Stellen gemeinsam ändern.
--
-- Zeilen ohne brauchbare Zeitstempel werden wie früher behandelt: Die ganze Zeile mit dem
-- neueren updated_at gewinnt. Das betrifft alte Zeilen, Tabellen ohne Gruppen (habit_logs,
-- settings) und ältere App-Versionen. Die kennen field_times nicht und ändern nur updated_at –
-- daran erkennt der Trigger sie: Brauchbar sind Zeitstempel nur, wenn der jüngste genau
-- updated_at ist.

-- Die Zeitstempel einer Zeile als JSON – oder null, wenn sie nicht brauchbar sind.
create or replace function public.sync_field_times(times jsonb, updated_at timestamptz)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  latest timestamptz;
begin
  if times is null or jsonb_typeof(times) <> 'object' or times = '{}'::jsonb then
    return null;
  end if;
  select max(value::timestamptz) into latest from jsonb_each_text(times);
  if latest is distinct from updated_at then
    return null;
  end if;
  return times;
exception when others then
  -- Unlesbarer Inhalt: wie eine Zeile ohne Zeitstempel behandeln
  return null;
end;
$$;

create or replace function public.sync_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  -- Feld-Gruppen dieser Tabelle: {"gruppe": ["spalte", ...]}; ohne Angabe gilt die ganze Zeile
  grps      jsonb := case when tg_nargs > 0 then tg_argv[0]::jsonb end;
  new_times jsonb;
  old_times jsonb;
  old_row   jsonb;
  grp       text;
  cols      jsonb;
  col       text;
  new_at    timestamptz;
  old_at    timestamptz;
  keep      jsonb := '{}'::jsonb;  -- Spalten, die ihren alten Wert behalten
  times     jsonb := '{}'::jsonb;  -- Zeitstempel der zusammengeführten Zeile
  won       boolean := false;
begin
  if tg_op = 'UPDATE' then
    -- Eine Zeile kann nie einem anderen User "geschenkt" werden
    new.user_id := old.user_id;
    if grps is not null then
      old_row   := to_jsonb(old);
      new_times := public.sync_field_times(to_jsonb(new) -> 'field_times', new.updated_at);
      old_times := public.sync_field_times(old_row -> 'field_times', old.updated_at);
    end if;
    if new_times is null or old_times is null then
      -- Wie früher: Ein älterer Stand darf einen neueren nicht überschreiben
      if new.updated_at < old.updated_at then
        return null;
      end if;
      -- Derselbe Stand noch einmal, aber ohne Zeitstempel je Feld (ältere App-Version):
      -- nichts ändern, sonst gingen die vorhandenen Zeitstempel verloren
      if grps is not null and new_times is null and new.updated_at = old.updated_at then
        return null;
      end if;
      -- Die neue Zeile gilt als Ganzes. Passen ihre Zeitstempel nicht zu ihr (ältere
      -- App-Version), verfallen sie.
      if grps is not null and new_times is null then
        new := jsonb_populate_record(new, jsonb_build_object('field_times', null));
      end if;
    else
      -- Je Gruppe gewinnt der neuere Wert
      for grp, cols in select key, value from jsonb_each(grps) loop
        new_at := coalesce((new_times ->> grp)::timestamptz, new.updated_at);
        old_at := coalesce((old_times ->> grp)::timestamptz, old.updated_at);
        if new_at > old_at then
          won   := true;
          times := times || jsonb_build_object(grp, new_at);
        else
          times := times || jsonb_build_object(grp, old_at);
          for col in select jsonb_array_elements_text(cols) loop
            keep := keep || jsonb_build_object(col, old_row -> col);
          end loop;
        end if;
      end loop;
      -- Nichts Neueres dabei: Die Zeile bleibt, wie sie ist
      if not won then
        return null;
      end if;
      keep := keep || jsonb_build_object(
        'field_times', times,
        'updated_at', greatest(new.updated_at, old.updated_at)
      );
      new := jsonb_populate_record(new, keep);
    end if;
  end if;
  new.synced_at := now();
  return new;
end;
$$;

do $$
declare
  t text;
  -- Feld-Gruppen je Tabelle (dieselben wie in der App: lib/data/local_db.dart).
  -- Tabellen, die hier fehlen, gewinnen oder verlieren als ganze Zeile.
  field_groups constant jsonb := '{
    "categories":  {"name": ["name"], "color": ["color"], "offset": ["offset_days"], "list_from": ["list_from"], "position": ["position"], "deleted": ["deleted"]},
    "tasks":       {"title": ["title"], "notes": ["notes"], "category": ["category_id"], "due": ["due_date", "due_time"], "done": ["done", "done_at"], "deleted": ["deleted"]},
    "subtasks":    {"title": ["title"], "done": ["done"], "position": ["position"], "deleted": ["deleted"]},
    "habits":      {"name": ["name"], "color": ["color"], "position": ["position"], "deleted": ["deleted"]},
    "week_blocks": {"name": ["name"], "color": ["color"], "time": ["day", "start_min", "end_min", "repeat", "week_start"], "deleted": ["deleted"]}
  }';
begin
  foreach t in array array['categories', 'tasks', 'subtasks', 'habits', 'habit_logs', 'week_blocks', 'settings'] loop
    execute format('drop trigger if exists %I on public.%I', t || '_sync_guard', t);
    if field_groups ? t then
      execute format('create trigger %I before insert or update on public.%I for each row execute function public.sync_guard(%L)', t || '_sync_guard', t, field_groups -> t);
    else
      execute format('create trigger %I before insert or update on public.%I for each row execute function public.sync_guard()', t || '_sync_guard', t);
    end if;
    execute format('create index if not exists %I on public.%I (user_id, synced_at)', t || '_user_synced_idx', t);

    -- 3) Row Level Security: nur eigene Zeilen
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists %I on public.%I', t || '_select_own', t);
    execute format('create policy %I on public.%I for select to authenticated using ((select auth.uid()) = user_id)', t || '_select_own', t);
    execute format('drop policy if exists %I on public.%I', t || '_insert_own', t);
    execute format('create policy %I on public.%I for insert to authenticated with check ((select auth.uid()) = user_id)', t || '_insert_own', t);
    execute format('drop policy if exists %I on public.%I', t || '_update_own', t);
    execute format('create policy %I on public.%I for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)', t || '_update_own', t);
    execute format('drop policy if exists %I on public.%I', t || '_delete_own', t);
    execute format('create policy %I on public.%I for delete to authenticated using ((select auth.uid()) = user_id)', t || '_delete_own', t);

    -- 4) Realtime: andere Geräte bekommen Änderungen sofort mit
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end;
$$;

-- Supabase (PostgREST) neue Spalten sofort bekannt machen
notify pgrst, 'reload schema';
