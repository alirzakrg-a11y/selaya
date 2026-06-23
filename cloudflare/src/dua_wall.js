// SELAYA — Dua Duvarı API (api.selaya.app). Üyeler dua/istek paylaşır; her
// gönderi panelde ONAYLANINCA yayınlanır. Çok katmanlı kötüye-kullanım koruması:
//   1) Yalnızca girişli üye (Bearer JWT) yazabilir
//   2) Rumuz zorunlu + küfür filtresinden geçer
//   3) Metin küfür filtresinden geçer (apaçık olanlar en başta reddedilir)
//   4) Hız limiti (60 sn'de 1) + kullanıcı başına en çok 5 bekleyen gönderi
//   5) Uzunluk tavanı (≤ 280) + panel onayı (insan moderasyonu) ASIL koruma
//
// Uçlar:
//   POST /v1/dua-wall          (Bearer) {text}      -> {ok, status:'pending'}
//   GET  /v1/dua-wall          [?before=ts]         -> {duas:[...]}  (onaylılar)
//   GET  /v1/dua-wall/mine     (Bearer)             -> {duas:[...]}  (kendi)
//   POST /v1/dua-wall/amin     (Bearer) {id}        -> {ok, amins}
//   POST /v1/dua-wall/rumuz    (Bearer) {rumuz}     -> {ok, rumuz}
import { requireUser } from './auth.js';
import { containsProfanity, validateRumuz } from './profanity.js';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Admin-Token',
};
function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', ...CORS },
  });
}
async function readJson(request) { try { return await request.json(); } catch (_) { return null; } }

const MAX_LEN = 280;
const MIN_LEN = 3;
const RATE_MS = 60 * 1000;       // 60 sn'de en fazla 1 gönderi
const MAX_PENDING = 5;            // kullanıcı başına en çok 5 bekleyen
const PAGE = 30;

// Dua Duvarı rotası ise Response, değilse null (index.js akışı devam etsin).
export async function handleDuaWall(request, env, path) {
  if (!path.startsWith('/v1/dua-wall')) return null;
  if (!env.AUTH_SECRET) return json({ ok: false, error: 'server_misconfig' }, 500);

  // ---- HERKESE AÇIK: onaylı duaları listele (giriş gerekmez) ----
  if (request.method === 'GET' && path === '/v1/dua-wall') {
    const url = new URL(request.url);
    const before = parseInt(url.searchParams.get('before') || '0', 10) || Date.now() + 1;
    const { results } = await env.DB.prepare(
      "SELECT id, rumuz, text, amins, created_at FROM dua_wall " +
      "WHERE status='approved' AND created_at < ? ORDER BY created_at DESC LIMIT ?"
    ).bind(before, PAGE).all();
    return json({ ok: true, duas: results || [] });
  }

  // ---- Bundan sonrası giriş ister ----
  const payload = await requireUser(request, env);
  if (payload === 'banned') return json({ ok: false, error: 'banned' }, 403);
  if (!payload) return json({ ok: false, error: 'unauthorized' }, 401);
  const uid = payload.sub;

  // ---- RUMUZ AYARLA ----
  if (request.method === 'POST' && path === '/v1/dua-wall/rumuz') {
    const b = await readJson(request);
    if (!b) return json({ ok: false, error: 'bad_body' }, 400);
    const v = validateRumuz(b.rumuz);
    if (!v.ok) return json({ ok: false, error: v.error }, 400);
    await env.DB.prepare('UPDATE users SET rumuz=? WHERE id=?').bind(v.value, uid).run();
    return json({ ok: true, rumuz: v.value });
  }

  // ---- KENDİ GÖNDERİLERİM (durumlarıyla) ----
  if (request.method === 'GET' && path === '/v1/dua-wall/mine') {
    const { results } = await env.DB.prepare(
      'SELECT id, rumuz, text, status, amins, created_at FROM dua_wall ' +
      'WHERE user_id=? ORDER BY created_at DESC LIMIT 50'
    ).bind(uid).all();
    return json({ ok: true, duas: results || [] });
  }

  // ---- ÂMİN (kullanıcı başına 1; dedup) ----
  if (request.method === 'POST' && path === '/v1/dua-wall/amin') {
    const b = await readJson(request);
    const id = (b && b.id || '').toString();
    if (!id) return json({ ok: false, error: 'id_required' }, 400);
    const dua = await env.DB.prepare(
      "SELECT id FROM dua_wall WHERE id=? AND status='approved'"
    ).bind(id).first();
    if (!dua) return json({ ok: false, error: 'not_found' }, 404);
    // Daha önce âmin dediyse tekrar sayma.
    const had = await env.DB.prepare(
      'SELECT 1 FROM dua_amins WHERE dua_id=? AND user_id=?'
    ).bind(id, uid).first();
    if (had) {
      const cur = await env.DB.prepare('SELECT amins FROM dua_wall WHERE id=?').bind(id).first();
      return json({ ok: true, amins: (cur && cur.amins) || 0, already: true });
    }
    await env.DB.prepare('INSERT INTO dua_amins (dua_id, user_id) VALUES (?,?)').bind(id, uid).run();
    await env.DB.prepare('UPDATE dua_wall SET amins = amins + 1 WHERE id=?').bind(id).run();
    const cur = await env.DB.prepare('SELECT amins FROM dua_wall WHERE id=?').bind(id).first();
    return json({ ok: true, amins: (cur && cur.amins) || 1 });
  }

  // ---- ŞİKAYET ET (UGC moderasyonu — Play zorunluluğu) ----
  if (request.method === 'POST' && path === '/v1/dua-wall/report') {
    const b = await readJson(request);
    const id = (b && b.id || '').toString();
    if (!id) return json({ ok: false, error: 'id_required' }, 400);
    // 'reports' kolonu yoksa ekle (tek seferlik, idempotent).
    try {
      await env.DB.prepare(
        'ALTER TABLE dua_wall ADD COLUMN reports INTEGER NOT NULL DEFAULT 0'
      ).run();
    } catch (_) {}
    await env.DB.prepare(
      'UPDATE dua_wall SET reports = COALESCE(reports,0) + 1 WHERE id=?'
    ).bind(id).run();
    // 3+ şikayet → otomatik gizle (yayından kalkar; panelde tekrar incelenir).
    await env.DB.prepare(
      "UPDATE dua_wall SET status='hidden' WHERE id=? AND COALESCE(reports,0) >= 3 AND status='approved'"
    ).bind(id).run();
    return json({ ok: true });
  }

  // ---- DUA GÖNDER (onaya düşer) ----
  if (request.method === 'POST' && path === '/v1/dua-wall') {
    const b = await readJson(request);
    if (!b) return json({ ok: false, error: 'bad_body' }, 400);
    const text = (b.text || '').toString().trim().replace(/\s+/g, ' ');
    if (text.length < MIN_LEN) return json({ ok: false, error: 'too_short' }, 400);
    if (text.length > MAX_LEN) return json({ ok: false, error: 'too_long' }, 400);

    // Rumuz zorunlu (gönderi anındaki rumuz snapshot'lanır).
    const u = await env.DB.prepare('SELECT rumuz FROM users WHERE id=?').bind(uid).first();
    const rumuz = (u && u.rumuz || '').toString().trim();
    if (!rumuz) return json({ ok: false, error: 'rumuz_required' }, 400);

    // Apaçık küfür → en başta reddet (DB'ye hiç girmesin; moderatör yorulmasın).
    if (containsProfanity(text)) return json({ ok: false, error: 'contains_profanity' }, 422);

    const now = Date.now();
    // Hız limiti: son gönderiden 60 sn geçmeden yenisi yok.
    const last = await env.DB.prepare(
      'SELECT created_at FROM dua_wall WHERE user_id=? ORDER BY created_at DESC LIMIT 1'
    ).bind(uid).first();
    if (last && now - last.created_at < RATE_MS) {
      return json({ ok: false, error: 'too_soon' }, 429);
    }
    // Bekleyen kuyruğu doldurma koruması.
    const pend = await env.DB.prepare(
      "SELECT COUNT(*) AS n FROM dua_wall WHERE user_id=? AND status='pending'"
    ).bind(uid).first();
    if (pend && pend.n >= MAX_PENDING) {
      return json({ ok: false, error: 'too_many_pending' }, 429);
    }

    const id = crypto.randomUUID();
    await env.DB.prepare(
      "INSERT INTO dua_wall (id,user_id,rumuz,text,status,amins,created_at,decided_at) " +
      "VALUES (?,?,?,?,'pending',0,?,0)"
    ).bind(id, uid, rumuz, text, now).run();
    return json({ ok: true, status: 'pending', id });
  }

  return json({ ok: false, error: 'not_found' }, 404);
}
