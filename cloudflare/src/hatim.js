// SELAYA — Topluluk Hatmi. Üyeler cüz alır, okur, "okudum" der; 30 cüz
// tamamlanınca hatim biter, yenisi otomatik açılır. İsteğe bağlı niyetli
// (merhum/şifa vb.) hatimler de açılabilir.
//
//   GET  /v1/hatim                 -> {campaigns:[...], completed:[...]}  (herkese açık)
//   POST /v1/hatim/create (Bearer) {title, intention}  -> {campaign}
//   POST /v1/hatim/claim  (Bearer) {campaign, juz}     -> {campaign}
//   POST /v1/hatim/release(Bearer) {campaign, juz}     -> {campaign}
//   POST /v1/hatim/done   (Bearer) {campaign, juz}     -> {campaign, completed}
import { requireUser } from './auth.js';

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
}
async function readJson(request) {
  try { return await request.json(); } catch (_) { return null; }
}

const JUZ = 30;

// Şemayı tembel kur (wrangler migration'a bağımlı olmadan; IF NOT EXISTS).
let _schemaOk = false;
async function ensureSchema(env) {
  if (_schemaOk) return;
  await env.DB.batch([
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS hatim_campaigns (id TEXT PRIMARY KEY, title TEXT NOT NULL, " +
      "intention TEXT, status TEXT NOT NULL DEFAULT 'active', created_by TEXT, created_rumuz TEXT, " +
      "created_at INTEGER NOT NULL DEFAULT 0, completed_at INTEGER)"
    ),
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS hatim_juz (campaign_id TEXT NOT NULL, juz_no INTEGER NOT NULL, " +
      "user_id TEXT, rumuz TEXT, status TEXT NOT NULL DEFAULT 'open', claimed_at INTEGER, done_at INTEGER, " +
      "PRIMARY KEY (campaign_id, juz_no))"
    ),
    env.DB.prepare(
      "CREATE INDEX IF NOT EXISTS idx_hatim_status ON hatim_campaigns(status, created_at)"
    ),
    env.DB.prepare(
      "CREATE INDEX IF NOT EXISTS idx_hatim_juz_user ON hatim_juz(user_id)"
    ),
  ]);
  _schemaOk = true;
}

async function seedJuz(env, campaignId) {
  const stmts = [];
  for (let j = 1; j <= JUZ; j++) {
    stmts.push(env.DB.prepare(
      "INSERT OR IGNORE INTO hatim_juz (campaign_id, juz_no, status) VALUES (?,?, 'open')"
    ).bind(campaignId, j));
  }
  await env.DB.batch(stmts);
}

// Aktif bir topluluk hatmi yoksa varsayılan birini aç (akış hiç boş kalmasın).
async function ensureDefault(env) {
  const active = await env.DB
    .prepare("SELECT id FROM hatim_campaigns WHERE status='active' LIMIT 1")
    .first();
  if (active) return;
  const id = 'htm-' + crypto.randomUUID();
  await env.DB.prepare(
    "INSERT INTO hatim_campaigns (id,title,intention,status,created_by,created_rumuz,created_at) " +
    "VALUES (?,?,?,'active','system','SELAYA',?)"
  ).bind(id, 'Topluluk Hatmi', 'Tüm müminlerin selâmeti için', Date.now()).run();
  await seedJuz(env, id);
}

async function detail(env, campaignId, uid) {
  const c = await env.DB.prepare(
    "SELECT id,title,intention,status,created_rumuz,created_at,completed_at " +
    "FROM hatim_campaigns WHERE id=?"
  ).bind(campaignId).first();
  if (!c) return null;
  const { results } = await env.DB.prepare(
    "SELECT juz_no,status,rumuz,user_id FROM hatim_juz WHERE campaign_id=? ORDER BY juz_no"
  ).bind(campaignId).all();
  const juz = (results || []).map((r) => ({
    juz_no: r.juz_no,
    status: r.status,
    rumuz: r.rumuz || null,
    mine: !!(uid && r.user_id === uid),
  }));
  return {
    id: c.id,
    title: c.title,
    intention: c.intention,
    created_rumuz: c.created_rumuz,
    created_at: c.created_at,
    completed_at: c.completed_at,
    status: c.status,
    done: juz.filter((j) => j.status === 'done').length,
    total: JUZ,
    juz,
  };
}

export async function handleHatim(request, env, path) {
  if (!path.startsWith('/v1/hatim')) return null;
  if (!env.AUTH_SECRET) return json({ ok: false, error: 'server_misconfig' }, 500);
  await ensureSchema(env);

  // İsteğe bağlı kimlik: giriş varsa cüzleri "mine" ile işaretle + yazma izni.
  let uid = null;
  const payload = await requireUser(request, env);
  if (payload === 'banned') return json({ ok: false, error: 'banned' }, 403);
  if (payload) uid = payload.sub;

  // ---- LİSTE (herkese açık) ----
  if (request.method === 'GET' && path === '/v1/hatim') {
    await ensureDefault(env);
    const { results } = await env.DB.prepare(
      "SELECT id FROM hatim_campaigns WHERE status='active' ORDER BY created_at DESC LIMIT 20"
    ).all();
    const campaigns = [];
    for (const r of results || []) {
      const d = await detail(env, r.id, uid);
      if (d) campaigns.push(d);
    }
    const recent = await env.DB.prepare(
      "SELECT id,title,intention,created_rumuz,completed_at FROM hatim_campaigns " +
      "WHERE status='completed' ORDER BY completed_at DESC LIMIT 10"
    ).all();
    return json({ ok: true, campaigns, completed: recent.results || [] });
  }

  // ---- Bundan sonrası giriş ister ----
  if (!payload) return json({ ok: false, error: 'unauthorized' }, 401);

  // ---- YENİ HATİM BAŞLAT ----
  if (request.method === 'POST' && path === '/v1/hatim/create') {
    const b = await readJson(request);
    if (!b) return json({ ok: false, error: 'bad_body' }, 400);
    const title = (b.title || '').toString().trim().slice(0, 80);
    const intention = (b.intention || '').toString().trim().slice(0, 120);
    if (title.length < 2) return json({ ok: false, error: 'title_required' }, 400);
    const mine = await env.DB.prepare(
      "SELECT COUNT(*) AS n FROM hatim_campaigns WHERE created_by=? AND status='active'"
    ).bind(uid).first();
    if (mine && (mine.n || 0) >= 5) return json({ ok: false, error: 'too_many' }, 429);
    const u = await env.DB.prepare('SELECT rumuz FROM users WHERE id=?').bind(uid).first();
    const rumuz = ((u && u.rumuz) || '').toString().trim() || 'Bir Kul';
    const id = 'htm-' + crypto.randomUUID();
    await env.DB.prepare(
      "INSERT INTO hatim_campaigns (id,title,intention,status,created_by,created_rumuz,created_at) " +
      "VALUES (?,?,?,'active',?,?,?)"
    ).bind(id, title, intention, uid, rumuz, Date.now()).run();
    await seedJuz(env, id);
    return json({ ok: true, campaign: await detail(env, id, uid) });
  }

  // ---- CÜZ AL / BIRAK / OKUDUM ----
  if (request.method === 'POST' &&
      (path === '/v1/hatim/claim' || path === '/v1/hatim/release' || path === '/v1/hatim/done')) {
    const b = await readJson(request);
    if (!b) return json({ ok: false, error: 'bad_body' }, 400);
    const cid = (b.campaign || '').toString();
    const juz = parseInt(b.juz, 10);
    if (!cid || !(juz >= 1 && juz <= JUZ)) return json({ ok: false, error: 'bad_input' }, 400);
    const c = await env.DB.prepare("SELECT status FROM hatim_campaigns WHERE id=?").bind(cid).first();
    if (!c) return json({ ok: false, error: 'not_found' }, 404);
    if (c.status !== 'active') return json({ ok: false, error: 'not_active' }, 400);
    const cell = await env.DB.prepare(
      "SELECT status,user_id FROM hatim_juz WHERE campaign_id=? AND juz_no=?"
    ).bind(cid, juz).first();
    if (!cell) return json({ ok: false, error: 'not_found' }, 404);
    const now = Date.now();

    if (path === '/v1/hatim/claim') {
      if (cell.status !== 'open') return json({ ok: false, error: 'taken' }, 409);
      const u = await env.DB.prepare('SELECT rumuz FROM users WHERE id=?').bind(uid).first();
      const rumuz = ((u && u.rumuz) || '').toString().trim();
      if (!rumuz) return json({ ok: false, error: 'rumuz_required' }, 400);
      await env.DB.prepare(
        "UPDATE hatim_juz SET status='claimed', user_id=?, rumuz=?, claimed_at=? WHERE campaign_id=? AND juz_no=?"
      ).bind(uid, rumuz, now, cid, juz).run();
      return json({ ok: true, campaign: await detail(env, cid, uid) });
    }
    if (path === '/v1/hatim/release') {
      if (cell.user_id !== uid || cell.status === 'done') {
        return json({ ok: false, error: 'not_yours' }, 403);
      }
      await env.DB.prepare(
        "UPDATE hatim_juz SET status='open', user_id=NULL, rumuz=NULL, claimed_at=NULL WHERE campaign_id=? AND juz_no=?"
      ).bind(cid, juz).run();
      return json({ ok: true, campaign: await detail(env, cid, uid) });
    }
    // done
    if (cell.user_id !== uid) return json({ ok: false, error: 'not_yours' }, 403);
    await env.DB.prepare(
      "UPDATE hatim_juz SET status='done', done_at=? WHERE campaign_id=? AND juz_no=?"
    ).bind(now, cid, juz).run();
    const left = await env.DB.prepare(
      "SELECT COUNT(*) AS n FROM hatim_juz WHERE campaign_id=? AND status!='done'"
    ).bind(cid).first();
    let completed = false;
    if (left && (left.n || 0) === 0) {
      await env.DB.prepare(
        "UPDATE hatim_campaigns SET status='completed', completed_at=? WHERE id=?"
      ).bind(now, cid).run();
      completed = true;
    }
    return json({ ok: true, completed, campaign: await detail(env, cid, uid) });
  }

  return json({ ok: false, error: 'not_found' }, 404);
}
