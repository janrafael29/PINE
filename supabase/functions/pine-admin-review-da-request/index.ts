// Deploy: supabase functions deploy pine-admin-review-da-request
// Full admin approves/rejects DA access requests; approve sets app_metadata.da = true.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Max-Age': '86400',
};

function isFullAdmin(user: { app_metadata?: Record<string, unknown> }): boolean {
  const a = user.app_metadata?.admin;
  return a === true || a === 'true';
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: cors });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const anon = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
    const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    if (!supabaseUrl || !anon || !service) {
      return new Response(JSON.stringify({ error: 'Server misconfigured' }), {
        status: 500,
        headers: { ...cors, 'Content-Type': 'application/json' },
      });
    }

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...cors, 'Content-Type': 'application/json' },
      });
    }

    const userClient = createClient(supabaseUrl, anon, {
      global: { headers: { Authorization: authHeader } },
    });
    const {
      data: { user },
      error: userErr,
    } = await userClient.auth.getUser();
    if (userErr || !user) {
      return new Response(JSON.stringify({ error: 'Invalid session' }), {
        status: 401,
        headers: { ...cors, 'Content-Type': 'application/json' },
      });
    }

    if (!isFullAdmin(user)) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403,
        headers: { ...cors, 'Content-Type': 'application/json' },
      });
    }

    const body = await req.json();
    const request_id = String(body.request_id ?? '').trim();
    const action = String(body.action ?? '').trim().toLowerCase();
    const review_note =
      body.review_note == null || String(body.review_note).trim() === ''
        ? null
        : String(body.review_note).trim();

    if (!request_id) {
      return new Response(JSON.stringify({ error: 'request_id required' }), {
        status: 400,
        headers: { ...cors, 'Content-Type': 'application/json' },
      });
    }
    if (action !== 'approve' && action !== 'reject') {
      return new Response(
        JSON.stringify({ error: 'action must be approve or reject' }),
        {
          status: 400,
          headers: { ...cors, 'Content-Type': 'application/json' },
        }
      );
    }

    const adminClient = createClient(supabaseUrl, service);

    const { data: row, error: rowErr } = await adminClient
      .from('da_access_requests')
      .select('id, user_id, status')
      .eq('id', request_id)
      .maybeSingle();

    if (rowErr) {
      return new Response(JSON.stringify({ error: rowErr.message }), {
        status: 500,
        headers: { ...cors, 'Content-Type': 'application/json' },
      });
    }
    if (!row) {
      return new Response(JSON.stringify({ error: 'Request not found' }), {
        status: 404,
        headers: { ...cors, 'Content-Type': 'application/json' },
      });
    }
    if (row.status !== 'pending') {
      return new Response(
        JSON.stringify({ error: 'Request is no longer pending' }),
        {
          status: 409,
          headers: { ...cors, 'Content-Type': 'application/json' },
        }
      );
    }

    const now = new Date().toISOString();
    const nextStatus = action === 'approve' ? 'approved' : 'rejected';

    if (action === 'approve') {
      const { data: targetData, error: targetErr } =
        await adminClient.auth.admin.getUserById(row.user_id);
      if (targetErr || !targetData?.user) {
        return new Response(
          JSON.stringify({ error: targetErr?.message ?? 'User not found' }),
          {
            status: 404,
            headers: { ...cors, 'Content-Type': 'application/json' },
          }
        );
      }

      const existingMeta = targetData.user.app_metadata ?? {};
      const { error: metaErr } = await adminClient.auth.admin.updateUserById(
        row.user_id,
        {
          app_metadata: {
            ...existingMeta,
            da: true,
          },
        }
      );
      if (metaErr) {
        return new Response(JSON.stringify({ error: metaErr.message }), {
          status: 400,
          headers: { ...cors, 'Content-Type': 'application/json' },
        });
      }
    }

    const { error: updErr } = await adminClient
      .from('da_access_requests')
      .update({
        status: nextStatus,
        reviewer_id: user.id,
        review_note,
        reviewed_at: now,
        updated_at: now,
      })
      .eq('id', request_id);

    if (updErr) {
      return new Response(JSON.stringify({ error: updErr.message }), {
        status: 500,
        headers: { ...cors, 'Content-Type': 'application/json' },
      });
    }

    return new Response(
      JSON.stringify({
        ok: true,
        status: nextStatus,
        user_id: row.user_id,
      }),
      {
        headers: { ...cors, 'Content-Type': 'application/json' },
      }
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...cors, 'Content-Type': 'application/json' },
    });
  }
});
