// Registrar action: approve all pending registrations.
document.addEventListener('click',async e=>{if(e.target.dataset.approveall===undefined)return;const r=await sb.from('registrations').update({status:'approved'}).eq('status','pending').select();
if(r.error){document.getElementById('pout').innerHTML=note(r.error.message,'err');return}flash='Pending registrations approved.';keep=1;render()});
