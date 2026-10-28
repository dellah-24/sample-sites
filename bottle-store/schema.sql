-- Bottle store stock system. Run this whole file in Supabase > SQL Editor.
create table profiles(id uuid primary key references auth.users on delete cascade,full_name text,role text not null default 'bartender' check(role in('owner','bartender')),active boolean not null default true,created_at timestamptz default now());
create table settings(id int primary key default 1 check(id=1),store_name text default 'Sample Bottle Store',currency text default '$',tax_rate numeric default 15,max_discount_pct numeric default 10,receipt_footer text default 'Thank you! Please drink responsibly.');
create table categories(id bigint generated always as identity primary key,name text not null unique,age_restricted boolean default false);
create table suppliers(id bigint generated always as identity primary key,name text not null,phone text,email text,notes text);
create table products(id bigint generated always as identity primary key,sku text not null unique,name text not null,category_id bigint references categories on delete set null,size text,cost numeric not null default 0,price numeric not null default 0,stock numeric not null default 0 check(stock>=0),reorder_level numeric default 6,pack_size int default 1,supplier_id bigint references suppliers on delete set null,active boolean default true,created_at timestamptz default now());
create table customers(id bigint generated always as identity primary key,name text not null,phone text,balance numeric not null default 0);
create table shifts(id bigint generated always as identity primary key,user_id uuid default auth.uid(),opened_at timestamptz default now(),opening_float numeric default 0,closed_at timestamptz,counted_cash numeric,expected_cash numeric,note text);
create table sales(id bigint generated always as identity primary key,user_id uuid default auth.uid(),shift_id bigint,customer_id bigint,subtotal numeric,discount numeric default 0,total numeric,tax numeric,payment text check(payment in('cash','card','mobile','tab')),status text default 'completed' check(status in('completed','void')),note text,created_at timestamptz default now());
create table sale_items(id bigint generated always as identity primary key,sale_id bigint references sales on delete cascade,product_id bigint references products on delete set null,name text,qty numeric,price numeric,cost numeric);
create table purchases(id bigint generated always as identity primary key,supplier_id bigint references suppliers on delete set null,invoice_no text,status text default 'ordered' check(status in('ordered','received')),total numeric default 0,created_by uuid default auth.uid(),created_at timestamptz default now(),received_at timestamptz);
create table purchase_items(id bigint generated always as identity primary key,purchase_id bigint references purchases on delete cascade,product_id bigint references products on delete set null,qty numeric not null,unit_cost numeric not null);
-- Cost lots: FIFO stock costing. Each received purchase becomes a lot; sales draw from the oldest lot first.
create table stock_lots(id bigint generated always as identity primary key,product_id bigint references products on delete cascade,qty_remaining numeric not null check(qty_remaining>=0),unit_cost numeric not null,received_at timestamptz default now(),purchase_id bigint references purchases on delete set null,supplier_id bigint references suppliers on delete set null,note text);
create index sl_prod on stock_lots(product_id,received_at);
alter table stock_lots enable row level security;
create policy sl_all on stock_lots for all using(my_role()='owner') with check(my_role()='owner');
alter table sale_items add column lot_id bigint references stock_lots on delete set null;
create table movements(id bigint generated always as identity primary key,product_id bigint references products on delete cascade,type text,qty numeric,note text,user_id uuid default auth.uid(),ref_id bigint,created_at timestamptz default now());
create table expenses(id bigint generated always as identity primary key,spent_on date default current_date,category text,amount numeric not null,note text,user_id uuid default auth.uid());
create table restock_requests(id bigint generated always as identity primary key,product_id bigint references products on delete cascade,qty numeric,note text,status text default 'open' check(status in('open','done','dismissed')),user_id uuid default auth.uid(),created_at timestamptz default now());
create table payments(id bigint generated always as identity primary key,customer_id bigint references customers on delete cascade,amount numeric,method text,user_id uuid default auth.uid(),created_at timestamptz default now());
create table audit_log(id bigint generated always as identity primary key,user_id uuid default auth.uid(),action text,detail text,created_at timestamptz default now());

create function my_role() returns text language sql stable security definer set search_path=public as $$select role from profiles where id=auth.uid() and active$$;
create function handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$begin insert into profiles(id,full_name) values(new.id,coalesce(new.raw_user_meta_data->>'full_name',new.email));return new;end$$;
create trigger on_signup after insert on auth.users for each row execute function handle_new_user();

-- Bartenders read products and sale items through views that hide cost prices
create view product_list as select id,sku,name,category_id,size,price,stock,reorder_level,pack_size,supplier_id,active from products where my_role() is not null;
create view sale_item_list as select i.id,i.sale_id,i.product_id,i.name,i.qty,i.price from sale_items i join sales s on s.id=i.sale_id where s.user_id=auth.uid() or my_role()='owner';
grant select on product_list,sale_item_list to authenticated;
-- The store name is shown on the sign-in page, so it is readable before login
create view store_info as select store_name,currency from settings;
grant select on store_info to anon,authenticated;

-- Atomic stock operations
create function create_sale(p_items jsonb,p_payment text,p_discount numeric,p_customer bigint,p_note text) returns bigint language plpgsql security definer set search_path=public as $$
declare sid bigint;it jsonb;p products%rowtype;sub numeric:=0;tr numeric;md numeric;sh bigint;q numeric;tot numeric;lot stock_lots%rowtype;lot_id bigint;lot_cost numeric;lot_qty numeric;need numeric;
begin
 if my_role() is null then raise exception 'Not allowed'; end if;
 select tax_rate,max_discount_pct into tr,md from settings where id=1;
 -- pass 1: validate stock and compute subtotal
 for it in select * from jsonb_array_elements(p_items) loop
  select * into p from products where id=(it->>'product_id')::bigint for update;q:=(it->>'qty')::numeric;
  if p.id is null or not p.active then raise exception 'Unknown product'; end if;
  if q<=0 or p.stock<q then raise exception 'Not enough stock for %',p.name; end if;
  sub:=sub+p.price*q;
 end loop;
 if p_discount<0 or p_discount>sub then raise exception 'Invalid discount'; end if;
 if my_role()<>'owner' and p_discount>sub*md/100 then raise exception 'Discount is above your limit'; end if;
 if p_payment='tab' and p_customer is null then raise exception 'Choose a customer for a tab'; end if;
 tot:=sub-p_discount;select id into sh from shifts where user_id=auth.uid() and closed_at is null order by id desc limit 1;
 insert into sales(user_id,shift_id,customer_id,subtotal,discount,total,tax,payment,note) values(auth.uid(),sh,p_customer,sub,p_discount,tot,round(tot*tr/(100+tr),2),p_payment,p_note) returning id into sid;
 -- pass 2: draw FIFO from cost lots, record sale items, reduce stock
 for it in select * from jsonb_array_elements(p_items) loop
  q:=(it->>'qty')::numeric;need:=q;
  while need>0 loop
   select * into lot from stock_lots where product_id=(it->>'product_id')::bigint and qty_remaining>0 order by received_at asc, id asc limit 1 for update;
   exit when lot.id is null;
   lot_qty:=least(lot.qty_remaining,need);
   lot_cost:=lot.unit_cost;
   insert into sale_items(sale_id,product_id,name,qty,price,cost,lot_id) values(sid,(it->>'product_id')::bigint,p.name,lot_qty,p.price,lot_cost,lot.id);
   update stock_lots set qty_remaining=qty_remaining-lot_qty where id=lot.id;
   need:=need-lot_qty;
  end loop;
  if need>0 then raise exception 'FIFO stock mismatch for % — recount failed',p.name; end if;
  update products set stock=stock-q where id=(it->>'product_id')::bigint;
  insert into movements(product_id,type,qty,note,ref_id) values((it->>'product_id')::bigint,'sale',-q,'Sale #'||sid,sid);
 end loop;
 if p_payment='tab' then update customers set balance=balance+tot where id=p_customer; end if;
 insert into audit_log(user_id,action,detail) values(auth.uid(),'Sale','Sale #'||sid||' · '||p_payment||' · total '||tot);
 return sid;
end$$;
create function void_sale(p_sale bigint) returns void language plpgsql security definer set search_path=public as $$
declare s sales%rowtype;i sale_items%rowtype;lot stock_lots%rowtype;
begin
 if my_role()<>'owner' then raise exception 'Only the owner can void sales'; end if;
 select * into s from sales where id=p_sale for update;
 if s.status='void' then raise exception 'Already void'; end if;
 for i in select * from sale_items where sale_id=p_sale order by lot_id loop
  if i.lot_id is not null then
   select * into lot from stock_lots where id=i.lot_id for update;
   update stock_lots set qty_remaining=lot.qty_remaining+i.qty where id=i.lot_id;
  else
   update products set stock=stock+i.qty where id=i.product_id;
  end if;
  insert into movements(product_id,type,qty,note,ref_id) values(i.product_id,'void',i.qty,'Void sale #'||p_sale,p_sale);
 end loop;
 if s.payment='tab' then update customers set balance=balance-s.total where id=s.customer_id; end if;
 update sales set status='void' where id=p_sale;
 insert into audit_log(user_id,action,detail) values(auth.uid(),'Sale voided','Void sale #'||p_sale||' · '||s.total);
end$$;
create function receive_purchase(p_purchase bigint) returns void language plpgsql security definer set search_path=public as $$
declare i purchase_items%rowtype;pid bigint;sup bigint;note text;
begin
 if my_role()<>'owner' then raise exception 'Only the owner can receive stock'; end if;
 if (select status from purchases where id=p_purchase)='received' then raise exception 'Already received'; end if;
 for i in select * from purchase_items where purchase_id=p_purchase loop
  update products set stock=stock+i.qty,cost=i.unit_cost where id=i.product_id;
  select supplier_id into sup from purchases where id=p_purchase;
  note:='Purchase #'||p_purchase;
  insert into stock_lots(product_id,qty_remaining,unit_cost,purchase_id,supplier_id,note) values(i.product_id,i.qty,i.unit_cost,p_purchase,sup,note);
  insert into movements(product_id,type,qty,note,ref_id) values(i.product_id,'purchase',i.qty,note,p_purchase);
 end loop;
 update purchases set status='received',received_at=now() where id=p_purchase;
 insert into audit_log(user_id,action,detail) values(auth.uid(),'Stock received','Purchase #'||p_purchase);
end$$;
create function adjust_stock(p_product bigint,p_delta numeric,p_type text,p_note text) returns void language plpgsql security definer set search_path=public as $$
declare lot stock_lots%rowtype;need numeric;lot_qty numeric;
begin
 if my_role() is null then raise exception 'Not allowed'; end if;
 update products set stock=stock+p_delta where id=p_product;
 if p_delta>0 then
  insert into stock_lots(product_id,qty_remaining,unit_cost,purchase_id,supplier_id,note) values(p_product,p_delta,(select cost from products where id=p_product),null,null,p_type||': '||coalesce(p_note,''));
 else
  need:=-p_delta;
  while need>0 loop
   select * into lot from stock_lots where product_id=p_product and qty_remaining>0 order by received_at asc, id asc limit 1 for update;
   exit when lot.id is null;
   lot_qty:=min(lot.qty_remaining,need);
   update stock_lots set qty_remaining=qty_remaining-lot_qty where id=lot.id;
   need:=need-lot_qty;
  end loop;
 end if;
 insert into movements(product_id,type,qty,note) values(p_product,'adjustment',p_delta,p_type||': '||coalesce(p_note,''));
 insert into audit_log(user_id,action,detail) values(auth.uid(),'Stock adjustment',p_type||': product #'||p_product||' · '||p_delta||coalesce(' · '||p_note,''));
end$$;
create function apply_counts(p_counts jsonb) returns int language plpgsql security definer set search_path=public as $$
declare c jsonb;cur numeric;n int:=0;pid bigint;counted numeric;wa numeric;tot numeric;lnum numeric;lot_count int;
begin
 if my_role() is null then raise exception 'Not allowed'; end if;
 for c in select * from jsonb_array_elements(p_counts) loop
  pid:=(c->>'product_id')::bigint;counted:=(c->>'counted')::numeric;
  select stock into cur from products where id=pid for update;
  if cur=counted then continue  else
   -- collapse existing lots into one at weighted-average cost, sized to the physical count
   select coalesce(sum(qty_remaining*unit_cost),0),coalesce(sum(qty_remaining),0) into wa,tot from stock_lots where product_id=pid;
   delete from stock_lots where product_id=pid;
   if counted>0 then
    insert into stock_lots(product_id,qty_remaining,unit_cost,purchase_id,supplier_id,note) values(pid,counted,case when tot>0 then wa/tot else (select cost from products where id=pid) end,null,null,'Stock take');
   end if;
   update products set stock=counted where id=pid;
   insert into movements(product_id,type,qty,note) values(pid,'count',counted-cur,'Stock take');n:=n+1;
  end if;
 end loop;
 insert into audit_log(user_id,action,detail) values(auth.uid(),'Stock take',n||' difference(s) recorded');
 return n;
end$$;
create function tab_payment(p_customer bigint,p_amount numeric,p_method text) returns void language plpgsql security definer set search_path=public as $$
begin
 if my_role() is null or p_amount<=0 then raise exception 'Not allowed'; end if;
 update customers set balance=balance-p_amount where id=p_customer;
 insert into payments(customer_id,amount,method) values(p_customer,p_amount,p_method);
 insert into audit_log(user_id,action,detail) values(auth.uid(),'Tab payment','Customer #'||p_customer||' · '||p_amount||' · '||p_method);
end$$;

-- Row level security: owner sees everything, bartenders only what they need
do $$declare t text;begin foreach t in array array['profiles','settings','categories','suppliers','products','customers','shifts','sales','sale_items','purchases','purchase_items','movements','expenses','restock_requests','payments','audit_log','stock_lots'] loop execute format('alter table %I enable row level security',t);end loop;end$$;
create policy pr_sel on profiles for select using(auth.uid() is not null);create policy pr_upd on profiles for update using(my_role()='owner');
create policy st_sel on settings for select using(auth.uid() is not null);create policy st_upd on settings for update using(my_role()='owner');
create policy ca_sel on categories for select using(auth.uid() is not null);create policy ca_all on categories for all using(my_role()='owner') with check(my_role()='owner');
create policy su_sel on suppliers for select using(auth.uid() is not null);create policy su_all on suppliers for all using(my_role()='owner') with check(my_role()='owner');
create policy po_all on products for all using(my_role()='owner') with check(my_role()='owner');
create policy cu_sel on customers for select using(my_role() is not null);create policy cu_ins on customers for insert with check(my_role() is not null);create policy cu_mod on customers for update using(my_role()='owner');create policy cu_del on customers for delete using(my_role()='owner');
create policy sh_sel on shifts for select using(user_id=auth.uid() or my_role()='owner');create policy sh_ins on shifts for insert with check(my_role() is not null and user_id=auth.uid());create policy sh_upd on shifts for update using(user_id=auth.uid() or my_role()='owner');
create policy sa_sel on sales for select using(user_id=auth.uid() or my_role()='owner');
create policy si_sel on sale_items for select using(my_role()='owner');
create policy pu_all on purchases for all using(my_role()='owner') with check(my_role()='owner');
create policy pi_all on purchase_items for all using(my_role()='owner') with check(my_role()='owner');
create policy mo_sel on movements for select using(user_id=auth.uid() or my_role()='owner');
create policy ex_all on expenses for all using(my_role()='owner') with check(my_role()='owner');
create policy rr_sel on restock_requests for select using(user_id=auth.uid() or my_role()='owner');create policy rr_ins on restock_requests for insert with check(my_role() is not null and user_id=auth.uid());create policy rr_upd on restock_requests for update using(my_role()='owner');
create policy pa_sel on payments for select using(my_role()='owner');
create policy au_ins on audit_log for insert with check(my_role() is not null);create policy au_sel on audit_log for select using(my_role()='owner');

-- Starter data
insert into settings(id) values(1);
insert into categories(name,age_restricted) values('Beer',true),('Wine',true),('Spirits',true),('Soft drinks',false),('Mixers',false),('Snacks',false);
insert into suppliers(name,phone) values('Delta Beverages','0771 000 001'),('Spirit House','0771 000 002'),('Fresh Distributors','0771 000 003');
insert into products(sku,name,category_id,size,cost,price,stock,reorder_level,pack_size,supplier_id) values
('B001','Castle Lager',1,'340ml',0.9,1.5,96,24,24,1),('B002','Black Label',1,'340ml',1,1.6,12,24,24,1),('B003','Heineken',1,'330ml',1.4,2.4,40,12,24,1),('B004','Savanna Dry',1,'330ml',1.5,2.5,0,12,24,1),
('W001','Four Cousins Red',2,'750ml',3.2,5.5,18,6,6,2),('W002','Robertson White',2,'750ml',4,6.5,5,6,6,2),('S001','Smirnoff Vodka',3,'750ml',8,13,14,4,12,2),('S002','Jack Daniel''s',3,'750ml',18,28,6,3,6,2),
('S003','Johnnie Walker Red',3,'750ml',16,25,3,3,6,2),('S004','Gordon''s Gin',3,'750ml',10,16,9,4,12,2),('D001','Coca-Cola',4,'500ml',0.4,0.9,120,48,24,3),('D002','Sprite',4,'500ml',0.4,0.9,60,48,24,3),
('D003','Mineral Water',4,'500ml',0.25,0.6,70,24,24,3),('M001','Tonic Water',5,'300ml',0.5,1.1,30,12,24,3),('M002','Ginger Ale',5,'300ml',0.5,1.1,8,12,24,3),('N001','Salted Peanuts',6,'100g',0.4,0.9,35,12,24,3),('N002','Potato Chips',6,'80g',0.5,1,22,12,24,3);
insert into customers(name,phone) values('Walk-in tab: Tendai M.',''),('Walk-in tab: Chipo N.','');

-- Demo accounts (password for both: Demo@12345). Delete before launch (see bottom).
do $$declare u record;uid uuid;begin
for u in select * from(values('owner@bottlestore.test','Olivia Owner','owner'),('bartender@bottlestore.test','Barry Bartender','bartender')) as t(email,full_name,role) loop
 if exists(select 1 from auth.users where email=u.email) then continue; end if;
 uid:=gen_random_uuid();
 insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,email_change,email_change_token_new,recovery_token)
 values('00000000-0000-0000-0000-000000000000',uid,'authenticated','authenticated',u.email,extensions.crypt('Demo@12345',extensions.gen_salt('bf')),now(),'{"provider":"email","providers":["email"]}',jsonb_build_object('full_name',u.full_name),now(),now(),'','','','');
 insert into auth.identities(id,user_id,provider_id,identity_data,provider,last_sign_in_at,created_at,updated_at) values(gen_random_uuid(),uid,uid::text,jsonb_build_object('sub',uid::text,'email',u.email),'email',now(),now(),now());
 update public.profiles set role=u.role where id=uid;
end loop;end$$;
-- Before going live: delete from auth.users where email like '%@bottlestore.test';
-- Make your own account the owner: update profiles set role='owner' where id=(select id from auth.users where email='YOU@EXAMPLE.COM');
