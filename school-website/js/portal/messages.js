// Portal page: messages (key "msgs"). Receives the portal context c.
portalViews.msgs=async function(c){const{me,R,stu,adm,post,M,tile,studs,own,G,A,Fe,avg,pct,due,sm,all,ed}=c;const d=await all('messages');return `<h1>Messages</h1>${tbl(['Date','From','Message'],d.map(x=>tr([fmt(x.created_at),esc(x.name)+' ('+esc(x.email)+')',esc(x.body)])),0,ed('messages',[null,null,null],d))}`};
