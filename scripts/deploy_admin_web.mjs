/**
 * Upload PineSight Admin static files to Supabase Storage (public bucket).
 *
 * Requires:
 *   SUPABASE_URL
 *   SUPABASE_SERVICE_ROLE_KEY  (Dashboard → Settings → API → service_role)
 *
 * Usage:
 *   node scripts/deploy_admin_web.mjs
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..');
const adminDir = path.join(repoRoot, 'admin');
const bucket = 'pinesight-admin';

const supabaseUrl = (process.env.SUPABASE_URL ?? '').replace(/\/$/, '');
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY ?? '';

if (!supabaseUrl || !serviceKey) {
  console.error(
    'Missing env vars. Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY, then re-run.',
  );
  process.exit(1);
}

const files = [
  { name: 'index.html', type: 'text/html' },
  { name: 'app.js', type: 'application/javascript' },
  { name: 'styles.css', type: 'text/css' },
  { name: 'config.js', type: 'application/javascript' },
];

for (const file of files) {
  const filePath = path.join(adminDir, file.name);
  if (!fs.existsSync(filePath)) {
    console.error(`Missing ${filePath}`);
    if (file.name === 'config.js') {
      console.error('Copy admin/config.example.js to admin/config.js first.');
    }
    process.exit(1);
  }
}

async function upload(name, body, contentType) {
  const url = `${supabaseUrl}/storage/v1/object/${bucket}/${name}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${serviceKey}`,
      apikey: serviceKey,
      'Content-Type': contentType,
      'x-upsert': 'true',
    },
    body,
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Upload ${name} failed (${res.status}): ${text}`);
  }
}

console.log(`Deploying PineSight Admin to Supabase Storage bucket "${bucket}"...`);
for (const file of files) {
  const filePath = path.join(adminDir, file.name);
  const body = fs.readFileSync(filePath);
  await upload(file.name, body, file.type);
  console.log(`  uploaded ${file.name}`);
}

console.log('');
console.log('Storage upload complete.');
console.log('');
console.log(
  'Supabase cannot host HTML in a browser (responses are forced to text/plain).',
);
console.log(
  'For the live admin UI, deploy to Netlify:',
);
console.log('  npx netlify-cli login');
console.log('  .\\scripts\\deploy_admin_web.ps1 -Target netlify -Prod');
