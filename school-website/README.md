# Sample School: website and portal (source code)
Plain HTML, CSS and JavaScript with no build step. Hosted on Cloudflare Pages, data in Supabase.

## Where to change things
| To change | Edit |
|---|---|
| Supabase keys | `js/config.js` |
| Colours, fonts, layout, table look | `css/style.css` |
| Top bar, footer, page frame | `index.html` |
| A public page (home, about, academics, admissions, news, events, staff, contact) | `js/pages/<name>.js` |
| Portal login screen, sidebar menu, which role sees what | `js/pages/portal.js` (the `M` list) |
| A portal page (dashboard, grades, attendance, fees, announcements, applications, messages, events, users) | `js/portal/<name>.js` |
| Table features (search, sort, CSV export, inline edit, delete) | `js/tables.js` |
| Forms (apply, contact, sign in, sign up, add records) | `js/forms.js` |
| Page routing | `js/router.js` |
| Preview mode sample data and demo accounts | `js/preview.js` |
| Shared helpers | `js/helpers.js` |
| Database tables and security rules | `database/*.sql` |

Script order in `index.html` matters: config, preview, helpers, tables, public pages, portal pages, portal shell, router, forms, app.

## Adding a page
- Public: create `js/pages/x.js` containing `pages.x=()=>`...`;`, add its script tag before `js/pages/portal.js`, and add a link in the top bar in `index.html`.
- Portal: create `js/portal/x.js` containing `portalViews.x=async function(c){...}`, add its script tag, and add `['x','Label',['roles']]` to the `M` list in `js/pages/portal.js`.

## Deploy
1. Supabase: run the files in `database/` in numeric order in the SQL Editor. Enable the Email provider (turn off "Confirm email" while testing).
2. Put your project URL and anon key in `js/config.js`.
3. Cloudflare: Workers & Pages > Create > Pages > Upload assets, upload this whole folder.
4. Supabase > Authentication > URL Configuration: add your Cloudflare domain as the Site URL.
5. Make yourself admin: sign up, then run the admin SQL at the bottom of `database/1_schema.sql`.

## Preview mode
With the keys left as `YOUR_...` (or `?preview` on the URL) the site runs on sample data in the browser with one-tap demo sign-in. Demo password for all accounts: `Demo@12345`. Accounts: admin, teacher, registrar, bursar, pupil, pupil2 (`@sampleschool.test`).

## Before launch
Delete the demo users (command at the bottom of `database/2_staff_roles_and_demo_users.sql`) and add your real keys.

## Editing tables
Double-click a cell to edit (Enter saves, Esc cancels). The bin icon deletes (click twice). Permissions are enforced by the database policies in `database/3_editing_policies.sql`.

## Sign-in pages and demo credentials
The portal has a sign-in page for every role: `#portal` (all roles), `#portal/student`, `#portal/teacher`, `#portal/registrar`, `#portal/bursar`, `#portal/admin`. Each page shows its demo account (email, password, Fill and Sign in buttons). Set `SHOW_DEMO=false` in `js/config.js` to hide them before launch.

## Logo
`assets/logo.svg` is the logo. Replace the file (or change `LOGO` in `js/config.js`) to use your own.

## Gradebook and subjects
Run `database/4_subjects_and_gradebook.sql` after the other SQL files. Admins add the school's subjects on the **Subjects** page and can allocate them to teachers (teachers can also tick the subjects they teach on the Grades page). Teachers then work on the **Grades** page: pick a subject and term, add each test with its **total marks** (for example Quiz 1 out of 20, Mid-term out of 50), and type every student's mark into the grid, one column per test (saved automatically). Average (%) is worked out from each test's total, either as the mean of test percentages or as total marks divided by total possible (you choose), and the Summary tab shows every subject's average per student. Admins see every subject; pupils see their tests and averages by term. The database only lets teachers write tests and marks for subjects they teach, and refuses a mark above the test total.

Run `database/5_tests_and_marks.sql` after the other SQL files (it replaces the old single-score grades; existing marks are kept as "Test 1" out of 100).

## Averages, ordering and term registration
- **Missing marks count as zero.** In the gradebook a blank box is worked out as 0 (shown as a faint 0), in the class averages, the Summary tab, the pupil's own view and the dashboard. Nothing is stored for a blank box, so you can still tell "not entered" from a real 0.
- **Ordering pupils.** On Grades, "Order pupils by" sorts by name (A to Z or Z to A) or by average (high to low or low to high). It applies on the Enter marks and Summary tabs; use Re-sort after typing marks to refresh the order.
- **Term registration.** Pupils register for a term on **Term registration** (term, academic year, class, optional note); it starts as pending. The registrar and admin use **Registrations** to see everything, register a student directly, approve all pending, or set a status of approved or rejected with a note. Run `database/6_term_registration.sql` after the other SQL files.
