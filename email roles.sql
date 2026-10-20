-- ProcureTrack · automatic roles from email names
-- Run in Supabase → SQL Editor, AFTER supabase_schema.sql.
-- Rule: <prefix><number>@swico.co.ug  →  role.   e.g. stockmanager02@swico.co.ug = stock manager.

create table if not exists public.email_rules(
  prefix text primary key,
  role text not null,
  sign_as text[] not null default '{}',
  label text
);

insert into public.email_rules(prefix,role,sign_as,label) values
 ('admin',        'sysadmin',            '{}',                              'Administrator'),
 ('procurement',  'procurement_officer', '{"Procurement Officer"}',         'Procurement officer'),
 ('stockmanager', 'stock_manager',       '{}',                              'Stock manager'),
 ('cfo',          'committee',           '{"Chief Finance Officer"}',       'Chief Finance Officer'),
 ('legal',        'committee',           '{"Head Legal"}',                  'Head Legal'),
 ('corporate',    'committee',           '{"Manager Corporate Affairs"}',   'Manager Corporate Affairs'),
 ('hra',          'committee',           '{"Senior HRA"}',                  'Senior HRA'),
 ('headit',       'committee',           '{"Head IT"}',                     'Head IT'),
 ('ceo',          'executive',           '{"CEO"}',                         'CEO')
on conflict (prefix) do update set role=excluded.role, sign_as=excluded.sign_as, label=excluded.label;

alter table public.email_rules enable row level security;   -- no policies: only the trigger below can read it

-- every NEW user gets a profile automatically
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $fn$
declare r public.email_rules;
begin
  select * into r from public.email_rules
   where lower(new.email) ~ ('^' || prefix || '[0-9]+@swico\.co\.ug$') limit 1;
  if found then
    insert into public.profiles(id,email,name,role,sign_as)
    values(new.id,new.email,initcap(split_part(new.email,'@',1)),r.role,r.sign_as)
    on conflict (id) do update set role=excluded.role, sign_as=excluded.sign_as, email=excluded.email;
  end if;
  return new;
end $fn$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- users that ALREADY exist get their profile now
insert into public.profiles(id,email,name,role,sign_as)
select u.id,u.email,initcap(split_part(u.email,'@',1)),r.role,r.sign_as
from auth.users u
join public.email_rules r on lower(u.email) ~ ('^' || r.prefix || '[0-9]+@swico\.co\.ug$')
on conflict (id) do update set role=excluded.role, sign_as=excluded.sign_as;

-- Optional: give someone their real name (it appears on their signatures)
-- update public.profiles set name='Jane Doe' where email='cfo01@swico.co.ug';
