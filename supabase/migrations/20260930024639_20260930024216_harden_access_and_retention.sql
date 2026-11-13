-- Index foreign keys used by ownership filters and notification joins.
create index if not exists idx_emergency_contacts_user_id
  on public.emergency_contacts (user_id);
create index if not exists idx_incident_notifications_contact_id
  on public.incident_notifications (contact_id);

-- Trigger and event-trigger functions retain their privileged owners, but are
-- not callable as RPC functions by API roles.
revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.rls_auto_enable() from public, anon, authenticated;

drop policy if exists "usuario ve su perfil" on public.profiles;
create policy "usuario ve su perfil" on public.profiles
  for select to public using ((select auth.uid()) = id);

drop policy if exists "usuario actualiza su perfil" on public.profiles;
create policy "usuario actualiza su perfil" on public.profiles
  for update to public
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

drop policy if exists "usuario gestiona sus contactos" on public.emergency_contacts;
create policy "usuario gestiona sus contactos" on public.emergency_contacts
  for all to public
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "usuario gestiona sus dispositivos" on public.devices;
create policy "usuario gestiona sus dispositivos" on public.devices
  for all to public
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "usuario inserta sus ubicaciones" on public.gps_locations;
create policy "usuario inserta sus ubicaciones" on public.gps_locations
  for insert to public with check ((select auth.uid()) = user_id);

drop policy if exists "usuario ve sus ubicaciones" on public.gps_locations;
create policy "usuario ve sus ubicaciones" on public.gps_locations
  for select to public using ((select auth.uid()) = user_id);

drop policy if exists "usuario gestiona sus incidentes" on public.incidents;
create policy "usuario gestiona sus incidentes" on public.incidents
  for all to public
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "usuario ve notificaciones de sus incidentes" on public.incident_notifications;
create policy "usuario ve notificaciones de sus incidentes" on public.incident_notifications
  for select to public using (
    exists (
      select 1 from public.incidents i
      where i.id = incident_notifications.incident_id
        and i.user_id = (select auth.uid())
    )
  );

-- Keep the existing daily jobs, but align their retention windows with the
-- approved policy: GPS points for 90 days; incidents and cascading alerts 1 year.
do $retention$
declare
  old_job record;
begin
  for old_job in
    select jobid from cron.job
    where jobname in ('cleanup-old-locations', 'cleanup-old-incidents')
  loop
    perform cron.unschedule(old_job.jobid);
  end loop;

  perform cron.schedule(
    'cleanup-old-locations',
    '0 3 * * *',
    $command$delete from public.gps_locations where recorded_at < now() - interval '90 days';$command$
  );
  perform cron.schedule(
    'cleanup-old-incidents',
    '0 4 * * *',
    $command$delete from public.incidents where created_at < now() - interval '1 year';$command$
  );
end;
$retention$;
