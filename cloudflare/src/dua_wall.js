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
import { requireUser, notifyAdmin } from './auth.js';
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

// Şikayet şemasını (reports kolonu + dedup tablosu) isolate başına BİR KEZ garanti
// et — her çağrıda ALTER denemek yerine.
let _reportSchemaOk = false;
async function ensureReportSchema(env) {
  if (_reportSchemaOk) return;
  try {
    await env.DB.prepare(
      'ALTER TABLE dua_wall ADD COLUMN reports INTEGER NOT NULL DEFAULT 0'
    ).run();
  } catch (_) {}
  try {
    await env.DB.prepare(
      'CREATE TABLE IF NOT EXISTS dua_reports (dua_id TEXT NOT NULL, user_id TEXT NOT NULL, ' +
      'created_at INTEGER, PRIMARY KEY(dua_id,user_id))'
    ).run();
  } catch (_) {}
  _reportSchemaOk = true;
}

// Dua Duvarı rotası ise Response, değilse null (index.js akışı devam etsin).
export async function handleDuaWall(request, env, path, ctx) {
  if (!path.startsWith('/v1/dua-wall')) return null;
  if (!env.AUTH_SECRET) return json({ ok: false, error: 'server_misconfig' }, 500);

  // ---- HERKESE AÇIK: onaylı duaları listele (giriş gerekmez) ----
  if (request.method === 'GET' && path === '/v1/dua-wall') {
    const url = new URL(request.url);
    const beforeParam = url.searchParams.get('before');
    // İlk sayfa (before yok) herkese aynı → 30 sn edge cache: auth'suz bot seli
    // her çağrıda D1'e inmesin (fatura/DoS koruması).
    const cache = caches.default;
    const CK = 'https://api.selaya.app/__cache/dua-wall';
    if (!beforeParam) {
      const hit = await cache.match(CK);
      if (hit) return hit;
    }
    const before = parseInt(beforeParam || '0', 10) || Date.now() + 1;
    const { results } = await env.DB.prepare(
      "SELECT id, rumuz, text, amins, created_at FROM dua_wall " +
      "WHERE status='approved' AND created_at < ? ORDER BY created_at DESC LIMIT ?"
    ).bind(before, PAGE).all();
    const resp = json({ ok: true, duas: results || [] });
    if (!beforeParam) {
      resp.headers.set('Cache-Control', 'public, max-age=30');
      await cache.put(CK, resp.clone());
    }
    return resp;
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
    // Benzersizlik: başkasının rumuzunu alıp kimliğine bürünmeyi engelle
    // (dua duvarı/hatim/quiz'de rumuz görünür). Panel ile aynı kural.
    const taken = await env.DB.prepare(
      'SELECT id FROM users WHERE rumuz=? COLLATE NOCASE AND id<>?'
    ).bind(v.value, uid).first();
    if (taken) return json({ ok: false, error: 'rumuz_taken' }, 409);
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
    await ensureReportSchema(env);
    // Kullanıcı başına 1 şikayet (dedup): bir kişi 3 kez şikayet ederek meşru
    // bir duayı TEK BAŞINA gizleyemesin (moderasyon-DoS koruması).
    await env.DB.prepare(
      'INSERT OR IGNORE INTO dua_reports (dua_id,user_id,created_at) VALUES (?,?,?)'
    ).bind(id, uid, Date.now()).run();
    const cnt = await env.DB.prepare(
      'SELECT COUNT(*) AS n FROM dua_reports WHERE dua_id=?'
    ).bind(id).first();
    const n = (cnt && cnt.n) || 0;
    await env.DB.prepare('UPDATE dua_wall SET reports=? WHERE id=?').bind(n, id).run();
    // 3+ FARKLI kullanıcı şikayet → otomatik gizle (panelde tekrar incelenir).
    if (n >= 3) {
      await env.DB.prepare(
        "UPDATE dua_wall SET status='hidden' WHERE id=? AND status='approved'"
      ).bind(id).run();
    }
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
    if (ctx) ctx.waitUntil(notifyAdmin(env, 'Yeni dua — onay bekliyor 🤲', [
      'Rumuz: ' + rumuz,
      'Dua: ' + text,
      'Onayla/reddet: panel.selaya.app → Dua Duvarı',
    ]));
    return json({ ok: true, status: 'pending', id });
  }

  return json({ ok: false, error: 'not_found' }, 404);
}
