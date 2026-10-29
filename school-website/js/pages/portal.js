// Portal shell: login screen, role menu, sidebar layout. Add or hide portal pages in the M list.
pages.portal=async function(sub){const{data:{session}}=await sb.auth.getSession();
if(!session)return loginView(sub);
me=(await sb.from('profiles').select('*').eq('id',session.user.id).single()).data||{full_name:session.user.email,role:'student',id:session.user.id};
const R=me.role,stu=R=='student',adm=R=='admin',post=['teacher','registrar','admin'].includes(R);
const M=[['dash','🏠 Dashboard'],['grades','📝 Grades',['student','teacher','admin']],['subjects','📚 Subjects',['admin']],['att','📅 Attendance',['student','teacher','admin']],['fees','💳 Fees',['student','bursar','admin']],['reg','📋 Term registration',['student']],['regs','🗂️ Registrations',['registrar','admin']],['news','📣 Announcements'],['apps','📥 Applications',['registrar','admin']],['msgs','✉️ Messages',['registrar','admin']],['events','🎉 Events',['admin']],['users','👥 Users and roles',['admin']]].filter(m=>!m[2]||m[2].includes(R));
const k=M.some(m=>m[0]==sub)?sub:'dash';
const tile=(v,l)=>`<div class="c"><div class="stat">${v}</div>${l}</div>`;
const studs=async()=>{const st=(await sb.from('profiles').select('id,full_name').eq('role','student').order('full_name')).data||[];return{n:st.length,sel:`<label>Student<select name="student_id" required>${st.map(x=>`<option value="${x.id}">${esc(x.full_name)}</option>`).join('')}</select></label>`,nm:Object.fromEntries(st.map(x=>[x.id,x.full_name]))}};
const own=q=>stu?q.eq('student_id',me.id):q;
const CAN={grades:['teacher','admin'],attendance:['teacher','admin'],fees:['bursar','admin'],announcements:['teacher','registrar','admin'],applications:['registrar','admin'],messages:['registrar','admin'],events:['admin'],profiles:['admin'],subjects:['admin'],assessments:['teacher','admin'],registrations:['student','registrar','admin']},ed=(t,f,d,x)=>CAN[t].includes(R)?{t,f,d,x}:0;
const G=async()=>{const[a,m]=await Promise.all([sb.from('assessments').select('*'),own(sb.from('marks').select('*'))]),AS=Object.fromEntries((a.data||[]).map(x=>[x.id,x]));if(stu){const MS=Object.fromEntries((m.data||[]).map(x=>[x.assessment_id,+x.score]));return(a.data||[]).map(x=>({assessment_id:x.id,subject:x.subject,term:x.term,score:100*(MS[x.id]??0)/x.total_marks}))}return(m.data||[]).filter(x=>AS[x.assessment_id]).map(x=>({...x,subject:AS[x.assessment_id].subject,term:AS[x.assessment_id].term,score:100*x.score/AS[x.assessment_id].total_marks}))};
const A=async()=>(await own(sb.from('attendance').select('*')).order('day',{ascending:false}).limit(60)).data||[];
const Fe=async()=>(await own(sb.from('fees').select('*')).order('created_at',{ascending:false}).limit(60)).data||[];
const avg=g=>g.length?(g.reduce((t,x)=>t+ +x.score,0)/g.length).toFixed(1):'–',pct=a=>a.length?Math.round(100*a.filter(x=>x.status!='absent').length/a.length)+'%':'–',due=f=>f.reduce((t,x)=>t+(x.amount-x.paid),0),sm=(f,k)=>f.reduce((t,x)=>t+ +x[k],0);
const all=async t=>(await sb.from(t).select('*').order('created_at',{ascending:false}).limit(50)).data||[];
const c={me,R,stu,adm,post,M,tile,studs,own,G,A,Fe,avg,pct,due,sm,all,ed};
const body=await portalViews[k](c),fl=flash;flash='';
return `<section class="s"><div class="w pt"><aside class="side" aria-label="Portal menu"><div class="who"><img src="${LOGO}" alt="" width="40" height="40"><br><b>${esc(me.full_name)}</b><br><span class="mu">${esc(R)}</span></div>${M.map(m=>`<a href="#portal/${m[0]}" class="${m[0]==k?'on':''}">${m[1]}</a>`).join('')}<button class="btn o" data-a="out" style="color:inherit">Sign out</button></aside><div class="pm"><div id="pout">${fl?note(fl):''}</div>${body}</div></div></section>`};
