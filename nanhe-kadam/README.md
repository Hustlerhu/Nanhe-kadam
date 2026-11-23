# Nanhe Kadam Public School

A single Hono Cloudflare Worker serves the website, portals and API. Cloudflare D1 stores all persistent data, including uploaded image bytes. There is no R2, external image host, third-party font or separate frontend service. An optional, admin-configured Google Maps iframe does contact Google and is empty by default. `/`, `/portal`, `/admin` and `/teacher` are routes of the same Worker. The public site works without an administrator signing in.

## IMPORTANT: destructive deployment

**`deploy.sh` permanently removes every non-system table and view in the configured D1 database and replaces the Worker. All existing students, enquiries, accounts, photos and other data in that database will be lost.** It first exports a SQL backup locally and requires you to type `RESET nanhe-kadam-db`. Review the backup and script, and stop if this database is shared. It excludes SQLite/Cloudflare internal tables and `d1_migrations`. The reset enumerates unknown legacy tables and views and tries to order drops by foreign-key dependency; exotic virtual tables, triggers, or legacy constraints may require manual intervention. If a command fails the script stops; inspect the database and backup before retrying. A reset and deployment across separate Cloudflare operations are **not** one transaction and may cause downtime. Never run this on production without a maintenance window and tested restore plan.

The API token supplied in the original request is deliberately **not** stored here. Treat it as compromised: revoke/rotate it in Cloudflare, then use a new token with the required account-scoped Workers Scripts edit, D1 edit, and Workers routes/account permissions. Do not commit it or paste it into a file. Cloudflare authentication, the configured account, D1 database and workers.dev hostname must already be valid and accessible. Free-tier usage is subject to Cloudflare's current limits; D1 base64 images consume database capacity and Worker requests/CPU are not unlimited.

## Deployment

Requirements: Node.js 20+, npm, curl, Bash and network access. The wrapper `install-and-deploy.sh` (provided next to the ZIP) can create the project files and run the same deploy script. Alternatively unzip the project and run:

```bash
cd nanhe-kadam
export CLOUDFLARE_API_TOKEN='YOUR_NEW_ROTATED_TOKEN'
./deploy.sh
```

The script installs locked dependencies, runs checks, exports the database, dynamically builds a destructive reset and migration, deploys the Worker, sets two random Worker secrets, and checks the requested URL for HTTP 200 and `/api/health`. The migration seeds **username `Rakesh@1` with the password requested by the user**, represented only by a salted PBKDF2 hash in SQL. Because that password is known and has been exposed, it is unsafe for a public deployment: anyone who knows it can sign in and change it before you do, even though the application forces a password change before other portal actions. **At the deployment prompt, enter a new private initial password instead of pressing Enter.** The script replaces the seed with a fresh salt and hash; the new password is never written to the migration SQL. Record it securely. The username is still `Rakesh@1` and the new password must be changed at the first portal login. Pressing Enter preserves the requested known credential for exact compatibility, but is unsuitable for production. Restrict access during deployment and review the result before exposing it to the public. `COOKIE_SECRET` and `CSRF_SECRET` are set as Worker secrets, never in `wrangler.toml`. Rotating either invalidates existing sessions or their CSRF tokens. No credentials are emailed.

The project is pinned to account `704b3a3e3931d2adb78faec76525e2fa`, Worker `nanhe-kadam`, D1 ID `40010739-626b-4441-87bd-ffcf2331c67a`, and the requested workers.dev URL. Configure the account's workers.dev subdomain or custom route separately if necessary. The script's HTTP check will fail if that URL is not mapped, if the deployment hasn't propagated, or if access is blocked. A successful HTTP 200 alone is not proof that all user journeys work.

## Local development

```bash
npm ci
cp .dev.vars.example .dev.vars
npx wrangler d1 execute nanhe-kadam-db --local --file migrations/0001_reset.sql
npm run dev
```

Open `http://localhost:8787`. The destructive local migration seeds username `Rakesh@1` and the requested initial password `rakesh@7632`. At first login you must immediately change it to a password of at least 12 characters before using the portal. These initial credentials and the example secrets are only safe for local development: use the script's private-password override for deployment. The included integration test expects a freshly reset local D1 and the example `.dev.vars`:

```bash
# With npm run dev already running and after resetting local D1:
node tests/integration.mjs
npm test
```

Integration tests mutate the local DB, create accounts and delete a teacher; do not point them at production. `npm run typecheck` validates TypeScript; `npx wrangler deploy --dry-run` checks bundling. For development, the frontend and bundled compressed illustrations are embedded into `backend/src/assets.ts` by `npm run assets`; no second deployment is needed. `npm run dev` and `npm run deploy` run that step automatically.

## Portal and content

* The super-admin can manage content, teachers, co-admins, salary, attendance, assignments and enquiries. Co-admins have the same content and teacher functions but cannot access co-admin management or alter/delete super-admins or co-admins; these checks are enforced in the API too.
* Teachers see their own profile, assignments and salary history. They can post or edit/delete their own notices and gallery entries only for currently assigned classes. Admins assign classes. The public page polls D1-backed content every five seconds while visible and refreshes the interface without a page reload, unless a form field or dialog is in use. Dynamic responses and media are `no-store`; updates are not pushed instantly. Polling consumes Worker/D1 requests, so review Cloudflare free-tier limits and adjust the interval for your traffic.
* Upload PNG, JPEG or WebP (at most 900 KB) to D1 using a portal upload control. Copy the resulting ID into the relevant logo, hero, class image, gallery or photo field and save. Remove a setting's image by clearing its ID. The settings panel provides permanent media deletion; deleting a media record also deletes gallery records that reference it. Teacher-owned uploads and the teacher's photo are deleted when that teacher is removed; if a photo is shared, all references to it can be affected. Avoid sharing teacher-owned files. Base64 overhead applies to D1 storage; use appropriately compressed images.
* The school starts with nine editable classes from Play Class through Class 5. Configure the optional Google Maps Embed URL (the iframe `src` from Google Maps, not the entire iframe) in School Identity & Address; only HTTPS Google Maps embed URLs are accepted. Enabling it loads content from Google and may disclose visitor data to Google; review your privacy notice and applicable consent requirements.
* The three fixed gallery sections are edited, not added or removed. Social icons are initially visible but unconfigured and show a configuration prompt; in **Socials**, set an HTTPS URL, handle, message and visibility. Never upload confidential documents: media URLs are public by design.
* Salary amounts are whole Indian rupees. The dashboard total is calculated from current salary rows, not cached. Deleting a teacher deletes the linked user, active sessions, salary, attendance, assignments and owned media in one D1 batch, with D1 foreign-key cascades. It may also remove gallery items that reference deleted media. Other notices authored by the deleted user remain with a null author.
* Dates and initial notices are illustrative reference-design examples, not verified school announcements. Update them before launch to avoid misleading families. Class tiles use bundled 3D-style artwork if no image is set. The bundled hero is an AI-generated illustration, not a photograph of the school. The supplied reference images informed the design, but exact pixel matching and 60–120 FPS performance have not been independently benchmarked.

## Rendering and animation

The Worker queries D1 for `/` and renders initial school identity, contact details, hero, class tiles and notices into HTML. The escaped JSON data block hydrates the interactive site without an initial public API request; dynamic content subsequently polls while visible. D1 and network latency still apply, so zero-millisecond loading cannot be guaranteed. Bunny and enquiry mascot motion uses transform/opacity and honours reduced-motion preferences. Browser checks covered first paint with JavaScript disabled and several viewport sizes; 60–120 FPS is not guaranteed or benchmarked across devices.

## Security and operational notes

Passwords use PBKDF2-SHA-256 with per-user random salts and 210,000 iterations. Sessions are random, stored in D1, HMAC-signed in HttpOnly/Secure/SameSite=Strict cookies, expire after eight hours and are revoked upon account deletion or admin password reset. Mutations require same-origin JSON and a CSRF token: public forms use a signed anonymous cookie, while signed-in mutations use a session-derived token. A D1-backed IP and username throttle limits sign-in attempts; an IP throttle limits enquiries, but it is not a substitute for Cloudflare WAF/bot controls, abuse monitoring, MFA, audit logs, or a formal security review. No MFA, password recovery, automated backups, anti-spam CAPTCHA or email notifications are implemented. Treat D1 data and backups as sensitive; configure access and retention policies. Staff can see all enquiries and salary records. Verify child-data handling, privacy notices, parental consent and applicable laws before launch. Input and media limits are enforced by the Worker, but do not rely on this project as having undergone a production security audit or load test. Dashboard HTML shell and its minified client code are served only after session verification; the interactive dashboard is rendered client-side after authentication, not fully server-side rendered. An authenticated user can inspect or copy client code; no web application can guarantee zero source exposure to an authorized browser. The public bundle contains no dashboard code. Server-side RBAC is the security boundary.

## Layout

* `backend/src/index.ts` — Hono Worker, RBAC, sessions, CSRF and API
* `frontend/` — accessible responsive HTML/CSS/JS, bundled at build time
* `public/hero.jpg` — bundled illustration
* `migrations/0001_reset.sql` — known schema and example content; destructive
* `scripts/build-reset.mjs` — generates the full inventory-based clean reset
* `deploy.sh` — backup, reset, secrets, deploy, secrets and HTTP verification
* `tests/` — project checks and a local integration exercise
