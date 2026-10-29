// Hash router: #page or #portal/page.
async function render(){document.querySelectorAll('img.lg').forEach(i=>i.src=LOGO);document.getElementById('fav').href=LOGO;document.getElementById('nav').classList.remove('open');const y=scrollY,[r,sub]=(location.hash.slice(1)||'home').split('?')[0].split('/'),p=pages[r]||pages.home;
document.querySelectorAll('nav a.l').forEach(a=>a.classList.toggle('on',a.hash=='#'+r));
app.innerHTML='<div class="w" style="padding:60px 20px">Loading…</div>';
try{app.innerHTML=await p(sub);enhance();document.querySelectorAll('.gb').forEach(gbCalc);gbSortAll()}catch(e){app.innerHTML=`<div class="w" style="padding:40px 20px">${note('Could not load this page. Check your Supabase settings in index.html.','err')}</div>`}if(keep){scrollTo(0,y);keep=0}else window.scrollTo(0,0)}
