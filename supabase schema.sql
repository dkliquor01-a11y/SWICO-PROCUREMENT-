-- ProcureTrack · Supabase schema with role-based access (run once in Supabase → SQL Editor)

create table if not exists public.profiles(
  id uuid primary key references auth.users on delete cascade,
  email text,
  name text not null,
  role text not null check (role in ('sysadmin','executive','committee','procurement_officer','stock_manager')),
  sign_as text[] not null default '{}',      -- titles this person may sign as, e.g. {'Chief Finance Officer'} or {'CEO'}
  active boolean not null default true
);

create table if not exists public.records(
  collection text not null,                  -- pr, sup, item, mv, grn, book, asset, cfg, sig
  id text not null,
  data jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid(),
  primary key (collection,id)
);

-- helpers (security definer so they can read profiles regardless of RLS)
create or replace function public.my_role() returns text language sql stable security definer set search_path=public as
$$ select role from public.profiles where id=auth.uid() and active $$;

-- WHO CAN READ WHAT
create or replace function public.can_read(col text) returns boolean language sql stable security definer set search_path=public as $$
  select case public.my_role()
    when 'sysadmin' then true
    when 'executive' then true
    when 'committee' then true
    when 'procurement_officer' then col in ('pr','sup','sig','cfg','grn')
    when 'stock_manager' then col in ('item','mv','grn','book','asset','pr','cfg')
    else false end $$;

-- WHO CAN CHANGE WHAT
create or replace function public.can_write(col text) returns boolean language sql stable security definer set search_path=public as $$
  select case public.my_role()
    when 'procurement_officer' then col in ('pr','sup')
    when 'stock_manager' then col in ('item','mv','grn','book','asset')
    when 'sysadmin' then col = 'cfg'
    else false end $$;

-- WHO CAN SIGN (a person may only sign as a title listed in their own profile, under their own name)
create or replace function public.can_sign(r text, signer text) returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.profiles where id=auth.uid() and active and r = any(sign_as) and name = signer) $$;

alter table public.records  enable row level security;
alter table public.profiles enable row level security;

create policy rec_select on public.records for select to authenticated using (public.can_read(collection));
create policy rec_insert on public.records for insert to authenticated
  with check (public.can_write(collection) or (collection='sig' and public.can_sign(data->>'role', data->>'by')));
create policy rec_update on public.records for update to authenticated
  using (public.can_write(collection)) with check (public.can_write(collection));   -- signatures can never be edited
create policy rec_delete on public.records for delete to authenticated
  using (public.can_write(collection));                                             -- ...or deleted

create policy prof_select on public.profiles for select to authenticated using (id=auth.uid() or public.my_role()='sysadmin');
create policy prof_admin  on public.profiles for all    to authenticated using (public.my_role()='sysadmin') with check (public.my_role()='sysadmin');

-- live updates
alter publication supabase_realtime add table public.records;

-- private bucket for scanned documents
insert into storage.buckets(id,name,public) values('docs','docs',false) on conflict do nothing;
create policy docs_read  on storage.objects for select to authenticated using (bucket_id='docs' and public.my_role() is not null);
create policy docs_write on storage.objects for insert to authenticated with check (bucket_id='docs' and public.my_role() in ('procurement_officer','stock_manager'));

-- ---------- ADD PEOPLE ----------
-- 1) Dashboard → Authentication → Users → "Add user" (email + password). 2) Then run one line per person:
-- insert into public.profiles(id,email,name,role,sign_as) select id,email,'Full Name','sysadmin','{}' from auth.users where email='admin@company.com';
-- insert into public.profiles(id,email,name,role,sign_as) select id,email,'Full Name','procurement_officer','{"Procurement Officer"}' from auth.users where email='po@company.com';
-- insert into public.profiles(id,email,name,role,sign_as) select id,email,'Full Name','stock_manager','{}' from auth.users where email='store@company.com';
-- insert into public.profiles(id,email,name,role,sign_as) select id,email,'Full Name','committee','{"Chief Finance Officer"}' from auth.users where email='cfo@company.com';
-- insert into public.profiles(id,email,name,role,sign_as) select id,email,'Full Name','committee','{"Head Legal"}' from auth.users where email='legal@company.com';
-- insert into public.profiles(id,email,name,role,sign_as) select id,email,'Full Name','committee','{"Manager Corporate Affairs"}' from auth.users where email='corp@company.com';
-- insert into public.profiles(id,email,name,role,sign_as) select id,email,'Full Name','committee','{"Senior HRA"}' from auth.users where email='hr@company.com';
-- insert into public.profiles(id,email,name,role,sign_as) select id,email,'Full Name','committee','{"Head IT"}' from auth.users where email='it@company.com';
-- insert into public.profiles(id,email,name,role,sign_as) select id,email,'Full Name','executive','{"CEO"}' from auth.users where email='ceo@company.com';
