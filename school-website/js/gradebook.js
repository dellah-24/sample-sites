// Gradebook behaviour: auto-saving marks, average calculation, term/subject/method switches, subject ticks.
function gAvg(it,meth){if(!it.length)return NaN;return meth=='pooled'?100*it.reduce((s,x)=>s+x.score,0)/it.reduce((s,x)=>s+x.total_marks,0):it.reduce((s,x)=>s+100*x.score/x.total_marks,0)/it.length}
function gbCalc(t){const m=a=>a.length?a.reduce((x,y)=>x+y,0)/a.length:NaN,f=v=>isNaN(v)?'–':v.toFixed(1),tt=[...t.querySelectorAll('thead th[data-tt]')].map(h=>+h.dataset.tt),cols=tt.map(()=>[]),rv=[];
t.querySelectorAll('tbody tr').forEach(r=>{const ins=[...r.querySelectorAll('input.gi')],it=[];ins.forEach((i,k)=>{const v=i.value===''?0:+i.value;i.classList.toggle('bad',v>tt[k]);cols[k].push(v);it.push({score:v,total_marks:tt[k]})});
const a=gAvg(it,gmeth);r.querySelector('td.ac').textContent=f(a);if(!isNaN(a))rv.push(a)});
t.querySelectorAll('tfoot td.sm').forEach((c,i)=>c.textContent=f(m(cols[i])));t.querySelectorAll('tfoot td.sp').forEach((c,i)=>c.textContent=f(100*m(cols[i])/tt[i]));const o=t.querySelector('tfoot td.oa');if(o)o.textContent=f(m(rv))}
function gbSort(t){const b=t.tBodies[0],nm=r=>r.cells[1].textContent.trim().toLowerCase(),av=r=>{const v=parseFloat(r.cells[r.cells.length-1].textContent);return isNaN(v)?-1:v},c={az:(x,y)=>nm(x).localeCompare(nm(y)),za:(x,y)=>nm(y).localeCompare(nm(x)),hi:(x,y)=>av(y)-av(x)||nm(x).localeCompare(nm(y)),lo:(x,y)=>av(x)-av(y)||nm(x).localeCompare(nm(y))}[gsort];[...b.rows].sort(c).forEach(r=>b.appendChild(r))}
const gbSortAll=()=>document.querySelectorAll('.gb table,.gs table').forEach(gbSort);
document.addEventListener('click',e=>{if(e.target.dataset.resort!==undefined)gbSortAll();const t=e.target.closest('[data-gtab]');if(t){gtab=t.dataset.gtab;keep=1;render()}});
document.addEventListener('change',async e=>{const x=e.target,msg=h=>{const o=document.getElementById('gmsg');if(o)o.innerHTML=h};
if(x.id=='gterm'){gterm=x.value;keep=1;render();return}
if(x.id=='gsub'){gsub=x.value;keep=1;render();return}
if(x.id=='gmeth'){gmeth=x.value;keep=1;render();return}
if(x.id=='gsort'){gsort=x.value;gbSortAll();return}
if(x.id=='gavg'){gavg=x.checked?1:0;document.querySelectorAll('.gb').forEach(t=>t.classList.toggle('hide-avg',!x.checked));return}
if(x.dataset.ts){const tid=x.dataset.t||me.id,sid=+x.dataset.ts,r=x.checked?await sb.from('teacher_subjects').insert({teacher_id:tid,subject_id:sid}):await sb.from('teacher_subjects').delete().eq('teacher_id',tid).eq('subject_id',sid);
if(r.error){msg(note(r.error.message,'err'));x.checked=!x.checked;return}keep=1;render();return}
if(!x.classList.contains('gi'))return;
const v=x.value.trim(),tot=+x.dataset.tt;
if(v!==''&&!(+v>=0&&+v<=tot)){x.classList.add('bad');msg(note('Marks must be between 0 and '+tot+'.','err'));return}
x.classList.remove('bad');const q=sb.from('marks'),a=x.dataset.a,s=x.dataset.st;
const r=v===''?await q.delete().eq('assessment_id',a).eq('student_id',s):await q.upsert({assessment_id:+a,student_id:s,score:+v},{onConflict:'assessment_id,student_id'});
if(r.error){x.classList.add('bad');msg(note(r.error.message,'err'));return}
msg('');x.classList.add('sv');setTimeout(()=>x.classList.remove('sv'),900);gbCalc(x.closest('table'))});
