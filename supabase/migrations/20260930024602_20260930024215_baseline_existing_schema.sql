-- Baseline schema snapshot for the existing NexusRide Supabase project.
-- This migration is idempotent so it can both register the current remote
-- schema and bootstrap an empty project with the same application tables.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  avatar_url text,
  created_at timestamptz not null default now(),
  fcm_token text
);

create table if not exists public.emergency_contacts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  phone text not null,
  email text,
  relationship text default 'otro',
  notify_sms boolean default true,
  notify_push boolean default true,
  created_at timestamptz not null default now()
);

create table if not exists public.devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  mac_address text not null unique,
  name text default 'Mi casco',
  firmware_version text,
  battery_level integer check (battery_level >= 0 and battery_level <= 100),
  last_seen timestamptz,
  is_active boolean default true,
  created_at timestamptz not null default now()
);

create table if not exists public.gps_locations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  latitude double precision not null,
  longitude double precision not null,
  speed real,
  accuracy real,
  recorded_at timestamptz not null default now()
);

create table if not exists public.incidents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  latitude double precision not null,
  longitude double precision not null,
  g_force real,
  speed_at_impact real,
  status text default 'detected'
    check (status = any (array['detected', 'confirmed', 'cancelled']::text[])),
  notified_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.incident_notifications (
  id uuid primary key default gen_random_uuid(),
  incident_id uuid not null references public.incidents(id) on delete cascade,
  contact_id uuid references public.emergency_contacts(id) on delete set null,
  method text check (method = any (array['sms', 'push', 'whatsapp']::text[])),
  status text default 'pending'
    check (status = any (array['pending', 'sent', 'delivered', 'failed']::text[])),
  sent_at timestamptz not null default now()
);

create index if not exists idx_devices_user_active
  on public.devices (user_id, is_active);
create index if not exists idx_gps_user_time
  on public.gps_locations (user_id, recorded_at desc);
create index if not exists idx_notif_incident
  on public.incident_notifications (incident_id);
create index if not exists idx_incidents_user_status
  on public.incidents (user_id, status, created_at desc);

alter table public.profiles enable row level security;
alter table public.emergency_contacts enable row level security;
alter table public.devices enable row level security;
alter table public.gps_locations enable row level security;
alter table public.incidents enable row level security;
alter table public.incident_notifications enable row level security;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (
    new.id,
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'avatar_url'
  );
  return new;
end;
$function$;

do $function$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'on_auth_user_created'
      and tgrelid = 'auth.users'::regclass
      and not tgisinternal
  ) then
    create trigger on_auth_user_created
      after insert on auth.users
      for each row execute function public.handle_new_user();
  end if;
end;
$function$;

create or replace function public.rls_auto_enable()
returns event_trigger
language plpgsql
security definer
set search_path = pg_catalog
as $function$
declare
  cmd record;
begin
  for cmd in
    select * from pg_event_trigger_ddl_commands()
    where command_tag in ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      and object_type in ('table', 'partitioned table')
  loop
    if cmd.schema_name is not null
      and cmd.schema_name = 'public'
      and cmd.schema_name not in ('pg_catalog', 'information_schema')
      and cmd.schema_name not like 'pg_toast%'
      and cmd.schema_name not like 'pg_temp%' then
      begin
        execute format('alter table if exists %s enable row level security', cmd.object_identity);
        raise log 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      exception when others then
        raise log 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      end;
    end if;
  end loop;
end;
$function$;

do $function$
begin
  if not exists (select 1 from pg_event_trigger where evtname = 'ensure_rls') then
    create event trigger ensure_rls
      on ddl_command_end
      when tag in ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      execute function public.rls_auto_enable();
  end if;
end;
$function$;

do $policies$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='profiles' and policyname='usuario ve su perfil') then
    create policy "usuario ve su perfil" on public.profiles for select to public using (auth.uid() = id);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='profiles' and policyname='usuario actualiza su perfil') then
    create policy "usuario actualiza su perfil" on public.profiles for update to public using (auth.uid() = id);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='emergency_contacts' and policyname='usuario gestiona sus contactos') then
    create policy "usuario gestiona sus contactos" on public.emergency_contacts for all to public using (auth.uid() = user_id) with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='devices' and policyname='usuario gestiona sus dispositivos') then
    create policy "usuario gestiona sus dispositivos" on public.devices for all to public using (auth.uid() = user_id) with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='gps_locations' and policyname='usuario inserta sus ubicaciones') then
    create policy "usuario inserta sus ubicaciones" on public.gps_locations for insert to public with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='gps_locations' and policyname='usuario ve sus ubicaciones') then
    create policy "usuario ve sus ubicaciones" on public.gps_locations for select to public using (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='incidents' and policyname='usuario gestiona sus incidentes') then
    create policy "usuario gestiona sus incidentes" on public.incidents for all to public using (auth.uid() = user_id) with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='incident_notifications' and policyname='usuario ve notificaciones de sus incidentes') then
    create policy "usuario ve notificaciones de sus incidentes" on public.incident_notifications for select to public using (
      exists (
        select 1 from public.incidents i
        where i.id = incident_notifications.incident_id and i.user_id = auth.uid()
      )
    );
  end if;
end;
$policies$;
