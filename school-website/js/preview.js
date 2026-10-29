// Preview mode: sample data and demo accounts that work without Supabase.
const DEMO=[['admin','Ada Admin','admin','Admin'],['teacher','Tom Teacher','teacher','Teacher'],['registrar','Rita Registrar','registrar','Registrar'],['bursar','Ben Bursar','bursar','Bursar'],['pupil','Peter Pupil','student','Pupil'],['pupil2','Grace Pupil','student','Pupil 2']],DEMO_PW='Demo@12345';
const PREVIEW=SUPABASE_URL.startsWith('YOUR_')||new URLSearchParams(location.search).has('preview');
function mockSb(){const iso=n=>new Date(Date.now()-n*864e5).toISOString(),day=n=>iso(n).slice(0,10);
const sub=[['Mathematics',82],['English',74],['Science',91],['History',68]];
const D={profiles:DEMO.map(d=>({id:d[0],full_name:d[1],role:d[2]})),
announcements:[{id:1,title:'Welcome to Sample School',body:'Applications for the new term are now open.',is_public:true,created_at:iso(1)},{id:2,title:'Term 2 begins Monday',body:'Pupils should collect timetables from the office.',is_public:true,created_at:iso(3)},{id:3,title:'Staff briefing Friday 8am',body:'Portal-only notice.',is_public:false,created_at:iso(0)}],
events:[{id:1,title:'Open Day',event_date:day(-21),location:'Main Campus'},{id:2,title:'Inter-House Sports',event_date:day(-45),location:'School Field'}],
grades:[],assessments:[['Mathematics','Test 1',100,.82],['Mathematics','Quiz 1',20,.8],['Mathematics','Mid-term',50,.82],['English','Test 1',100,.74],['Science','Test 1',100,.91],['Science','Practical',30,.8],['History','Test 1',100,.68]].map((x,i)=>({id:i+1,subject:x[0],term:'Term 1',name:x[1],total_marks:x[2],test_date:null,p:x[3],created_at:iso(9-i)})),marks:[],attendance:[],fees:[],registrations:[['pupil','Term 1','approved',40],['pupil','Term 2','pending',1],['pupil2','Term 1','approved',40]].map((x,i)=>({id:i+1,student_id:x[0],year:new Date().getFullYear(),term:x[1],class_name:'Grade 8',status:x[2],review_note:'',created_at:iso(x[3])})),subjects:['Mathematics','English','Science','History','Geography','Computer Studies'].map((n,i)=>({id:i+1,name:n})),teacher_subjects:[{id:1,teacher_id:'teacher',subject_id:1},{id:2,teacher_id:'teacher',subject_id:3}],
applications:[{id:1,student_name:'Mia Okoro',grade_level:'Grade 7',guardian_name:'J. Okoro',email:'jokoro@example.com',phone:'',created_at:iso(2)}],
messages:[{id:1,name:'A. Parent',email:'parent@example.com',body:'What are the school hours?',created_at:iso(1)}]};
['pupil','pupil2'].forEach((s,k)=>{D.assessments.forEach(a=>D.marks.push({id:s+a.id,assessment_id:a.id,student_id:s,score:Math.round(a.total_marks*(a.p-k*.06))}));[0,1,2,3,4,5,6].forEach(i=>D.attendance.push({id:s+'a'+i,student_id:s,day:day(i),status:i==2?'absent':i==4?'late':'present'}));D.fees.push({id:s,student_id:s,term:'Term 1',amount:1200,paid:k?700:1200,created_at:iso(5)})});
let n=100,session=null;
const q=t=>{const f=[],o={};let op='sel',pay;
const b={select(){return b},eq(c,v){f.push(r=>r[c]==v);return b},gte(c,v){f.push(r=>r[c]>=v);return b},in(c,v){f.push(r=>v.includes(r[c]));return b},order(c,x){o.c=c;o.d=x&&x.ascending===false?-1:1;return b},limit(l){o.l=l;return b},single(){o.s=1;return b},
insert(p){op='ins';pay=p;return b},delete(){op='del';return b},upsert(p,x){op='ups';pay=p;o.k=x.onConflict.split(',');return b},update(p){op='upd';pay=p;return b},
then(a,c){return Promise.resolve(run()).then(a,c)}};
function run(){const T=D[t],ok={data:null,error:null};
if(op=='ins'){T.push({id:++n,created_at:iso(0),...pay});return ok}
if(op=='ups'){const i=T.findIndex(r=>o.k.every(k=>r[k]==pay[k]));i<0?T.push({id:++n,...pay}):Object.assign(T[i],pay);return ok}
let r=T.filter(x=>f.every(g=>g(x)));
if(op=='del'){r.forEach(x=>T.splice(T.indexOf(x),1));return ok}
if(op=='upd'){r.forEach(x=>Object.assign(x,pay));return ok}
if(o.c)r=[...r].sort((x,y)=>(x[o.c]>y[o.c]?1:x[o.c]<y[o.c]?-1:0)*o.d);
if(o.l)r=r.slice(0,o.l);
return{data:o.s?r[0]||null:r,error:null}}
return b};
return{from:q,auth:{getSession:async()=>({data:{session}}),
signInWithPassword:async v=>{const d=DEMO.find(x=>x[0]+'@sampleschool.test'==v.email);if(!d||v.password!=DEMO_PW)return{error:{message:'Wrong email or password. Use the preview buttons.'}};session={user:{id:d[0],email:v.email}};return{data:{session},error:null}},
signUp:async()=>({error:{message:'Sign-up is switched off in preview mode.'}}),signOut:async()=>{session=null}}}}
const sb=PREVIEW?mockSb():supabase.createClient(SUPABASE_URL,SUPABASE_ANON_KEY);
if(PREVIEW){const p=document.getElementById('pv');p.className='pv';p.innerHTML='Preview mode: sample data, nothing is saved. '+(SUPABASE_URL.startsWith('YOUR_')?'Add your Supabase keys to go live.':'<a href="./">Exit preview</a>')}
