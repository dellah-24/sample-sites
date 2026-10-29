// Portal page: dashboard (key "dash"). Receives the portal context c.
portalViews.dash=async function(c){const{me,R,stu,adm,post,M,tile,studs,own,G,A,Fe,avg,pct,due,sm,all,ed}=c;let t='';
if(stu){const[g,a,f]=await Promise.all([G(),A(),Fe()]);t=tile(avg(g),'average mark (%)')+tile(pct(a),'attendance')+tile(due(f),'fees balance')}
else{t=tile((await studs()).n,'students');if(R=='teacher'||adm)t+=tile((await G()).length,'marks recorded');if(R=='registrar'||adm)t+=tile((await all('applications')).length,'applications')+tile((await all('messages')).length,'messages')+tile(((await sb.from('registrations').select('*').eq('status','pending')).data||[]).length,'pending registrations');if(R=='bursar'||adm)t+=tile(due(await Fe()),'fees outstanding')}
const a=(await sb.from('announcements').select('*').order('created_at',{ascending:false}).limit(3)).data||[];
return `<h1>Dashboard</h1><div class="g" style="margin-bottom:24px">${t}</div><h2>Latest announcements</h2>${newsList(a)}<h2 style="margin-top:24px">Go to</h2><div class="g">${M.slice(1).map(m=>`<a class="c" href="#portal/${m[0]}"><h3>${m[1]}</h3></a>`).join('')}</div>`};
