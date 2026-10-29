// Public page: events
pages.events=async function(){const e=await sb.from('events').select('*').gte('event_date',new Date().toISOString().slice(0,10)).order('event_date');return `<section class="s"><div class="w"><h1>Events</h1>${tbl(['Date','Event','Where'],(e.data||[]).map(x=>tr([fmt(x.event_date),esc(x.title),esc(x.location)])))}</div></section>`};
