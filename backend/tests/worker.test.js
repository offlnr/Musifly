import test from 'node:test';
import assert from 'node:assert/strict';
import worker, { parseRange } from '../src/worker.js';
const data = new TextEncoder().encode('0123456789');
const meta = { size: 10, etag: 'test', httpEtag: '"test"' };
const env = { APP_TOKEN: 'test-token', SIGNING_KEY: 'test-signing-secret', MUSIC: {
  async list() { return { objects: [{ key: 'álbum/uno.mp3' }, { key: 'cover.jpg' }], truncated: false }; },
  async head(key) { return key === 'álbum/uno.mp3' ? meta : null; },
  async get(key, options) { const r = options?.range; return { ...meta, body: r ? data.slice(r.offset, r.offset + r.length) : data }; }
}};
const request = (path, options = {}) => new Request('https://music.example' + path, options);
const authorized = path => request(path, { headers: { Authorization: 'Bearer test-token' } });
test('catalog requires authorization and filters non-audio objects', async () => {
  assert.equal((await worker.fetch(request('/catalog'), env)).status, 401);
  const result = await (await worker.fetch(authorized('/catalog'), env)).json();
  assert.deepEqual(result.objects, [{ key: 'álbum/uno.mp3' }]);
});
test('signed media supports ranges, HEAD and rejects tampering', async () => {
  const { url } = await (await worker.fetch(authorized('/play?key=' + encodeURIComponent('álbum/uno.mp3')), env)).json();
  const response = await worker.fetch(new Request(url, { headers: { Range: 'bytes=2-5' } }), env);
  assert.equal(response.status, 206); assert.equal(response.headers.get('Content-Range'), 'bytes 2-5/10');
  assert.equal(await response.text(), '2345');
  assert.equal((await worker.fetch(new Request(url, { method: 'HEAD' }), env)).headers.get('Content-Length'), '10');
  assert.equal((await worker.fetch(new Request(url + 'x'), env)).status, 403);
  assert.equal((await worker.fetch(new Request(url, { headers: { Range: 'bytes=99-' } }), env)).status, 416);
  const expired = new URL(url); expired.searchParams.set('expires', '1');
  assert.equal((await worker.fetch(new Request(expired), env)).status, 403);
});
test('range edge cases and unsupported writes', async () => {
  assert.deepEqual(parseRange('bytes=-3', 10), { offset: 7, length: 3 });
  assert.deepEqual(parseRange('bytes=8-99', 10), { offset: 8, length: 2 });
  assert.throws(() => parseRange('bytes=0-1,3-4', 10));
  assert.equal((await worker.fetch(request('/catalog', { method: 'DELETE' }), env)).status, 405);
});

test('additional Android key preserves iPhone access and rejects empty or invalid keys', async () => {
  const both = { ...env, ANDROID_TOKEN: 'android-test-token' };
  for (const token of ['test-token', 'android-test-token']) {
    const response = await worker.fetch(request('/catalog', { headers: { Authorization: `Bearer ${token}` } }), both);
    assert.equal(response.status, 200);
  }
  for (const token of ['', 'wrong-token']) {
    assert.equal((await worker.fetch(request('/catalog', { headers: { Authorization: `Bearer ${token}` } }), both)).status, 401);
  }
  assert.equal((await worker.fetch(request('/catalog', { headers: { Authorization: 'Bearer android-test-token' } }), env)).status, 401);
});
