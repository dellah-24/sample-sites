-- Run after the other SQL files. Adds the subject list, teacher subject allocation and gradebook rules.
create table if not exists subjects(id bigint generated always as identity primary key,name text not null unique,created_at timestamptz default now());
create table if not exists teacher_subjects(teacher_id uuid references profiles on delete cascade,subject_id bigint references subjects on delete cascade,primary key(teacher_id,subject_id));
alter table subjects enable row level security;alter table teacher_subjects enable row level security;
drop policy if exists s_sel on subjects;create policy s_sel on subjects for select using(auth.uid() is not null);
drop policy if exists s_all on subjects;create policy s_all on subjects for all using(app_role()='admin') with check(app_role()='admin');
drop policy if exists ts_sel on teacher_subjects;create policy ts_sel on teacher_subjects for select using(teacher_id=auth.uid() or app_role() in('teacher','admin'));
drop policy if exists ts_ins on teacher_subjects;create policy ts_ins on teacher_subjects for insert with check(app_role()='admin' or (app_role()='teacher' and teacher_id=auth.uid()));
drop policy if exists ts_del on teacher_subjects;create policy ts_del on teacher_subjects for delete using(app_role()='admin' or teacher_id=auth.uid());
-- One mark per student, subject and term
delete from grades a using grades b where a.id<b.id and a.student_id=b.student_id and a.subject=b.subject and a.term=b.term;
alter table grades drop constraint if exists grades_student_subject_term;
alter table grades add constraint grades_student_subject_term unique(student_id,subject,term);
-- Teachers can only write marks for subjects they teach; admins for any subject
create or replace function can_grade(sub text) returns boolean language sql stable security definer set search_path=public as $$select app_role()='admin' or (app_role()='teacher' and exists(select 1 from teacher_subjects ts join subjects s on s.id=ts.subject_id where ts.teacher_id=auth.uid() and s.name=sub))$$;
drop policy if exists g_ins on grades;create policy g_ins on grades for insert with check(can_grade(subject));
drop policy if exists g_upd on grades;create policy g_upd on grades for update using(can_grade(subject)) with check(can_grade(subject));
drop policy if exists g_del on grades;create policy g_del on grades for delete using(can_grade(subject));
insert into subjects(name) values('Mathematics'),('English'),('Science'),('History'),('Geography'),('Computer Studies') on conflict do nothing;
-- Demo: the demo teacher teaches Mathematics and Science
insert into teacher_subjects(teacher_id,subject_id) select p.id,s.id from profiles p join auth.users a on a.id=p.id join subjects s on s.name in('Mathematics','Science') where a.email='teacher@sampleschool.test' on conflict do nothing;
