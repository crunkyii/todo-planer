-- Todo-Liste: Datenbankschema für Supabase
-- Im Supabase-Dashboard unter "SQL Editor" komplett einfügen und auf "Run" klicken.
-- Das Skript kann gefahrlos mehrfach ausgeführt werden.
--
-- Jede Tabelle hat:
--   user_id    – wem die Zeile gehört (wird automatisch auf den angemeldeten User gesetzt)
--   updated_at – Zeitpunkt der letzten Änderung am Gerät; bei Konflikten gewinnt der neueste
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

-- 2) Sync-Regeln: neuester Stand gewinnt, synced_at setzt der Server ------------

create or replace function public.sync_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    -- Ein älterer Stand darf einen neueren nicht überschreiben
    if new.updated_at < old.updated_at then
      return null;
    end if;
    -- Eine Zeile kann nie einem anderen User "geschenkt" werden
    new.user_id := old.user_id;
  end if;
  new.synced_at := now();
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array['categories', 'tasks', 'subtasks', 'habits', 'habit_logs', 'week_blocks', 'settings'] loop
    execute format('drop trigger if exists %I on public.%I', t || '_sync_guard', t);
    execute format('create trigger %I before insert or update on public.%I for each row execute function public.sync_guard()', t || '_sync_guard', t);
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
