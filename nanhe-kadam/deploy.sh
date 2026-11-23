#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
: "${CLOUDFLARE_API_TOKEN:?Set CLOUDFLARE_API_TOKEN to a NEW, rotated token in your environment}"
command -v node >/dev/null; command -v npm >/dev/null; command -v curl >/dev/null
printf '\nWARNING: This will PERMANENTLY DELETE ALL non-system tables and views in nanhe-kadam-db, including users, enquiries, salaries and media.\n'
printf 'A backup will be exported first. The live Worker will be replaced. The initial admin password is PUBLICLY KNOWN and can be stolen before you change it.\nType RESET nanhe-kadam-db to continue: '
read -r confirmation
[[ "$confirmation" == 'RESET nanhe-kadam-db' ]] || { echo 'Cancelled.'; exit 1; }
printf 'Enter a new private initial admin password (12+ characters), or press Enter for the requested PUBLICLY KNOWN password: '
read -rs NANHE_INITIAL_PASSWORD; echo
if [[ -n "$NANHE_INITIAL_PASSWORD" && ${#NANHE_INITIAL_PASSWORD} -lt 12 ]]; then echo 'Password must be at least 12 characters.' >&2; exit 1; fi
if [[ ${#NANHE_INITIAL_PASSWORD} -gt 128 ]]; then echo 'Password is too long.' >&2; exit 1; fi
export NANHE_INITIAL_PASSWORD
umask 077
npm ci --no-audit --no-fund
npm run typecheck
npm test
backup="nanhe-kadam-backup-$(date -u +%Y%m%dT%H%M%SZ).sql"
echo "Exporting remote D1 backup to $backup"
npx wrangler d1 export nanhe-kadam-db --remote --output "$backup"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
npx wrangler d1 execute nanhe-kadam-db --remote --json --command "SELECT type,name FROM sqlite_schema WHERE type IN ('table','view') AND name NOT GLOB 'sqlite_*' AND name NOT GLOB '_cf_*' AND name <> 'd1_migrations'" > "$tmp/schema.json"
npx wrangler d1 execute nanhe-kadam-db --remote --json --command "SELECT m.name AS child, p.\"table\" AS parent FROM sqlite_schema m JOIN pragma_foreign_key_list(m.name) p WHERE m.type='table' AND m.name NOT GLOB 'sqlite_*' AND m.name NOT GLOB '_cf_*' AND m.name <> 'd1_migrations'" > "$tmp/fk.json"
node scripts/build-reset.mjs "$tmp/schema.json" "$tmp/fk.json" "$tmp/reset.sql"
# Optional safer credential override; only a salt and PBKDF2 hash are written to SQL.
if [[ -n "$NANHE_INITIAL_PASSWORD" ]]; then
  RESET_SQL="$tmp/reset.sql" node --input-type=module <<'NODE'
import {readFileSync,writeFileSync} from 'node:fs';import {randomBytes,pbkdf2Sync} from 'node:crypto';
const salt=randomBytes(16).toString('hex'),hash=pbkdf2Sync(process.env.NANHE_INITIAL_PASSWORD,salt,100000,32,'sha256').toString('hex');
const path=process.env.RESET_SQL;let sql=readFileSync(path,'utf8');const marker="'ee810a7498051e64997a5f1c510ebb1834271ab0b629a4665189ab2d855b3cd3','127f60c5b699c703dc594f43388cdb54'";
if(!sql.includes(marker))throw Error('Initial credential marker missing');sql=sql.replace(marker,`'${hash}','${salt}'`);writeFileSync(path,sql);
NODE
fi
unset NANHE_INITIAL_PASSWORD
echo 'Resetting remote D1 and applying the schema…'
npx wrangler d1 execute nanhe-kadam-db --remote --file "$tmp/reset.sql"
random() { node -e "process.stdout.write(require('node:crypto').randomBytes(32).toString('base64url'))"; }
cookie=$(random); csrf=$(random)
npm run deploy
printf %s "$cookie" | npx wrangler secret put COOKIE_SECRET
printf %s "$csrf" | npx wrangler secret put CSRF_SECRET
code=$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' 'https://nanhe-kadam.empathy-life-jelly.workers.dev')
[[ "$code" == 200 ]] || { echo "Verification failed: HTTP $code"; exit 1; }
curl --fail --silent --show-error 'https://nanhe-kadam.empathy-life-jelly.workers.dev/api/health'; echo
printf '\nHTTP 200 verified. Initial username: Rakesh@1. Use the password selected at the prompt and change it on first sign-in.\nBackup: %s/%s\n' "$PWD" "$backup"
