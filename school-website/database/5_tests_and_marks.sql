-- Run after the other SQL files. Tests (with total marks) and marks per student, replacing the old single-score grades.
create table if not exists assessments(id bigint generated always as identity primary key,subject text not null,term text not null,name text not null,total_marks numeric not null check(total_marks>0),test_date date,created_by uuid default auth.uid(),created_at timestamptz default now(),unique(subject,term,name));
create table if not exists marks(id bigint generated always as identity primary key,assessment_id bigint not null references assessments on delete cascade,student_id uuid not null references profiles on delete cascade,score numeric not null check(score>=0),unique(assessment_id,student_id));
alter table assessments enable row level security;alter table marks enable row level security;
create or replace function can_mark(aid bigint) returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from assessments a where a.id=aid and can_grade(a.subject))$$;
drop policy if exists as_sel on assessments;create policy as_sel on assessments for select using(auth.uid() is not null);
drop policy if exists as_ins on assessments;create policy as_ins on assessments for insert with check(can_grade(subject));
drop policy if exists as_upd on assessments;create policy as_upd on assessments for update using(can_grade(subject)) with check(can_grade(subject));
drop policy if exists as_del on assessments;create policy as_del on assessments for delete using(can_grade(subject));
drop policy if exists mk_sel on marks;create policy mk_sel on marks for select using(student_id=auth.uid() or app_role() in('teacher','admin'));
drop policy if exists mk_ins on marks;create policy mk_ins on marks for insert with check(can_mark(assessment_id));
drop policy if exists mk_upd on marks;create policy mk_upd on marks for update using(can_mark(assessment_id)) with check(can_mark(assessment_id));
drop policy if exists mk_del on marks;create policy mk_del on marks for delete using(can_mark(assessment_id));
-- A mark can never exceed the test total, and a total can never drop below a mark already entered
create or replace function check_mark() returns trigger language plpgsql as $$begin if new.score>(select total_marks from assessments where id=new.assessment_id) then raise exception 'Mark cannot be higher than the total marks'; end if; return new; end$$;
drop trigger if exists t_check_mark on marks;create trigger t_check_mark before insert or update on marks for each row execute function check_mark();
create or replace function check_total() returns trigger language plpgsql as $$begin if new.total_marks<coalesce((select max(score) from marks where assessment_id=new.id),0) then raise exception 'Total marks cannot be lower than a mark already entered'; end if; return new; end$$;
drop trigger if exists t_check_total on assessments;create trigger t_check_total before update of total_marks on assessments for each row execute function check_total();
-- Move old single-score grades across as "Test 1" out of 100
insert into assessments(subject,term,name,total_marks) select distinct subject,term,'Test 1',100 from grades on conflict do nothing;
insert into marks(assessment_id,student_id,score) select a.id,g.student_id,g.score from grades g join assessments a on a.subject=g.subject and a.term=g.term and a.name='Test 1' on conflict do nothing;
-- Demo: extra tests with different totals
insert into assessments(subject,term,name,total_marks) values('Mathematics','Term 1','Quiz 1',20),('Mathematics','Term 1','Mid-term',50),('Science','Term 1','Practical',30) on conflict do nothing;
insert into marks(assessment_id,student_id,score) select a.id,p.id,v.s from (values('Quiz 1','pupil@sampleschool.test',16),('Quiz 1','pupil2@sampleschool.test',14),('Mid-term','pupil@sampleschool.test',41),('Mid-term','pupil2@sampleschool.test',35),('Practical','pupil@sampleschool.test',24),('Practical','pupil2@sampleschool.test',21)) v(n,e,s) join assessments a on a.name=v.n and a.term='Term 1' join auth.users u on u.email=v.e join profiles p on p.id=u.id on conflict do nothing;
