const encoder = new TextEncoder();
const formats = { mp3: 'audio/mpeg', m4a: 'audio/mp4', aac: 'audio/aac', wav: 'audio/wav', flac: 'audio/flac', aif: 'audio/aiff', aiff: 'audio/aiff', caf: 'audio/x-caf' };
const extension = key => key.split('.').pop().toLowerCase();
const isAudio = key => typeof key === 'string' && Object.hasOwn(formats, extension(key));
const json = (body, status = 200) => Response.json(body, { status, headers: { 'Cache-Control': 'no-store' } });
async function hmac(secret, value) {
  const key = await crypto.subtle.importKey('raw', encoder.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const bytes = new Uint8Array(await crypto.subtle.sign('HMAC', key, encoder.encode(value)));
  return Array.from(bytes, b => b.toString(16).padStart(2, '0')).join('');
}
async function equal(a, b) {
  const digest = value => crypto.subtle.digest('SHA-256', encoder.encode(value));
  const [x, y] = await Promise.all([digest(a), digest(b)]);
  return new Uint8Array(x).reduce((result, value, i) => result | (value ^ new Uint8Array(y)[i]), 0) === 0;
}
export function parseRange(value, size) {
  if (!value) return null;
  const match = /^bytes=(\d*)-(\d*)$/.exec(value);
  if (!match || (!match[1] && !match[2]) || size === 0) throw new Error('range');
  let start, end;
  if (!match[1]) { const length = Number(match[2]); if (!Number.isSafeInteger(length) || length <= 0) throw new Error('range'); start = Math.max(0, size - length); end = size - 1; }
  else { start = Number(match[1]); end = match[2] ? Math.min(Number(match[2]), size - 1) : size - 1; }
  if (![start, end].every(Number.isSafeInteger) || start >= size || end < start) throw new Error('range');
  return { offset: start, length: end - start + 1 };
}
async function handle(request, env) {
  if (!env.MUSIC || !env.APP_TOKEN || !env.SIGNING_KEY) return json({ error: 'service_not_configured' }, 503);
  const url = new URL(request.url);
  if (url.protocol !== 'https:' && url.hostname !== 'localhost') return json({ error: 'https_required' }, 400);
  if (!['GET', 'HEAD'].includes(request.method)) return json({ error: 'method_not_allowed' }, 405);
  if (url.pathname === '/media') {
    const key = url.searchParams.get('key');
    const expires = url.searchParams.get('expires');
    const signature = url.searchParams.get('signature') || '';
    const now = Math.floor(Date.now() / 1000);
    if (!isAudio(key) || !/^\d+$/.test(expires || '') || Number(expires) <= now || Number(expires) > now + 21660) return json({ error: 'invalid_link' }, 403);
    if (!await equal(signature, await hmac(env.SIGNING_KEY, JSON.stringify([key, expires])))) return json({ error: 'invalid_link' }, 403);
    const metadata = await env.MUSIC.head(key);
    if (!metadata) return json({ error: 'not_found' }, 404);
    let range;
    try {
      // If-Range mismatch means return the whole representation.
      const ifRange = request.headers.get('If-Range');
      const rangeHeader = !ifRange || ifRange === metadata.httpEtag ? request.headers.get('Range') : null;
      range = parseRange(rangeHeader, metadata.size);
    } catch { return new Response(null, { status: 416, headers: { 'Content-Range': `bytes */${metadata.size}`, 'Cache-Control': 'no-store' } }); }
    const headers = new Headers({ 'Content-Type': formats[extension(key)], 'Accept-Ranges': 'bytes', 'ETag': metadata.httpEtag, 'Cache-Control': 'private, no-store', 'X-Content-Type-Options': 'nosniff' });
    headers.set('Content-Length', String(range ? range.length : metadata.size));
    if (range) headers.set('Content-Range', `bytes ${range.offset}-${range.offset + range.length - 1}/${metadata.size}`);
    if (request.method === 'HEAD') return new Response(null, { status: range ? 206 : 200, headers });
    const object = await env.MUSIC.get(key, { ...(range ? { range } : {}), onlyIf: { etagMatches: metadata.etag } });
    if (!object) return json({ error: 'not_found' }, 404);
    if (!('body' in object)) return json({ error: 'object_changed_retry' }, 412);
    return new Response(object.body, { status: range ? 206 : 200, headers });
  }
  if (request.method !== 'GET') return json({ error: 'method_not_allowed' }, 405);
  const auth = request.headers.get('Authorization') || '';
  const allowed = await Promise.all([env.APP_TOKEN, env.ANDROID_TOKEN].filter(Boolean).map(token => equal(auth, `Bearer ${token}`)));
  if (!allowed.some(Boolean)) return json({ error: 'unauthorized' }, 401);
  if (url.pathname === '/catalog') {
    const cursor = url.searchParams.get('cursor') || undefined;
    const page = await env.MUSIC.list({ limit: 500, cursor });
    return json({ objects: page.objects.filter(o => isAudio(o.key)).map(o => ({ key: o.key, version: o.etag })), cursor: page.truncated ? page.cursor : null });
  }
  if (url.pathname === '/play') {
    const key = url.searchParams.get('key');
    if (!isAudio(key)) return json({ error: 'invalid_audio_key' }, 400);
    if (!await env.MUSIC.head(key)) return json({ error: 'not_found' }, 404);
    const expires = String(Math.floor(Date.now() / 1000) + 21600);
    const media = new URL('/media', url.origin);
    media.searchParams.set('key', key); media.searchParams.set('expires', expires);
    media.searchParams.set('signature', await hmac(env.SIGNING_KEY, JSON.stringify([key, expires])));
    return json({ url: media.href });
  }
  return json({ error: 'not_found' }, 404);
}
export default { async fetch(request, env) {
  try { return await handle(request, env); }
  catch { return json({ error: 'service_unavailable' }, 503); }
}};
