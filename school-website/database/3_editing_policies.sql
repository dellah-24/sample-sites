-- Run after schema.sql and demo_and_staff_roles.sql. Lets the right staff edit and delete records.
drop policy if exists g_upd on grades;create policy g_upd on grades for update using(app_role() in('teacher','admin'));
drop policy if exists g_del on grades;create policy g_del on grades for delete using(app_role() in('teacher','admin'));
drop policy if exists t_del on attendance;create policy t_del on attendance for delete using(app_role() in('teacher','admin'));
drop policy if exists f_del on fees;create policy f_del on fees for delete using(app_role() in('bursar','admin'));
drop policy if exists a_upd on announcements;create policy a_upd on announcements for update using(app_role() in('teacher','registrar','admin'));
drop policy if exists a_del on announcements;create policy a_del on announcements for delete using(app_role() in('teacher','registrar','admin'));
drop policy if exists ap_del on applications;create policy ap_del on applications for delete using(app_role() in('registrar','admin'));
drop policy if exists m_del on messages;create policy m_del on messages for delete using(app_role() in('registrar','admin'));
-- Already allowed by earlier files: attendance, fees, applications updates; events and user names/roles (admin).
