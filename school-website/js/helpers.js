// Shared helpers: escaping, formatting, table rows, form fields, news list.
const app=document.getElementById('app');document.getElementById('yr').textContent=new Date().getFullYear();
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const fd=f=>Object.fromEntries(new FormData(f));
const note=(t,k='ok')=>`<div class="msg ${k}" role="status">${esc(t)}</div>`;
const fmt=d=>new Date(d).toLocaleDateString(undefined,{day:'numeric',month:'short',year:'numeric'});
const card=(t,b)=>`<div class="c"><h3>${t}</h3><p class="mu">${b}</p></div>`;
const tr=a=>`<tr>${a.map(x=>`<td>${x}</td>`).join('')}</tr>`;
const field=(l,n,t='text',req=1)=>`<label>${l}<input name="${n}" type="${t}" ${req?'required':''}></label>`;
const news=async(n=20)=>(await sb.from('announcements').select('*').eq('is_public',true).order('created_at',{ascending:false}).limit(n)).data||[];
const newsList=a=>a.length?a.map(x=>`<div class="c" style="margin-bottom:12px"><h3>${esc(x.title)}</h3><p class="mu">${fmt(x.created_at)}</p><p>${esc(x.body)}</p></div>`).join(''):'<p class="mu">No news yet.</p>';
let me=null,flash='',keep=0,gterm='Term 1',gavg=1,gsub='',gtab='enter',gmeth='mean',gsort='az';
