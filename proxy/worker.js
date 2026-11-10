/**
 * Forkcast AI proxy - Cloudflare Worker.
 *
 * Keeps your provider API key on the server. The app calls
 *   POST https://<your-worker>.workers.dev/chat/completions
 * and this worker forwards to an OpenAI-compatible upstream with the secret key.
 *
 * Deploy:
 *   npm i -g wrangler
 *   wrangler init forkcast-proxy   (choose "Hello World" worker, replace src with this file)
 *   wrangler secret put OPENAI_API_KEY
 *   wrangler secret put APP_TOKEN          # optional shared token checked below
 *   wrangler deploy
 *
 * Then in the app's .env:
 *   USE_MOCK_AI=false
 *   AI_BASE_URL=https://forkcast-proxy.<you>.workers.dev
 *   AI_API_KEY=<APP_TOKEN value, or leave empty if you didn't set one>
 *
 * Production hardening ideas: per-user auth (Firebase/Supabase JWT), rate limiting
 * with Durable Objects or KV, request size caps, and logging/abuse monitoring.
 */

const UPSTREAM = 'https://api.openai.com/v1/chat/completions';
const ALLOWED_MODELS = new Set(['gpt-4o-mini', 'gpt-4o', 'gpt-4.1-mini']);
const MAX_BODY_BYTES = 6 * 1024 * 1024; // photos are sent as base64

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') return new Response(null, { headers: cors() });
    if (request.method !== 'POST' || url.pathname !== '/chat/completions') {
      return json({ error: 'Not found' }, 404);
    }

    // Optional shared token: the app sends it as "Authorization: Bearer <token>".
    if (env.APP_TOKEN) {
      const auth = request.headers.get('Authorization') || '';
      if (auth !== `Bearer ${env.APP_TOKEN}`) return json({ error: 'Unauthorized' }, 401);
    }

    const length = Number(request.headers.get('Content-Length') || 0);
    if (length > MAX_BODY_BYTES) return json({ error: 'Payload too large' }, 413);

    let body;
    try {
      body = await request.json();
    } catch {
      return json({ error: 'Invalid JSON' }, 400);
    }

    if (!ALLOWED_MODELS.has(body.model)) body.model = 'gpt-4o-mini';
    body.max_tokens = Math.min(body.max_tokens ?? 900, 900);
    delete body.stream;

    const upstream = await fetch(UPSTREAM, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${env.OPENAI_API_KEY}`,
      },
      body: JSON.stringify(body),
    });

    return new Response(upstream.body, {
      status: upstream.status,
      headers: { 'Content-Type': 'application/json', ...cors() },
    });
  },
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...cors() },
  });
}

function cors() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };
}
