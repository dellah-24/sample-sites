# Bottle store stock system
One page per function, plus Supabase. No build step. Roles: **owner** and **bartender**.

## Structure
- `index.html` — the full app (header + sidebar nav, 14 pages). Open this for the complete experience.
- `pages/<page>.html` — one standalone HTML file per function, each loading the same shared JS. Useful for linking straight into a page, or for a tabbed layout. 14 function pages: Products & stock, Purchases, Stock take, Wastage & adjustments, Stock movements, Sales, Shift & cash-up, Expenses, Reports, Restock requests, Categories, Staff & roles, Audit log, Settings.
- `styles.css` — all styles (extracted from the original single file).
- `store.js` — all app logic (renderers, events, demo backend, Supabase client). `STANDALONE=true` + `bootStandalone('<page>')` runs a single page with its own header and sign-out.
- `schema.sql` — DB schema, RLS policies, RPC functions, starter data, demo users.

## Try it without a database
Open `index.html` as it is (or add `?preview` to the address). It runs on sample data in the browser. Demo logins: `owner@bottlestore.test` and `bartender@bottlestore.test`, password `Demo@12345` (or tap the demo buttons).

A standalone page works the same way: `pages/products.html?preview`.

## Go live (Cloudflare Pages + Supabase)
1. Supabase: create a project, open SQL Editor, run all of `schema.sql`. In Authentication enable Email (turn off "Confirm email" while testing).
2. Edit the top of the script in `index.html` (and each `pages/*.html`): set `SUPABASE_URL` and `SUPABASE_ANON_KEY` (Project Settings > API, anon key only).
3. Cloudflare: Workers & Pages > Create > Pages > Upload assets, upload this folder.
4. In Supabase > Authentication > URL Configuration add your Cloudflare address as the Site URL.
5. Make your own login the owner: sign up, then run the owner SQL at the bottom of `schema.sql`.
6. Before launch: delete the demo users (SQL at the bottom of `schema.sql`) and set `SHOW_DEMO=false`.

## What each role can do
- **Owner**: everything. Products (costs, prices, reorder levels, suppliers), purchases and receiving stock, stock takes, wastage, stock movement ledger, sales and voids, shifts, expenses, reports (profit, margin, by day/category/product/payment/staff, reorder list, valuation, slow stock), restock requests, categories, staff and roles, audit log, settings.
- **Bartender**: see stock without cost prices, request restock, record wastage, stock counts, own sales, open and close own shift with cash-up.

The database enforces this: bartenders cannot read cost prices or other people's sales, edit products, void sales or change roles.

## Store name, cards and phones
- The owner sets the store name under **Settings** (or taps the ✎ Rename button in the header). It appears in the header, on receipts, in the browser tab and on the sign-in page. Run the updated `schema.sql` so the sign-in page can read the name before login (it adds the `store_info` view).
- Products, categories and other tables show as cards (with a Cards / Table switch); every table turns into stacked cards on phones.
- On phones the menu is a bottom bar with a More sheet.