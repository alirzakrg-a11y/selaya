// SELAYA — Bilgi Yarışması haftalık liderlik tablosu.
//
//   GET  /v1/quiz/leaderboard[?week=YYYY-Www]   -> {week, top:[...], me:{rank,score}}  (auth opsiyonel)
//   POST /v1/quiz/submit (Bearer) {score,correct,total} -> {ok, week, best}  (haftalık EN İYİ skoru tutar)
//
// Skor istemcide hesaplanır (doğru sayısı + hız bonusu); sunucu makul üst sınırla
// doğrular ve haftayı kendi saatinden atar (hafta-spoof engeli). Bir kullanıcı için
// hafta başına tek satır; yeni skor öncekinden yüksekse güncellenir.
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

// Haftalık anahtar = o haftanın PAZAR günü (UTC), YYYY-MM-DD. Hafta Pazar başlar →
// her PAZAR sıfırlanır (madde 3: haftalık hak + sorular + liderlik). Uygulama
// (Dart quizWeekKey) ile birebir aynı algoritma olmalı.
function weekKey(ms) {
  const dt = new Date(ms);
  const dow = dt.getUTCDay(); // 0=Pazar..6=Cumartesi
  const sun = new Date(
    Date.UTC(dt.getUTCFullYear(), dt.getUTCMonth(), dt.getUTCDate() - dow));
  const y = sun.getUTCFullYear();
  const m = String(sun.getUTCMonth() + 1).padStart(2, '0');
  const d = String(sun.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

let _schemaOk = false;
async function ensureSchema(env) {
  if (_schemaOk) return;
  await env.DB.batch([
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS quiz_scores (user_id TEXT NOT NULL, week TEXT NOT NULL, " +
      "rumuz TEXT, score INTEGER NOT NULL DEFAULT 0, correct INTEGER, total INTEGER, " +
      "attempts INTEGER NOT NULL DEFAULT 0, updated_at INTEGER, PRIMARY KEY (user_id, week))"
    ),
    env.DB.prepare("CREATE INDEX IF NOT EXISTS idx_quiz_week ON quiz_scores(week, score)"),
  ]);
  // Mevcut tabloya attempts sütunu (madde 3 haftalık hak sayacı) — yoksa ekle.
  try {
    await env.DB
      .prepare("ALTER TABLE quiz_scores ADD COLUMN attempts INTEGER NOT NULL DEFAULT 0")
      .run();
  } catch (_) { /* sütun zaten var */ }
  _schemaOk = true;
}

export async function handleQuiz(request, env, path) {
  if (!path.startsWith('/v1/quiz')) return null;
  if (!env.AUTH_SECRET) return json({ ok: false, error: 'server_misconfig' }, 500);
  await ensureSchema(env);
  const week = weekKey(Date.now());

  let uid = null;
  const payload = await requireUser(request, env);
  if (payload === 'banned') return json({ ok: false, error: 'banned' }, 403);
  if (payload) uid = payload.sub;

  // ---- LİDERLİK TABLOSU (herkese açık) ----
  if (request.method === 'GET' && path === '/v1/quiz/leaderboard') {
    const url = new URL(request.url);
    const wk = url.searchParams.get('week') || week;
    // Anonim istek (me yok) hafta başına aynı → 60 sn edge cache. Girişli istekte
    // "me" (kişisel sıra) olduğundan cache ATLANIR.
    const cache = caches.default;
    const CK = 'https://api.selaya.app/__cache/quiz-lb?w=' + encodeURIComponent(wk);
    if (!uid) {
      const hit = await cache.match(CK);
      if (hit) return hit;
    }
    const { results } = await env.DB.prepare(
      "SELECT rumuz, score, correct, total FROM quiz_scores WHERE week=? AND score>0 " +
      "ORDER BY score DESC, updated_at ASC LIMIT 50"
    ).bind(wk).all();
    let me = null;
    if (uid) {
      const mine = await env.DB
        .prepare("SELECT score FROM quiz_scores WHERE user_id=? AND week=?")
        .bind(uid, wk).first();
      if (mine) {
        const above = await env.DB
          .prepare("SELECT COUNT(*) AS n FROM quiz_scores WHERE week=? AND score>?")
          .bind(wk, mine.score).first();
        me = { rank: ((above && above.n) || 0) + 1, score: mine.score };
      }
    }
    const resp = json({ ok: true, week: wk, top: results || [], me });
    if (!uid) {
      resp.headers.set('Cache-Control', 'public, max-age=60');
      await cache.put(CK, resp.clone());
    }
    return resp;
  }

  // ---- Bundan sonrası giriş ister ----
  if (!payload) return json({ ok: false, error: 'unauthorized' }, 401);

  const WEEKLY_LIMIT = 2; // madde 3: haftada 2 "Haftalık başla" hakkı (Pazar sıfırlanır)

  // ---- HAFTALIK HAK DURUMU (hak DÜŞMEZ — kartta "x/2" göstermek için) ----
  if (request.method === 'GET' && path === '/v1/quiz/status') {
    const row = await env.DB
      .prepare("SELECT attempts FROM quiz_scores WHERE user_id=? AND week=?")
      .bind(uid, week).first();
    const used = (row && row.attempts) || 0;
    return json({
      ok: true, week, used, limit: WEEKLY_LIMIT,
      remaining: Math.max(0, WEEKLY_LIMIT - used),
    });
  }

  // ---- HAFTALIK BAŞLAT (hak DÜŞ) — limit dolduysa reddet ----
  if (request.method === 'POST' && path === '/v1/quiz/start') {
    const row = await env.DB
      .prepare("SELECT attempts FROM quiz_scores WHERE user_id=? AND week=?")
      .bind(uid, week).first();
    const used = (row && row.attempts) || 0;
    if (used >= WEEKLY_LIMIT) {
      return json({
        ok: false, error: 'weekly_limit', used, limit: WEEKLY_LIMIT, remaining: 0,
      });
    }
    if (row) {
      await env.DB
        .prepare("UPDATE quiz_scores SET attempts=attempts+1 WHERE user_id=? AND week=?")
        .bind(uid, week).run();
    } else {
      const u = await env.DB.prepare('SELECT rumuz FROM users WHERE id=?').bind(uid).first();
      const rumuz = ((u && u.rumuz) || '').toString().trim();
      await env.DB.prepare(
        "INSERT INTO quiz_scores (user_id,week,rumuz,score,attempts,updated_at) " +
        "VALUES (?,?,?,0,1,?)"
      ).bind(uid, week, rumuz, Date.now()).run();
    }
    return json({
      ok: true, week, used: used + 1, limit: WEEKLY_LIMIT,
      remaining: WEEKLY_LIMIT - (used + 1),
    });
  }

  // ---- SKOR GÖNDER (haftalık en iyi) ----
  if (request.method === 'POST' && path === '/v1/quiz/submit') {
    const b = await readJson(request);
    if (!b) return json({ ok: false, error: 'bad_body' }, 400);
    const score = parseInt(b.score, 10);
    const correct = parseInt(b.correct, 10);
    const total = parseInt(b.total, 10);
    if (!(score >= 0) || score > 5000 || !(correct >= 0) || !(total > 0) ||
        total > 30 || correct > total) {
      return json({ ok: false, error: 'bad_input' }, 400);
    }
    const u = await env.DB.prepare('SELECT rumuz FROM users WHERE id=?').bind(uid).first();
    const rumuz = ((u && u.rumuz) || '').toString().trim();
    if (!rumuz) return json({ ok: false, error: 'rumuz_required' }, 400);
    const now = Date.now();
    const existing = await env.DB
      .prepare("SELECT score FROM quiz_scores WHERE user_id=? AND week=?")
      .bind(uid, week).first();
    if (existing) {
      if (score > (existing.score || 0)) {
        await env.DB.prepare(
          "UPDATE quiz_scores SET score=?, correct=?, total=?, rumuz=?, updated_at=? " +
          "WHERE user_id=? AND week=?"
        ).bind(score, correct, total, rumuz, now, uid, week).run();
      }
    } else {
      await env.DB.prepare(
        "INSERT INTO quiz_scores (user_id,week,rumuz,score,correct,total,updated_at) " +
        "VALUES (?,?,?,?,?,?,?)"
      ).bind(uid, week, rumuz, score, correct, total, now).run();
    }
    const best = Math.max(score, (existing && existing.score) || 0);
    return json({ ok: true, week, best });
  }

  return json({ ok: false, error: 'not_found' }, 404);
}
