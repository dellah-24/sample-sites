-- Run AFTER schema.sql. Adds registrar + bursar roles, fees, and demo accounts.
alter table profiles drop constraint profiles_role_check;
alter table profiles add constraint profiles_role_check check(role in('student','teacher','registrar','bursar','admin'));
create table fees(id bigint generated always as identity primary key,student_id uuid references profiles on delete cascade,term text not null,amount numeric not null,paid numeric not null default 0,created_at timestamptz default now());
alter table fees enable row level security;
create policy f_sel on fees for select using(student_id=auth.uid() or app_role() in('bursar','admin'));
create policy f_ins on fees for insert with check(app_role() in('bursar','admin'));
create policy f_upd on fees for update using(app_role() in('bursar','admin'));
drop policy p_sel on profiles;create policy p_sel on profiles for select using(id=auth.uid() or app_role() in('teacher','admin','registrar','bursar'));
drop policy a_ins on announcements;create policy a_ins on announcements for insert with check(app_role() in('teacher','admin','registrar'));
drop policy ap_sel on applications;create policy ap_sel on applications for select using(app_role() in('admin','registrar'));
drop policy ap_upd on applications;create policy ap_upd on applications for update using(app_role() in('admin','registrar'));
drop policy m_sel on messages;create policy m_sel on messages for select using(app_role() in('admin','registrar'));

-- Demo accounts (password for all: Demo@12345)
do $$
declare u record;uid uuid;
begin
for u in select * from(values
 ('admin@sampleschool.test','Ada Admin','admin'),('teacher@sampleschool.test','Tom Teacher','teacher'),
 ('registrar@sampleschool.test','Rita Registrar','registrar'),('bursar@sampleschool.test','Ben Bursar','bursar'),
 ('pupil@sampleschool.test','Peter Pupil','student'),('pupil2@sampleschool.test','Grace Pupil','student')
) as t(email,full_name,role) loop
 if exists(select 1 from auth.users where email=u.email) then continue; end if;
 uid:=gen_random_uuid();
 insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,email_change,email_change_token_new,recovery_token)
 values('00000000-0000-0000-0000-000000000000',uid,'authenticated','authenticated',u.email,extensions.crypt('Demo@12345',extensions.gen_salt('bf')),now(),'{"provider":"email","providers":["email"]}',jsonb_build_object('full_name',u.full_name),now(),now(),'','','','');
 insert into auth.identities(id,user_id,provider_id,identity_data,provider,last_sign_in_at,created_at,updated_at)
 values(gen_random_uuid(),uid,uid::text,jsonb_build_object('sub',uid::text,'email',u.email),'email',now(),now(),now());
 update public.profiles set role=u.role where id=uid;
end loop;
end$$;

-- Sample records for the two demo pupils
insert into grades(student_id,subject,term,score) select p.id,s.subject,'Term 1',s.score from profiles p join auth.users a on a.id=p.id cross join (values('Mathematics',82),('English',74),('Science',91),('History',68)) s(subject,score) where a.email like 'pupil%@sampleschool.test';
insert into attendance(student_id,day,status) select p.id,current_date-d,case when d=2 then 'absent' when d=4 then 'late' else 'present' end from profiles p join auth.users a on a.id=p.id cross join generate_series(0,6) as d where a.email like 'pupil%@sampleschool.test';
insert into fees(student_id,term,amount,paid) select p.id,'Term 1',1200,case when a.email='pupil@sampleschool.test' then 1200 else 700 end from profiles p join auth.users a on a.id=p.id where a.email like 'pupil%@sampleschool.test';
insert into applications(student_name,grade_level,guardian_name,email) values('Mia Okoro','Grade 7','J. Okoro','jokoro@example.com');
insert into messages(name,email,body) values('A. Parent','parent@example.com','What are the school hours?');
-- BEFORE GOING LIVE, delete the demo users:
-- delete from auth.users where email like '%@sampleschool.test';
