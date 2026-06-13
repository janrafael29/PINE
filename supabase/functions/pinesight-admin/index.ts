// Public static proxy for PineSight Admin.
// Supabase Storage serves HTML as text/plain; this function returns text/html.
// Assets are read from the pinesight-admin public bucket (upload via deploy_admin_web.mjs).

import 'jsr:@supabase/functions-js/edge-runtime.d.ts';

const BUCKET = 'pinesight-admin';

const MIME: Record<string, string> = {
  'index.html': 'text/html; charset=utf-8',
  'styles.css': 'text/css; charset=utf-8',
  'app.js': 'application/javascript; charset=utf-8',
  'config.js': 'application/javascript; charset=utf-8',
};

const ALLOWED = new Set(Object.keys(MIME));

Deno.serve(async (req) => {
  const supabaseUrl = (Deno.env.get('SUPABASE_URL') ?? '').replace(/\/$/, '');
  if (!supabaseUrl) {
    return new Response('Server misconfigured', { status: 500 });
  }

  const url = new URL(req.url);
  let subpath = url.pathname;
  for (const prefix of ['/functions/v1/pinesight-admin', '/pinesight-admin']) {
    if (subpath === prefix || subpath.startsWith(`${prefix}/`)) {
      subpath = subpath.slice(prefix.length);
      break;
    }
  }
  subpath = subpath.replace(/^\/+/, '') || 'index.html';

  if (!ALLOWED.has(subpath)) {
    return new Response('Not found', { status: 404 });
  }

  const storageUrl = `${supabaseUrl}/storage/v1/object/public/${BUCKET}/${subpath}`;
  const upstream = await fetch(storageUrl);
  if (!upstream.ok) {
    return new Response('Not found', { status: upstream.status });
  }

  const body = await upstream.arrayBuffer();
  return new Response(body, {
    status: 200,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Content-Type': MIME[subpath],
      'Cache-Control': 'public, max-age=60',
    },
  });
});
