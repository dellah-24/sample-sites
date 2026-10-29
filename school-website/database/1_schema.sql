-- Sample School: run this in Supabase > SQL Editor
create table profiles(id uuid primary key references auth.users on delete cascade,full_name text,role text not null default 'student' check(role in('student','teacher','admin')),class_name text,created_at timestamptz default now());
create table announcements(id bigint generated always as identity primary key,title text not null,body text,is_public boolean default true,author uuid default auth.uid(),created_at timestamptz default now());
create table events(id bigint generated always as identity primary key,title text not null,event_date date not null,location text);
create table grades(id bigint generated always as identity primary key,student_id uuid references profiles on delete cascade,subject text not null,term text not null,score numeric not null check(score between 0 and 100),teacher_id uuid default auth.uid(),created_at timestamptz default now());
create table attendance(id bigint generated always as identity primary key,student_id uuid references profiles on delete cascade,day date not null default current_date,status text not null check(status in('present','absent','late')),unique(student_id,day));
create table applications(id bigint generated always as identity primary key,student_name text not null,grade_level text,guardian_name text,email text not null,phone text,notes text,status text default 'new',created_at timestamptz default now());
create table messages(id bigint generated always as identity primary key,name text not null,email text not null,body text not null,created_at timestamptz default now());

create function app_role() returns text language sql stable security definer set search_path=public as $$select role from profiles where id=auth.uid()$$;
create function handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$begin insert into profiles(id,full_name) values(new.id,coalesce(new.raw_user_meta_data->>'full_name',new.email));return new;end$$;
create trigger on_signup after insert on auth.users for each row execute function handle_new_user();

alter table profiles enable row level security;alter table announcements enable row level security;alter table events enable row level security;alter table grades enable row level security;alter table attendance enable row level security;alter table applications enable row level security;alter table messages enable row level security;

create policy p_sel on profiles for select using(id=auth.uid() or app_role() in('teacher','admin'));
create policy p_upd on profiles for update using(app_role()='admin');
create policy a_sel on announcements for select using(is_public or auth.uid() is not null);
create policy a_ins on announcements for insert with check(app_role() in('teacher','admin'));
create policy a_del on announcements for delete using(app_role()='admin');
create policy e_sel on events for select using(true);
create policy e_all on events for all using(app_role()='admin') with check(app_role()='admin');
create policy g_sel on grades for select using(student_id=auth.uid() or app_role() in('teacher','admin'));
create policy g_ins on grades for insert with check(app_role() in('teacher','admin'));
create policy t_sel on attendance for select using(student_id=auth.uid() or app_role() in('teacher','admin'));
create policy t_ins on attendance for insert with check(app_role() in('teacher','admin'));
create policy t_upd on attendance for update using(app_role() in('teacher','admin'));
create policy ap_ins on applications for insert with check(true);
create policy ap_sel on applications for select using(app_role()='admin');
create policy ap_upd on applications for update using(app_role()='admin');
create policy m_ins on messages for insert with check(true);
create policy m_sel on messages for select using(app_role()='admin');

insert into announcements(title,body) values('Welcome to Sample School','Applications for the new term are now open. Visit the Admissions page to apply.');
insert into events(title,event_date,location) values('Open Day',current_date+21,'Main Campus'),('Inter-House Sports',current_date+45,'School Field');
-- After you sign up, make yourself admin:
-- update profiles set role='admin' where id=(select id from auth.users where email='YOU@EXAMPLE.COM');
