# ProcureTrack (SWICO) – deployment guide

## 1. Supabase (10 min)
1. supabase.com → New project (note the **Project URL** and **anon public key**: Settings → API).
2. SQL Editor → paste all of `supabase_schema.sql` → Run.
3. Authentication → Providers → Email: turn **off** "Allow new users to sign up" (invite-only).
4. Authentication → Users → **Add user** for each person (email + password), then run the matching
   `insert into public.profiles ...` line from the bottom of the SQL file (change name/email).
   Start with one `sysadmin`.
5. Authentication → URL Configuration → set **Site URL** to your GitHub Pages address (step 2).

## 2. GitHub
1. New **private** repository → upload `index.html` (and these two files if you like).
2. Open `index.html`, replace `YOUR-PROJECT-ID` and `YOUR-ANON-PUBLIC-KEY` near the top of the script with your values
   (the anon key is safe to publish – the database rules protect the data).
3. Settings → Pages → Source: *Deploy from a branch* → `main` / root. Your address appears there.
   (Private-repo Pages needs a paid GitHub plan; otherwise use a public repo or Netlify/Vercel – the app is one file.
   The page itself is public, but nothing is visible without signing in.)

## 3. Roles
| Role | Sees | Can change | Signs |
|---|---|---|---|
| procurement_officer | Procurement, suppliers, reports, delivery status (GRN) | Procurement & suppliers | as "Procurement Officer" |
| stock_manager | Stock, issue book, GRN, assets, request list (to link GRNs) | Stock side only | – |
| committee | Everything (read-only) + reports | Nothing | as their title (set in `sign_as`) |
| executive (CEO) | Everything (read-only) + reports | Nothing | as "CEO" |
| sysadmin | Everything (read-only) | Settings (petty cash limit & approvers) | – |

Signatures are drawn on screen, saved with name + date, and cannot be edited or deleted by anyone.
