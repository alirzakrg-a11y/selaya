// SELAYA içerik API'si + yönetim paneli — tek Worker.
// Host'a göre yönlenir:
//   api.selaya.app   -> herkese açık: GET /v1/manifest, GET /v1/notifications, /health
//   panel.selaya.app -> yönetim paneli UI + korumalı yazma API'si (X-Admin-Token)
// Bağlamalar: DB (D1: selaya-content), CDN (R2: selaya-cdn), CDN_BASE (var),
//             ADMIN_TOKEN (secret), AUTH_SECRET (secret — JWT imzası)

import { handleAuth, hashPassword, timingSafeEqual } from './auth.js';
import { handleDuaWall } from './dua_wall.js';
import { handleHatim } from './hatim.js';
import { handleQuiz } from './quiz.js';
import { handlePrivacy } from './privacy.js';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Admin-Token',
};

function json(obj, { status = 200, maxage = 0 } = {}) {
  const h = { 'Content-Type': 'application/json; charset=utf-8', ...CORS };
  if (maxage) h['Cache-Control'] = 'public, max-age=' + maxage;
  return new Response(JSON.stringify(obj), { status, headers: h });
}

function safeParse(s) { try { return JSON.parse(s); } catch (e) { return null; } }

// Edge önbellek anahtarları (public GET'ler). D1'e her uygulama açılışında
// gitmemek için yanıtlar Cloudflare edge'inde tutulur; panel mutasyonları
// bustManifest ile anında düşürür.
const MANIFEST_CK = 'https://api.selaya.app/v1/manifest';
const LIKES_CK = 'https://api.selaya.app/v1/likes';
const FINANCE_CK = 'https://api.selaya.app/v1/finance';
const NOTIF_CK = 'https://api.selaya.app/v1/notifications';
// Beğeni key'i = type:id. Bilinen içerik türleriyle SINIRLI → rastgele key
// seliyle likes tablosuna sınırsız satır yazılmasını engeller. Yeni bir tür
// eklenirse buraya da eklenmeli.
const LIKE_KEY_RE = /^(verse|hadith|dua|feed|wallpaper|surah|story|video|ayah):[A-Za-z0-9_.-]{1,64}$/;
function bustManifest(ctx) {
  if (!ctx) return;
  try {
    ctx.waitUntil(caches.default.delete(MANIFEST_CK));
    ctx.waitUntil(caches.default.delete(NOTIF_CK));
  } catch (_) {}
}

// İçerik şikayeti (Bildir) — duvar kağıdı/video/ses vb. için kullanıcı bildirimi.
// IP'yi ham SAKLAMAYIZ; yalnız dedup için zayıf hash (aynı kişi tek içeriği
// şişiremesin → UNIQUE(ckey,iphash)).
function quickHash(s) {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) >>> 0;
  return h.toString(36);
}
let _reportsOk = false;
async function ensureReports(env) {
  if (_reportsOk) return;
  try {
    await env.DB.prepare(
      'CREATE TABLE IF NOT EXISTS content_reports (id TEXT PRIMARY KEY, ckey TEXT NOT NULL, ' +
      'ctype TEXT, ctitle TEXT, reason TEXT, iphash TEXT, user_id TEXT, created_at INTEGER)'
    ).run();
    await env.DB.prepare(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_creports_dedup ON content_reports(ckey, iphash)'
    ).run();
  } catch (_) {}
  _reportsOk = true;
}

// likes tablosuna "son beğeni zamanı" kolonu — bildirim akışında (/api/activity)
// son beğenilen içeriği zamanlı gösterebilmek için. Eski deploy'da yoksa eklenir.
let _likesColOk = false;
async function ensureLikesCol(env) {
  if (_likesColOk) return;
  try {
    await env.DB.prepare('ALTER TABLE likes ADD COLUMN last_at INTEGER').run();
  } catch (_) {}
  _likesColOk = true;
}

function extOf(name, fallback) {
  const e = (name || '').split('.').pop();
  return (e && e.length <= 5 ? e : fallback).toLowerCase();
}

async function putFile(env, key, file) {
  await env.CDN.put(key, await file.arrayBuffer(), {
    httpMetadata: {
      contentType: file.type || 'application/octet-stream',
      cacheControl: 'public, max-age=604800',
    },
  });
}

// Free-tier kullanım istatistiği: R2 (nesne boyutları) + D1 (tablo satır + boyut).
// Tamamı binding'lerden hesaplanır — harici Analytics API/token GEREKMEZ.
async function computeStats(env) {
  const GB = 1073741824;
  // --- D1: tablo satır sayıları + DB boyutu (PRAGMA) ---
  let d1Bytes = 0, d1Rows = 0;
  const tables = [];
  try {
    const t = await env.DB.prepare(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '_cf_%' ORDER BY name"
    ).all();
    // D1 boyutu: sorgu meta'sının size_after alanı (DB dosya boyutu) — gerçek
    // tabloya erişen bu sorguda dolu gelir.
    d1Bytes = Number(t && t.meta && t.meta.size_after) || 0;
    for (const row of (t.results || [])) {
      let n = 0;
      try {
        const c = await env.DB.prepare('SELECT COUNT(*) AS n FROM "' + row.name + '"').first();
        n = (c && c.n) || 0;
      } catch (_) {}
      tables.push({ name: row.name, rows: n });
      d1Rows += n;
    }
  } catch (_) {}
  // --- R2: toplam boyut + nesne sayısı + üst klasöre göre döküm ---
  let r2Bytes = 0, r2Count = 0, cursor;
  const byPrefix = {};
  try {
    do {
      const list = await env.CDN.list({ limit: 1000, cursor });
      for (const o of list.objects) {
        r2Bytes += o.size; r2Count++;
        const top = (o.key.split('/')[0]) || '(kök)';
        if (!byPrefix[top]) byPrefix[top] = { bytes: 0, count: 0 };
        byPrefix[top].bytes += o.size; byPrefix[top].count++;
      }
      cursor = list.truncated ? list.cursor : null;
    } while (cursor);
  } catch (_) {}

  return {
    ok: true,
    generatedAt: new Date().toISOString(),
    d1: { bytes: d1Bytes, limitBytes: 5 * GB, rows: d1Rows, tables },
    r2: { bytes: r2Bytes, limitBytes: 10 * GB, count: r2Count, byPrefix },
    limits: {
      r2ClassAMonth: 1000000, r2ClassBMonth: 10000000,
      d1RowsReadDay: 5000000, d1RowsWriteDay: 100000, workersReqDay: 100000,
    },
  };
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const host = url.hostname;
    const path = url.pathname;

    if (request.method === 'OPTIONS') return new Response(null, { headers: CORS });

    // ---------- PUBLIC API (api.selaya.app) ----------
    if (host.startsWith('api.')) {
      if (path === '/' || path === '/health') return json({ ok: true, service: 'selaya-api' });

      // GİZLİLİK POLİTİKASI — uygulama içi link + Play için erişilebilir HTML
      // (kaynak: store/privacy-policy.html → src/privacy.js, gen-privacy.js ile).
      const privacyResp = handlePrivacy(request, path);
      if (privacyResp) return privacyResp;

      // ÜYELİK & SENKRON (kayıt/giriş/profil/veri) — ayrı modül, auth değilse null.
      const authResp = await handleAuth(request, env, path, ctx);
      if (authResp) return authResp;

      // DUA DUVARI (#10) — üyeler dua paylaşır, panelde onaylanınca yayınlanır.
      const duaResp = await handleDuaWall(request, env, path, ctx);
      if (duaResp) return duaResp;

      // TOPLULUK HATMİ — üyeler cüz alır/okur; 30 cüz dolunca hatim tamamlanır.
      const hatimResp = await handleHatim(request, env, path);
      if (hatimResp) return hatimResp;

      // BİLGİ YARIŞMASI — haftalık skor gönderimi + liderlik tablosu.
      const quizResp = await handleQuiz(request, env, path);
      if (quizResp) return quizResp;

      // FİNANS — canlı gram altın (₺) + Diyanet fitre (zekât/fitre hesabı için).
      // 30 dk edge cache: kaynağı yormaz, uygulama her açılışta güncel çeker.
      if (path === '/v1/finance') {
        const cache = caches.default;
        const hit = await cache.match(FINANCE_CK);
        if (hit) return hit;
        let goldGram = 0, goldUpdated = '';
        try {
          const r = await fetch('https://finans.truncgil.com/v4/today.json',
              { cf: { cacheTtl: 1800 } });
          if (r.ok) {
            const d = await r.json();
            goldGram = Number(d && d.GRA && d.GRA.Selling) || 0;
            goldUpdated = (d && d.Update_Date) || '';
          }
        } catch (_) {}
        const resp = json({
          ok: true,
          goldGram,                              // ₺/gram (gram altın satış)
          goldSource: 'finans.truncgil.com',
          goldUpdated,
          fitre: 240,                            // Diyanet 2026 (Ramazan 2026–2027)
          fitreYear: '2026',
          fitreSource: 'Diyanet İşleri Başkanlığı',
          generatedAt: new Date().toISOString(),
        }, { maxage: 1800 });
        ctx.waitUntil(cache.put(FINANCE_CK, resp.clone()));
        return resp;
      }

      if (path === '/v1/manifest') {
        const cache = caches.default;
        const hit = await cache.match(MANIFEST_CK);
        if (hit) return hit;
        const { results } = await env.DB.prepare(
          'SELECT id, collection, kind, key, title, subtitle, thumb_key, extra, sort ' +
          'FROM content_items WHERE active = 1 ORDER BY collection, sort, created_at'
        ).all();
        const base = env.CDN_BASE;
        const collections = {};
        for (const r of results) {
          // null alanlar hiç yazılmaz → binlerce öğede ciddi byte tasarrufu.
          const it = { id: r.id, kind: r.kind, url: r.key ? base + '/' + r.key : '' };
          if (r.thumb_key) it.thumb = base + '/' + r.thumb_key;
          if (r.title) it.title = r.title;
          if (r.subtitle) it.subtitle = r.subtitle;
          if (r.extra) { const x = safeParse(r.extra); if (x) it.extra = x; }
          (collections[r.collection] = collections[r.collection] || []).push(it);
        }
        // 'updated: Date.now()' bilerek YOK: gövde içerik değişmedikçe bayt-bayt
        // aynı kalır → uygulama "değişti mi?" kıyasını ucuza yapar.
        const resp = json({ ok: true, cdn: base, collections }, { maxage: 120 });
        if (ctx) ctx.waitUntil(cache.put(MANIFEST_CK, resp.clone()));
        return resp;
      }

      if (path === '/v1/notifications') {
        // 30 sn edge cache (önceden header vardı ama edge'e YAZILMIYORDU → her
        // açılış D1'e iniyordu). Panel mutasyonu bustManifest ile NOTIF_CK'yı düşürür.
        const cache = caches.default;
        const hit = await cache.match(NOTIF_CK);
        if (hit) return hit;
        const { results } = await env.DB.prepare(
          'SELECT id, title, body, image_key, link, created_at FROM notifications ' +
          'WHERE active = 1 ORDER BY created_at DESC LIMIT 50'
        ).all();
        const base = env.CDN_BASE;
        const items = results.map((r) => ({
          id: r.id,
          title: r.title,
          body: r.body || null,
          image: r.image_key ? base + '/' + r.image_key : null,
          link: r.link || null,
          created_at: r.created_at,
        }));
        const resp = json({ ok: true, items }, { maxage: 30 });
        if (ctx) ctx.waitUntil(cache.put(NOTIF_CK, resp.clone()));
        return resp;
      }

      // GET /v1/quran-audio/{sure}/{ayet} — Kuran ayet sesi.
      // everyayah'tan (Alafasy 128k) çekip Cloudflare edge'de 30 gün önbellekler.
      // Ayet-ayet çalma korunur; kaynağı buradan kontrol ederiz (everyayah sorun
      // çıkarırsa uygulamayı güncellemeden burada değiştirebiliriz).
      {
        const qa = path.match(/^\/v1\/quran-audio\/(\d{1,3})\/(\d{1,3})$/);
        if (qa) {
          const surah = parseInt(qa[1], 10);
          const ayah = parseInt(qa[2], 10);
          if (surah < 1 || surah > 114 || ayah < 1 || ayah > 286) {
            return json({ ok: false, error: 'bad_ref' }, { status: 400 });
          }
          // IP başına ses isteği tavanı (kötüye kullanım / fatura koruması).
          // Binding yoksa (eski deploy) sessizce atlar — güvenli.
          if (env.AUDIO_RL) {
            const ip = request.headers.get('CF-Connecting-IP') || 'anon';
            const { success } = await env.AUDIO_RL.limit({ key: 'qa:' + ip });
            if (!success) {
              return new Response('rate_limited', { status: 429, headers: CORS });
            }
          }
          const pad = (n) => String(n).padStart(3, '0');
          const src = 'https://everyayah.com/data/Alafasy_128kbps/' +
            pad(surah) + pad(ayah) + '.mp3';
          const up = await fetch(src, { cf: { cacheTtl: 2592000, cacheEverything: true } });
          if (!up.ok) return json({ ok: false, error: 'upstream_' + up.status }, { status: 502 });
          const h = new Headers(CORS);
          h.set('Content-Type', 'audio/mpeg');
          h.set('Cache-Control', 'public, max-age=2592000');
          return new Response(up.body, { status: 200, headers: h });
        }
      }

      // GET /v1/likes — tüm beğeni sayıları { key: count }.
      if (path === '/v1/likes') {
        const cache = caches.default;
        const hit = await cache.match(LIKES_CK);
        if (hit) return hit;
        const { results } = await env.DB.prepare(
          'SELECT key, count FROM likes'
        ).all();
        const likes = {};
        for (const r of results) likes[r.key] = r.count;
        // 30 sn edge TTL: sayılar en geç yarım dakika gecikir; kullanıcının
        // kendi beğenisi uygulamada zaten anlık (optimistic) gösterilir.
        const resp = json({ ok: true, likes }, { maxage: 30 });
        if (ctx) ctx.waitUntil(cache.put(LIKES_CK, resp.clone()));
        return resp;
      }

      // POST /v1/like/{key} — beğeni +1 (upsert).
      {
        const lm = path.match(/^\/v1\/like\/(.+)$/);
        if (lm && request.method === 'POST') {
          const key = decodeURIComponent(lm[1]).slice(0, 80);
          // Yalnız geçerli içerik key'i (type:id) — rastgele key seliyle likes
          // tablosuna sınırsız yeni satır yazılmasını engelle.
          if (!LIKE_KEY_RE.test(key)) return json({ ok: false, error: 'bad_key' }, { status: 400 });
          // IP başına yazma hız limiti (fatura/DoS koruması; binding yoksa atla).
          if (env.WRITE_RL) {
            const ip = request.headers.get('CF-Connecting-IP') || 'anon';
            const { success } = await env.WRITE_RL.limit({ key: 'wr:' + ip });
            if (!success) return new Response('rate_limited', { status: 429, headers: CORS });
          }
          await ensureLikesCol(env);
          await env.DB.prepare(
            'INSERT INTO likes (key, count, last_at) VALUES (?1, 1, ?2) ' +
            'ON CONFLICT(key) DO UPDATE SET count = count + 1, last_at = ?2'
          ).bind(key, Date.now()).run();
          const row = await env.DB.prepare(
            'SELECT count FROM likes WHERE key = ?1'
          ).bind(key).first();
          return json({ ok: true, key, count: row ? row.count : 1 });
        }
      }

      // POST /v1/unlike/{key} — beğeni -1 (taban 0). Çift yönlü kalp: kullanıcı
      // beğeniyi geri alınca sunucudaki sayı da düşsün.
      {
        const um = path.match(/^\/v1\/unlike\/(.+)$/);
        if (um && request.method === 'POST') {
          const key = decodeURIComponent(um[1]).slice(0, 80);
          if (!LIKE_KEY_RE.test(key)) return json({ ok: false, error: 'bad_key' }, { status: 400 });
          if (env.WRITE_RL) {
            const ip = request.headers.get('CF-Connecting-IP') || 'anon';
            const { success } = await env.WRITE_RL.limit({ key: 'wr:' + ip });
            if (!success) return new Response('rate_limited', { status: 429, headers: CORS });
          }
          await env.DB.prepare(
            'UPDATE likes SET count = MAX(0, count - 1) WHERE key = ?1'
          ).bind(key).run();
          const row = await env.DB.prepare(
            'SELECT count FROM likes WHERE key = ?1'
          ).bind(key).first();
          return json({ ok: true, key, count: row ? row.count : 0 });
        }
      }

      // POST /v1/report — içerik şikayeti (Bildir). Anonim + IP-dedup + rate-limit.
      if (path === '/v1/report' && request.method === 'POST') {
        let b = null; try { b = await request.json(); } catch (_) {}
        const key = ((b && b.key) || '').toString().slice(0, 100);
        if (!key || !LIKE_KEY_RE.test(key)) return json({ ok: false, error: 'bad_key' }, { status: 400 });
        const ip = request.headers.get('CF-Connecting-IP') || 'anon';
        if (env.WRITE_RL) {
          const { success } = await env.WRITE_RL.limit({ key: 'rp:' + ip });
          if (!success) return new Response('rate_limited', { status: 429, headers: CORS });
        }
        await ensureReports(env);
        const reason = ((b && b.reason) || '').toString().slice(0, 300);
        const ctype = ((b && b.type) || '').toString().slice(0, 40);
        const ctitle = ((b && b.title) || '').toString().slice(0, 200);
        // INSERT OR IGNORE → aynı IP aynı içeriği bir kez şikayet eder (dedup).
        await env.DB.prepare(
          'INSERT OR IGNORE INTO content_reports (id,ckey,ctype,ctitle,reason,iphash,created_at) ' +
          'VALUES (?,?,?,?,?,?,?)'
        ).bind(crypto.randomUUID(), key, ctype, ctitle, reason, quickHash(ip), Date.now()).run();
        // Yönetici e-postası GÖNDERİLMEZ (kullanıcı isteği): şikayetler panelde
        // (🚩 Şikayetler) + bildirim akışında (/api/activity) görünür.
        return json({ ok: true });
      }

      return json({ ok: false, error: 'not_found' }, { status: 404 });
    }

    // ---------- ADMIN PANEL (panel.selaya.app) ----------
    if (host.startsWith('panel.')) {
      if (request.method === 'GET' && (path === '/' || path === '')) {
        return new Response(PANEL_HTML, { headers: { 'Content-Type': 'text/html; charset=utf-8' } });
      }

      if (path.startsWith('/api/')) {
        const token = request.headers.get('X-Admin-Token') || '';
        // Sabit-zamanlı karşılaştırma (timing side-channel kapalı).
        if (!env.ADMIN_TOKEN || !timingSafeEqual(token, env.ADMIN_TOKEN)) {
          return json({ ok: false, error: 'unauthorized' }, { status: 401 });
        }

        // Panelden gelen HER mutasyon manifest edge önbelleğini düşürür →
        // yüklenen/silinen içerik uygulamaya 120 sn TTL beklemeden yansır.
        if (request.method !== 'GET') bustManifest(ctx);

        // ---- kullanım istatistikleri (free tier takibi) ----
        if (request.method === 'GET' && path === '/api/stats') {
          return json(await computeStats(env));
        }

        // ---- üyeler (Faz 4: panel 'Kullanıcılar' sekmesi) ----
        if (request.method === 'GET' && path === '/api/users') {
          const { results } = await env.DB.prepare(
            'SELECT u.id, u.name, u.surname, u.email, u.rumuz, u.banned, u.ban_reason, ' +
            'u.email_verified, u.created_at, u.last_active, d.updated_at AS data_updated, d.device ' +
            'FROM users u LEFT JOIN user_data d ON d.user_id = u.id ' +
            "WHERE u.id NOT IN ('seed-demo','panel-author') " +
            'ORDER BY u.banned DESC, u.created_at DESC LIMIT 1000'
          ).all();
          return json({ ok: true, users: results });
        }
        // ---- üye sil (KVKK: hesabı + verisini kalıcı sil) ----
        if (request.method === 'POST' && path === '/api/user-delete') {
          const form = await request.formData();
          const uid = (form.get('id') || '').toString();
          if (!uid) return json({ ok: false, error: 'id_required' }, { status: 400 });
          await env.DB.prepare('DELETE FROM user_data WHERE user_id=?').bind(uid).run();
          await env.DB.prepare('DELETE FROM users WHERE id=?').bind(uid).run();
          return json({ ok: true });
        }
        // ---- üye şifresini sıfırla (admin; kullanıcı unuttuğunda manuel) ----
        if (request.method === 'POST' && path === '/api/user-reset-password') {
          const form = await request.formData();
          const uid = (form.get('id') || '').toString();
          const pw = (form.get('password') || '').toString();
          if (!uid || pw.length < 6) {
            return json({ ok: false, error: 'bad_input' }, { status: 400 });
          }
          const np = await hashPassword(pw);
          await env.DB.prepare(
            'UPDATE users SET pass_hash=?, pass_salt=?, iters=?, failed_attempts=0, locked_until=0 WHERE id=?'
          ).bind(np.hash, np.salt, np.iters, uid).run();
          return json({ ok: true });
        }
        // ---- üye bilgilerini düzenle (ad / soyad / e-posta / rumuz) ----
        if (request.method === 'POST' && path === '/api/user-update') {
          const form = await request.formData();
          const uid = (form.get('id') || '').toString();
          const name = (form.get('name') || '').toString().trim();
          const surname = (form.get('surname') || '').toString().trim();
          const email = (form.get('email') || '').toString().trim().toLowerCase();
          const rumuz = (form.get('rumuz') || '').toString().trim();
          if (!uid) return json({ ok: false, error: 'id_required' }, { status: 400 });
          if (!name) return json({ ok: false, error: 'name_required' }, { status: 400 });
          if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) {
            return json({ ok: false, error: 'invalid_email' }, { status: 400 });
          }
          // E-posta başka bir üyede kayıtlıysa engelle (UNIQUE çakışması).
          const clash = await env.DB.prepare(
            'SELECT id FROM users WHERE email=? AND id<>?'
          ).bind(email, uid).first();
          if (clash) return json({ ok: false, error: 'email_taken' }, { status: 409 });
          // Rumuz başka bir üyede kayıtlıysa engelle.
          if (rumuz) {
            const rclash = await env.DB.prepare(
              'SELECT id FROM users WHERE rumuz=? COLLATE NOCASE AND id<>?'
            ).bind(rumuz, uid).first();
            if (rclash) return json({ ok: false, error: 'rumuz_taken' }, { status: 409 });
          }
          await env.DB.prepare(
            'UPDATE users SET name=?, surname=?, email=?, rumuz=? WHERE id=?'
          ).bind(name, surname, email, rumuz || null, uid).run();
          return json({ ok: true });
        }
        // ---- panelden YENİ ÜYE oluştur (admin; kullanıcı bu e-posta+şifre ile giriş yapar) ----
        if (request.method === 'POST' && path === '/api/user-create') {
          const form = await request.formData();
          const name = (form.get('name') || '').toString().trim();
          const surname = (form.get('surname') || '').toString().trim();
          const email = (form.get('email') || '').toString().trim().toLowerCase();
          const password = (form.get('password') || '').toString();
          const rumuz = (form.get('rumuz') || '').toString().trim();
          if (!name) return json({ ok: false, error: 'name_required' }, { status: 400 });
          if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) {
            return json({ ok: false, error: 'invalid_email' }, { status: 400 });
          }
          if (password.length < 6) return json({ ok: false, error: 'weak_password' }, { status: 400 });
          const clash = await env.DB.prepare('SELECT id FROM users WHERE email=?').bind(email).first();
          if (clash) return json({ ok: false, error: 'email_taken' }, { status: 409 });
          // Rumuz da kayıtlıysa engelle (büyük/küçük harf duyarsız) — çakışan kimlik olmasın.
          if (rumuz) {
            const rclash = await env.DB.prepare('SELECT id FROM users WHERE rumuz=? COLLATE NOCASE').bind(rumuz).first();
            if (rclash) return json({ ok: false, error: 'rumuz_taken' }, { status: 409 });
          }
          const np = await hashPassword(password);
          const id = crypto.randomUUID();
          await env.DB.prepare(
            'INSERT INTO users (id,name,surname,email,pass_hash,pass_salt,iters,email_verified,created_at,last_active,rumuz,banned) ' +
            'VALUES (?,?,?,?,?,?,?,1,?,0,?,0)'
          ).bind(id, name, surname, email, np.hash, np.salt, np.iters, Date.now(), rumuz || null).run();
          return json({ ok: true, id });
        }
        // ---- BAN: kullanıcı uygulamaya giremez + otomatik çıkış + cihazları düşür ----
        if (request.method === 'POST' && path === '/api/user-ban') {
          const form = await request.formData();
          const uid = (form.get('id') || '').toString();
          const reason = (form.get('reason') || '').toString().slice(0, 200);
          if (!uid) return json({ ok: false, error: 'id_required' }, { status: 400 });
          await env.DB.prepare(
            'UPDATE users SET banned=1, ban_reason=?, banned_at=? WHERE id=?'
          ).bind(reason, Date.now(), uid).run();
          // Cihaz kayıtlarını sil → mevcut token'lar da hemen geçersiz (sonraki
          // istekte 'banned' zaten döner; bu garantiyi güçlendirir).
          await env.DB.prepare('DELETE FROM user_devices WHERE user_id=?').bind(uid).run();
          // Banlanan kullanıcının dua duvarı gönderileri de kalksın (yayında +
          // bekleyen hepsi); dua_amins FK CASCADE ile temizlenir.
          await env.DB.prepare('DELETE FROM dua_wall WHERE user_id=?').bind(uid).run();
          return json({ ok: true });
        }
        // ---- AF / yasağı kaldır ----
        if (request.method === 'POST' && path === '/api/user-unban') {
          const form = await request.formData();
          const uid = (form.get('id') || '').toString();
          if (!uid) return json({ ok: false, error: 'id_required' }, { status: 400 });
          await env.DB.prepare(
            'UPDATE users SET banned=0, ban_reason=NULL, banned_at=0 WHERE id=?'
          ).bind(uid).run();
          return json({ ok: true });
        }

        // ---- DUA DUVARI MODERASYONU (#10) ----
        // Bekleyenler + son kararlananlar (moderatör bağlamı görsün).
        if (request.method === 'GET' && path === '/api/dua-pending') {
          // Yazarın hesap bilgisi de gelsin (moderatör kim olduğunu + kayıtlı
          // rumuzunu görsün → sahte/uyumsuz rumuz yakalanır).
          const AUTHCOLS =
            "u.email AS author_email, u.name AS author_name, u.surname AS author_surname, " +
            "u.rumuz AS author_rumuz, u.banned AS author_banned, u.ban_reason AS author_ban_reason, " +
            "u.email_verified AS author_verified, u.created_at AS author_created, u.last_active AS author_last, " +
            "ud.device AS author_device ";
          const AUTHJOIN =
            "LEFT JOIN users u ON u.id=d.user_id LEFT JOIN user_data ud ON ud.user_id=d.user_id ";
          const pending = await env.DB.prepare(
            "SELECT d.id, d.user_id, d.rumuz, d.text, d.amins, d.created_at, " + AUTHCOLS +
            "FROM dua_wall d " + AUTHJOIN +
            "WHERE d.status='pending' ORDER BY d.created_at ASC LIMIT 200"
          ).all();
          const recent = await env.DB.prepare(
            "SELECT d.id, d.user_id, d.rumuz, d.text, d.status, d.amins, d.created_at, d.decided_at, " + AUTHCOLS +
            "FROM dua_wall d " + AUTHJOIN +
            "WHERE d.status!='pending' ORDER BY d.decided_at DESC LIMIT 100"
          ).all();
          return json({
            ok: true,
            pending: pending.results || [],
            recent: recent.results || [],
          });
        }
        // Onayla → yayına al.
        if (request.method === 'POST' && path === '/api/dua-approve') {
          const form = await request.formData();
          const id = (form.get('id') || '').toString();
          if (!id) return json({ ok: false, error: 'id_required' }, { status: 400 });
          await env.DB.prepare(
            "UPDATE dua_wall SET status='approved', decided_at=? WHERE id=?"
          ).bind(Date.now(), id).run();
          return json({ ok: true });
        }
        // Reddet → gizle (kayıt kalır; istenirse sil).
        if (request.method === 'POST' && path === '/api/dua-reject') {
          const form = await request.formData();
          const id = (form.get('id') || '').toString();
          const del = (form.get('delete') || '').toString() === '1';
          if (!id) return json({ ok: false, error: 'id_required' }, { status: 400 });
          if (del) {
            await env.DB.prepare('DELETE FROM dua_wall WHERE id=?').bind(id).run();
          } else {
            await env.DB.prepare(
              "UPDATE dua_wall SET status='rejected', decided_at=? WHERE id=?"
            ).bind(Date.now(), id).run();
          }
          return json({ ok: true });
        }
        // Gizle / Göster → yayındaki duayı duvardan kaldır (status='hidden') ya da
        // tekrar yayınla (status='approved'). Kayıt SİLİNMEZ, geri alınabilir.
        // Herkese açık akış zaten yalnız status='approved' getirdiği için gizli
        // dualar uygulamada anında görünmez olur.
        if (request.method === 'POST' && path === '/api/dua-hide') {
          const form = await request.formData();
          const id = (form.get('id') || '').toString();
          const hide = (form.get('hidden') || '').toString() === '1';
          if (!id) return json({ ok: false, error: 'id_required' }, { status: 400 });
          await env.DB.prepare(
            "UPDATE dua_wall SET status=?, decided_at=? WHERE id=?"
          ).bind(hide ? 'hidden' : 'approved', Date.now(), id).run();
          return json({ ok: true });
        }
        // ---- panelden DUVARA DUA EKLE (admin; doğrudan 'approved' yayınlanır) ----
        if (request.method === 'POST' && path === '/api/dua-create') {
          const form = await request.formData();
          const rumuz = (form.get('rumuz') || '').toString().trim().slice(0, 40);
          const text = (form.get('text') || '').toString().trim().replace(/\s+/g, ' ');
          let amins = parseInt((form.get('amins') || '0').toString(), 10);
          if (!Number.isFinite(amins) || amins < 0) amins = 0;
          if (!rumuz) return json({ ok: false, error: 'rumuz_required' }, { status: 400 });
          if (text.length < 3) return json({ ok: false, error: 'too_short' }, { status: 400 });
          if (text.length > 280) return json({ ok: false, error: 'too_long' }, { status: 400 });
          // Panel duaları sabit bir sistem yazarına bağlanır (FK). seed-demo'dan
          // AYRI kalıcı hesap → "sahte/seed duaları sil" işlemi bunları silmez.
          const now = Date.now();
          await env.DB.prepare(
            "INSERT OR IGNORE INTO users (id,name,surname,email,pass_hash,pass_salt,rumuz,banned,created_at) " +
            "VALUES ('panel-author','Panel','','panel-author@selaya.app','-','-','SELAYA',0,?)"
          ).bind(now).run();
          const id = 'panel-' + crypto.randomUUID();
          await env.DB.prepare(
            "INSERT INTO dua_wall (id,user_id,rumuz,text,status,amins,created_at,decided_at) " +
            "VALUES (?,'panel-author',?,?,'approved',?,?,?)"
          ).bind(id, rumuz, text, amins, now, now).run();
          return json({ ok: true, id });
        }
        // ---- dua düzenle (rumuz / metin) — moderatör içeriği düzeltebilir ----
        if (request.method === 'POST' && path === '/api/dua-update') {
          const form = await request.formData();
          const id = (form.get('id') || '').toString();
          const rumuz = (form.get('rumuz') || '').toString().trim().slice(0, 40);
          const text = (form.get('text') || '').toString().trim().replace(/\s+/g, ' ');
          if (!id) return json({ ok: false, error: 'id_required' }, { status: 400 });
          if (!rumuz) return json({ ok: false, error: 'rumuz_required' }, { status: 400 });
          if (text.length < 3) return json({ ok: false, error: 'too_short' }, { status: 400 });
          if (text.length > 280) return json({ ok: false, error: 'too_long' }, { status: 400 });
          await env.DB.prepare('UPDATE dua_wall SET rumuz=?, text=? WHERE id=?').bind(rumuz, text, id).run();
          return json({ ok: true });
        }

        // ---- TOPLULUK HATMİ (admin: tüm kampanyalar + cüz detayı + yönetim) ----
        if (request.method === 'GET' && path === '/api/hatim') {
          // Tablolar yoksa (app henüz hiç çağırmadıysa) güvenli oluştur.
          await env.DB.batch([
            env.DB.prepare("CREATE TABLE IF NOT EXISTS hatim_campaigns (id TEXT PRIMARY KEY, title TEXT NOT NULL, intention TEXT, status TEXT NOT NULL DEFAULT 'active', created_by TEXT, created_rumuz TEXT, created_at INTEGER NOT NULL DEFAULT 0, completed_at INTEGER)"),
            env.DB.prepare("CREATE TABLE IF NOT EXISTS hatim_juz (campaign_id TEXT NOT NULL, juz_no INTEGER NOT NULL, user_id TEXT, rumuz TEXT, status TEXT NOT NULL DEFAULT 'open', claimed_at INTEGER, done_at INTEGER, PRIMARY KEY (campaign_id, juz_no))"),
          ]);
          const camps = await env.DB.prepare(
            "SELECT id,title,intention,status,created_by,created_rumuz,created_at,completed_at " +
            "FROM hatim_campaigns ORDER BY (status='active') DESC, created_at DESC LIMIT 100"
          ).all();
          const out = [];
          for (const c of camps.results || []) {
            const j = await env.DB.prepare(
              "SELECT j.juz_no, j.status, j.rumuz, j.claimed_at, j.done_at, " +
              "u.email AS claimer_email, u.name AS claimer_name FROM hatim_juz j " +
              "LEFT JOIN users u ON u.id=j.user_id WHERE j.campaign_id=? ORDER BY j.juz_no"
            ).bind(c.id).all();
            const juz = j.results || [];
            out.push({
              ...c,
              done: juz.filter((x) => x.status === 'done').length,
              claimed: juz.filter((x) => x.status === 'claimed').length,
              juz,
            });
          }
          return json({ ok: true, campaigns: out });
        }
        // Kampanya sil (+ cüzleri).
        if (request.method === 'POST' && path === '/api/hatim-delete') {
          const form = await request.formData();
          const id = (form.get('id') || '').toString();
          if (!id) return json({ ok: false, error: 'id_required' }, { status: 400 });
          await env.DB.prepare('DELETE FROM hatim_juz WHERE campaign_id=?').bind(id).run();
          await env.DB.prepare('DELETE FROM hatim_campaigns WHERE id=?').bind(id).run();
          return json({ ok: true });
        }
        // Bir cüzü sıfırla (open) — terk edilmiş/yanlış claim'i admin açar.
        if (request.method === 'POST' && path === '/api/hatim-juz-reset') {
          const form = await request.formData();
          const id = (form.get('id') || '').toString();
          const juz = parseInt(form.get('juz') || '0', 10);
          if (!id || !(juz >= 1 && juz <= 30)) {
            return json({ ok: false, error: 'bad_input' }, { status: 400 });
          }
          await env.DB.prepare(
            "UPDATE hatim_juz SET status='open', user_id=NULL, rumuz=NULL, claimed_at=NULL, done_at=NULL WHERE campaign_id=? AND juz_no=?"
          ).bind(id, juz).run();
          // Kampanya 'completed' idiyse bir cüz açıldığı için tekrar aktif olur.
          await env.DB.prepare(
            "UPDATE hatim_campaigns SET status='active', completed_at=NULL WHERE id=? AND status='completed'"
          ).bind(id).run();
          return json({ ok: true });
        }
        // Panelden hatim başlat (resmî/niyetli).
        if (request.method === 'POST' && path === '/api/hatim-create') {
          const form = await request.formData();
          const title = (form.get('title') || '').toString().trim().slice(0, 120);
          const intention = (form.get('intention') || '').toString().trim().slice(0, 160);
          if (title.length < 2) return json({ ok: false, error: 'title_required' }, { status: 400 });
          const id = 'htm-' + crypto.randomUUID();
          const now = Date.now();
          await env.DB.prepare(
            "INSERT INTO hatim_campaigns (id,title,intention,status,created_by,created_rumuz,created_at) " +
            "VALUES (?,?,?,'active','panel','Panel',?)"
          ).bind(id, title, intention, now).run();
          const stmts = [];
          for (let n = 1; n <= 30; n++) {
            stmts.push(env.DB.prepare(
              "INSERT OR IGNORE INTO hatim_juz (campaign_id,juz_no,status) VALUES (?,?, 'open')"
            ).bind(id, n));
          }
          await env.DB.batch(stmts);
          return json({ ok: true, id });
        }

        // ---- BİLGİ YARIŞMASI: haftalık sıralama (admin) ----
        if (request.method === 'GET' && path === '/api/quiz-leaderboard') {
          // Tablo yoksa (kimse oynamadıysa) boş dön.
          await env.DB.prepare(
            "CREATE TABLE IF NOT EXISTS quiz_scores (user_id TEXT NOT NULL, week TEXT NOT NULL, " +
            "rumuz TEXT, score INTEGER NOT NULL DEFAULT 0, correct INTEGER, total INTEGER, " +
            "updated_at INTEGER, PRIMARY KEY (user_id, week))"
          ).run();
          const url = new URL(request.url);
          const weeksRes = await env.DB.prepare(
            "SELECT week, COUNT(*) AS n FROM quiz_scores GROUP BY week ORDER BY week DESC LIMIT 30"
          ).all();
          const weeks = (weeksRes.results || []).map((r) => ({ week: r.week, n: r.n }));
          const week = url.searchParams.get('week') || (weeks[0] && weeks[0].week) || '';
          let rows = [];
          if (week) {
            const r = await env.DB.prepare(
              "SELECT q.rumuz, q.score, q.correct, q.total, q.updated_at, u.email " +
              "FROM quiz_scores q LEFT JOIN users u ON u.id=q.user_id " +
              "WHERE q.week=? ORDER BY q.score DESC, q.updated_at ASC LIMIT 200"
            ).bind(week).all();
            rows = r.results || [];
          }
          return json({ ok: true, week, weeks, rows });
        }

        // ---- İÇERİK ŞİKAYETLERİ (Bildir) ----
        if (request.method === 'GET' && path === '/api/content-reports') {
          await ensureReports(env);
          const r = await env.DB.prepare(
            "SELECT ckey, MAX(ctype) AS ctype, MAX(ctitle) AS ctitle, COUNT(*) AS n, " +
            "MAX(created_at) AS last, GROUP_CONCAT(NULLIF(reason,''), ' • ') AS reasons " +
            "FROM content_reports GROUP BY ckey ORDER BY n DESC, last DESC LIMIT 300"
          ).all();
          return json({ ok: true, rows: r.results || [] });
        }
        if (request.method === 'POST' && path === '/api/content-report-clear') {
          let b = null; try { b = await request.json(); } catch (_) {}
          const key = ((b && b.key) || '').toString();
          if (!key) return json({ ok: false, error: 'no_key' }, { status: 400 });
          await ensureReports(env);
          await env.DB.prepare('DELETE FROM content_reports WHERE ckey=?').bind(key).run();
          return json({ ok: true });
        }

        // ---- 🔔 Bildirim akışı: son aktiviteler (üye/dua/şikayet/hatim/beğeni) ----
        // E-posta GÖNDERİLMEZ; yönetici her şeyi buradan günlük takip eder.
        if (request.method === 'GET' && path === '/api/activity') {
          await ensureReports(env);
          await ensureLikesCol(env);
          const out = [];
          const add = (rows, fn) => {
            for (const r of (rows || [])) {
              const e = fn(r);
              if (e && e.at) out.push(e);
            }
          };
          const q = async (sql) => {
            try { return (await env.DB.prepare(sql).all()).results || []; }
            catch (_) { return []; }
          };
          add(await q('SELECT name, surname, rumuz, created_at FROM users ORDER BY created_at DESC LIMIT 25'),
            (r) => ({ type: 'member', at: +r.created_at || 0,
              title: ((r.name || '') + ' ' + (r.surname || '')).trim() || 'Yeni üye',
              sub: r.rumuz ? '@' + r.rumuz : '' }));
          add(await q('SELECT rumuz, text, status, created_at FROM dua_wall ORDER BY created_at DESC LIMIT 25'),
            (r) => ({ type: 'dua', at: +r.created_at || 0,
              title: '@' + (r.rumuz || '—'), sub: (r.text || '').slice(0, 90), tag: r.status }));
          add(await q('SELECT ckey, ctitle, reason, created_at FROM content_reports ORDER BY created_at DESC LIMIT 25'),
            (r) => ({ type: 'report', at: +r.created_at || 0,
              title: r.ctitle || r.ckey, sub: r.reason || '' }));
          add(await q("SELECT juz_no, rumuz, claimed_at FROM hatim_juz WHERE claimed_at IS NOT NULL ORDER BY claimed_at DESC LIMIT 15"),
            (r) => ({ type: 'hatim', at: +r.claimed_at || 0,
              title: 'Cüz ' + r.juz_no + ' alındı', sub: r.rumuz ? '@' + r.rumuz : '' }));
          add(await q("SELECT juz_no, rumuz, done_at FROM hatim_juz WHERE status='done' AND done_at IS NOT NULL ORDER BY done_at DESC LIMIT 15"),
            (r) => ({ type: 'hatimDone', at: +r.done_at || 0,
              title: 'Cüz ' + r.juz_no + ' okundu ✓', sub: r.rumuz ? '@' + r.rumuz : '' }));
          add(await q('SELECT key, count, last_at FROM likes WHERE last_at IS NOT NULL ORDER BY last_at DESC LIMIT 12'),
            (r) => ({ type: 'like', at: +r.last_at || 0,
              title: r.key, sub: (r.count || 0) + ' beğeni' }));
          out.sort((a, b) => b.at - a.at);
          return json({ ok: true, activity: out.slice(0, 80) });
        }

        // ---- metin içerik (ayet/hadis/dua/tebrik — DOSYASIZ) ----
        if (request.method === 'POST' && path === '/api/text') {
          const form = await request.formData();
          const collection = (form.get('collection') || 'inspiration').toString();
          const title = form.get('title') ? form.get('title').toString() : null;
          const subtitle = form.get('subtitle') ? form.get('subtitle').toString() : null;
          const sort = parseInt(form.get('sort') || '0', 10) || 0;
          let extra = null;
          try {
            const e = form.get('extra');
            if (e) extra = JSON.stringify(JSON.parse(e.toString()));
          } catch (_) {}
          if (!title && !subtitle) {
            return json({ ok: false, error: 'empty' }, { status: 400 });
          }
          const id = crypto.randomUUID();
          const now = Date.now();
          await env.DB.prepare(
            'INSERT INTO content_items (id, collection, kind, key, title, subtitle, thumb_key, extra, sort, active, created_at, updated_at) ' +
            'VALUES (?,?,?,?,?,?,?,?,?,1,?,?)'
          ).bind(id, collection, 'text', '', title, subtitle, null, extra, sort, now, now).run();
          return json({ ok: true, id });
        }

        // ---- içerik öğeleri ----
        if (request.method === 'GET' && path === '/api/items') {
          const { results } = await env.DB.prepare(
            'SELECT * FROM content_items ORDER BY collection, sort, created_at'
          ).all();
          // Her öğenin R2 boyutu (sesli hikâyede bölüm dosyaları da dahil).
          await Promise.all(results.map(async (r) => {
            let total = 0;
            try { const h = await env.CDN.head(r.key); if (h) total += h.size; } catch (e) {}
            if (r.collection === 'audio_stories' && r.extra) {
              try {
                const eps = (JSON.parse(r.extra).episodes) || [];
                await Promise.all(eps.map(async (e) => {
                  const k = (e.audio || '').replace(env.CDN_BASE + '/', '');
                  if (k && k.indexOf('http') !== 0) {
                    try { const h = await env.CDN.head(k); if (h) total += h.size; } catch (_) {}
                  }
                }));
              } catch (_) {}
            }
            r.size = total;
          }));
          return json({ ok: true, cdn: env.CDN_BASE, items: results });
        }

        // var olan bir öğenin dosyasını/görselini değiştir
        if (request.method === 'POST' && path.startsWith('/api/replace/')) {
          const rid = decodeURIComponent(path.split('/').pop());
          const form = await request.formData();
          const file = form.get('file');
          if (!file || typeof file === 'string') return json({ ok: false, error: 'file_required' }, { status: 400 });
          const row = await env.DB.prepare('SELECT collection, key FROM content_items WHERE id=?').bind(rid).first();
          if (!row) return json({ ok: false, error: 'not_found' }, { status: 404 });
          const type = file.type || 'application/octet-stream';
          const kind = type.startsWith('video') ? 'video' : type.startsWith('audio') ? 'audio' : 'image';
          const newKey = 'uploads/' + row.collection + '/' + crypto.randomUUID() + '.' + extOf(file.name, 'bin');
          await putFile(env, newKey, file);
          if (row.key && row.key.startsWith('uploads/')) { try { await env.CDN.delete(row.key); } catch (e) {} }
          await env.DB.prepare('UPDATE content_items SET key=?, kind=?, updated_at=? WHERE id=?').bind(newKey, kind, Date.now(), rid).run();
          return json({ ok: true, key: newKey, url: env.CDN_BASE + '/' + newKey });
        }

        // dosya (+ opsiyonel kapak) yükle -> R2 + içerik kaydı
        if (request.method === 'POST' && path === '/api/upload') {
          const form = await request.formData();
          const file = form.get('file');
          const cover = form.get('cover');
          const collection = (form.get('collection') || 'misc').toString();
          const title = form.get('title') ? form.get('title').toString() : null;
          const subtitle = form.get('subtitle') ? form.get('subtitle').toString() : null;
          const sort = parseInt(form.get('sort') || '0', 10) || 0;
          if (!file || typeof file === 'string') {
            return json({ ok: false, error: 'file_required' }, { status: 400 });
          }
          // Hikâye (stories) PANELDEN en fazla 5 eklenebilir (kullanıcı 2026-06-15).
          // Uygulama tarafı da en fazla 6 gösterir (ekstra güvence).
          if (collection === 'stories') {
            const cnt = await env.DB.prepare(
              "SELECT COUNT(*) AS n FROM content_items WHERE collection='stories' AND active=1"
            ).first();
            if (cnt && (cnt.n || 0) >= 5) {
              return json({
                ok: false,
                error: 'story_limit_5',
                message: 'En fazla 5 hikâye eklenebilir. Yeni eklemek için önce mevcut bir hikâyeyi silin.',
              }, { status: 400 });
            }
          }

          const type = file.type || 'application/octet-stream';
          const kind = type.startsWith('video') ? 'video' : type.startsWith('audio') ? 'audio' : 'image';
          // Video boyut sınırı: 4 MB (sunucu tarafı güvence; istemci de kontrol eder).
          if (kind === 'video' && file.size > 4 * 1024 * 1024) {
            return json({ ok: false, error: 'video_too_large', message: 'Video en fazla 4 MB olabilir.' }, { status: 400 });
          }
          const id = crypto.randomUUID();
          const key = 'uploads/' + collection + '/' + id + '.' + extOf(file.name, 'bin');
          await putFile(env, key, file);

          // Kapak: ses/video için manuel kapak; GÖRSELLERDE panel otomatik
          // küçük önizleme (≤560px WebP) gönderir → ızgaralar/listeler tam boy
          // dosyayı indirmez (1000 görselde ana fark budur).
          let thumbKey = null;
          if (cover && typeof cover !== 'string') {
            thumbKey = 'uploads/' + collection + '/' + id + '_cover.' + extOf(cover.name, 'webp');
            await putFile(env, thumbKey, cover);
          }

          const now = Date.now();
          await env.DB.prepare(
            'INSERT INTO content_items (id, collection, kind, key, title, subtitle, thumb_key, sort, active, created_at, updated_at) ' +
            'VALUES (?,?,?,?,?,?,?,?,1,?,?)'
          ).bind(id, collection, kind, key, title, subtitle, thumbKey, sort, now, now).run();
          return json({ ok: true, id, key, url: env.CDN_BASE + '/' + key });
        }

        // sesli hikâye oluştur: 1 kapak + N bölüm (ses) -> tek kategori kaydı
        if (request.method === 'POST' && path === '/api/audio-story') {
          const form = await request.formData();
          const title = (form.get('title') || '').toString().trim();
          const subtitle = (form.get('subtitle') || '').toString();
          const cover = form.get('cover');
          const audios = form.getAll('ep_audio');
          const titles = form.getAll('ep_title');
          const subs = form.getAll('ep_sub');
          const durs = form.getAll('ep_dur');
          if (!title || !cover || typeof cover === 'string' || audios.length === 0) {
            return json({ ok: false, error: 'title_cover_episodes_required' }, { status: 400 });
          }
          const catId = crypto.randomUUID();
          const dir = 'uploads/audio_stories/' + catId + '/';
          const coverKey = dir + 'cover.' + extOf(cover.name, 'webp');
          await putFile(env, coverKey, cover);
          const episodes = [];
          for (let i = 0; i < audios.length; i++) {
            const a = audios[i];
            if (!a || typeof a === 'string') continue;
            const k = dir + 'ep' + i + '.' + extOf(a.name, 'mp3');
            await putFile(env, k, a);
            episodes.push({
              audio: env.CDN_BASE + '/' + k,
              title: (titles[i] || ('Bölüm ' + (i + 1))).toString(),
              subtitle: (subs[i] || '').toString(),
              durationSec: parseInt(durs[i] || '0', 10) || 0,
            });
          }
          if (episodes.length === 0) return json({ ok: false, error: 'no_episodes' }, { status: 400 });
          const now = Date.now();
          await env.DB.prepare(
            'INSERT INTO content_items (id, collection, kind, key, title, subtitle, extra, sort, active, created_at, updated_at) ' +
            'VALUES (?,?,?,?,?,?,?,?,1,?,?)'
          ).bind(catId, 'audio_stories', 'audio', coverKey, title, subtitle,
                 JSON.stringify({ episodes }), 0, now, now).run();
          return json({ ok: true, id: catId, episodes: episodes.length });
        }

        // var olan R2 anahtarından (veya dış-URL'li extra ile) içerik kaydı oluştur
        if (request.method === 'POST' && path === '/api/items') {
          const b = await request.json();
          if (!b.collection || !b.key) {
            return json({ ok: false, error: 'collection_and_key_required' }, { status: 400 });
          }
          const id = b.id || crypto.randomUUID();
          const now = Date.now();
          await env.DB.prepare(
            'INSERT INTO content_items (id, collection, kind, key, title, subtitle, thumb_key, extra, sort, active, created_at, updated_at) ' +
            'VALUES (?,?,?,?,?,?,?,?,?,?,?,?)'
          ).bind(id, b.collection, b.kind || 'image', b.key, b.title || null, b.subtitle || null,
                 b.thumb_key || null, b.extra ? JSON.stringify(b.extra) : null, b.sort || 0,
                 b.active === 0 ? 0 : 1, now, now).run();
          return json({ ok: true, id });
        }

        if (request.method === 'PUT' && path.startsWith('/api/items/')) {
          const id = decodeURIComponent(path.split('/').pop());
          const b = await request.json();
          const now = Date.now();
          // extra verilirse onu da güncelle (metin düzenlemede arabic/reference için).
          const hasExtra = (b.extra !== undefined && b.extra !== null);
          const args = [
            b.collection, b.kind || 'image',
            b.title == null ? null : b.title,
            b.subtitle == null ? null : b.subtitle,
            b.sort || 0, b.active === 0 ? 0 : 1,
          ];
          if (hasExtra) args.push(JSON.stringify(b.extra));
          args.push(now, id);
          await env.DB.prepare(
            'UPDATE content_items SET collection=?, kind=?, title=?, subtitle=?, sort=?, active=?, ' +
            (hasExtra ? 'extra=?, ' : '') + 'updated_at=? WHERE id=?'
          ).bind(...args).run();
          return json({ ok: true });
        }

        if (request.method === 'DELETE' && path.startsWith('/api/items/')) {
          const id = decodeURIComponent(path.split('/').pop());
          const row = await env.DB.prepare('SELECT key, thumb_key FROM content_items WHERE id=?').bind(id).first();
          if (row && row.key && row.key.startsWith('uploads/')) {
            try { await env.CDN.delete(row.key); } catch (e) {}
            if (row.thumb_key) { try { await env.CDN.delete(row.thumb_key); } catch (e) {} }
          }
          await env.DB.prepare('DELETE FROM content_items WHERE id=?').bind(id).run();
          return json({ ok: true });
        }

        // ---- bildirimler ----
        if (request.method === 'GET' && path === '/api/notifications') {
          const { results } = await env.DB.prepare(
            'SELECT * FROM notifications ORDER BY created_at DESC'
          ).all();
          return json({ ok: true, cdn: env.CDN_BASE, items: results });
        }

        if (request.method === 'POST' && path === '/api/notify') {
          const form = await request.formData();
          const title = (form.get('title') || '').toString().trim();
          const body = (form.get('body') || '').toString();
          const link = (form.get('link') || '').toString();
          const image = form.get('image');
          if (!title) return json({ ok: false, error: 'title_required' }, { status: 400 });
          let imageKey = null;
          if (image && typeof image !== 'string') {
            imageKey = 'notifications/' + crypto.randomUUID() + '.' + extOf(image.name, 'webp');
            await putFile(env, imageKey, image);
          }
          const id = crypto.randomUUID();
          const now = Date.now();
          await env.DB.prepare(
            'INSERT INTO notifications (id, title, body, image_key, link, active, created_at) VALUES (?,?,?,?,?,1,?)'
          ).bind(id, title, body, imageKey, link, now).run();
          return json({ ok: true, id });
        }

        if (request.method === 'DELETE' && path.startsWith('/api/notifications/')) {
          const id = decodeURIComponent(path.split('/').pop());
          await env.DB.prepare('DELETE FROM notifications WHERE id=?').bind(id).run();
          return json({ ok: true });
        }

        return json({ ok: false, error: 'not_found' }, { status: 404 });
      }

      return new Response('Not found', { status: 404 });
    }

    return new Response('SELAYA API', { status: 200, headers: { 'Content-Type': 'text/plain' } });
  },
};

const PANEL_HTML = `<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SELAYA — Yönetim Paneli</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap');
  :root{ --bg:#f3f4f7; --card:#fff; --gold:#c8941f; --gold-soft:#fbf3e0; --gold-line:#edd9ac; --txt:#1b2330; --mut:#717a8a; --line:#e8eaef; --danger:#e2556b; --ok:#16a34a;
    --shadow:0 1px 2px rgba(16,24,40,.04),0 5px 18px rgba(16,24,40,.05); }
  *{ box-sizing:border-box; }
  body{ margin:0; font-family:'Plus Jakarta Sans',system-ui,Segoe UI,sans-serif; background:var(--bg); color:var(--txt); -webkit-font-smoothing:antialiased; }
  /* ---- login ---- */
  .login-screen{ min-height:100vh; display:flex; align-items:center; justify-content:center; padding:20px; background:radial-gradient(1100px 460px at 50% -8%, #fff, var(--bg)); }
  .login-card{ background:var(--card); border:1px solid var(--line); border-radius:22px; box-shadow:var(--shadow); padding:34px 30px; width:100%; max-width:380px; text-align:center; }
  .login-card .brand{ font-weight:800; font-size:27px; letter-spacing:.5px; color:var(--gold); margin-bottom:6px; }
  .login-card p{ color:var(--mut); font-size:13px; line-height:1.6; margin:4px 0 18px; }
  .login-card input{ margin-bottom:12px; text-align:center; }
  .login-card button{ width:100%; }
  /* ---- dashboard layout ---- */
  .dashboard{ display:flex; min-height:100vh; }
  .sidebar{ width:248px; flex:0 0 248px; background:var(--card); border-right:1px solid var(--line); padding:18px 14px; position:sticky; top:0; height:100vh; overflow-y:auto; }
  .logo{ font-weight:800; font-size:22px; letter-spacing:.5px; color:var(--gold); padding:6px 10px 16px; display:flex; align-items:center; gap:9px; }
  .logo .d{ width:9px; height:9px; border-radius:50%; background:var(--gold); box-shadow:0 0 0 4px var(--gold-soft); }
  .nav-section{ font-size:10.5px; font-weight:700; letter-spacing:.9px; color:#a7afbc; text-transform:uppercase; margin:18px 12px 7px; }
  .nav-item{ display:flex; align-items:center; gap:11px; padding:11px 12px; border-radius:11px; color:var(--mut); font-weight:600; font-size:14px; cursor:pointer; transition:.15s; margin-bottom:2px; user-select:none; }
  .nav-item:hover{ background:#f6f7f9; color:var(--txt); }
  .nav-item.active{ background:var(--gold-soft); color:var(--gold); }
  .main{ flex:1; min-width:0; display:flex; flex-direction:column; }
  .topbar{ display:flex; align-items:center; gap:12px; padding:15px 26px; background:rgba(255,255,255,.82); backdrop-filter:blur(8px); border-bottom:1px solid var(--line); position:sticky; top:0; z-index:5; }
  .topbar h1{ font-size:19px; margin:0; flex:1; font-weight:700; }
  .bellbtn{ position:relative; background:none; border:0; font-size:21px; cursor:pointer; padding:4px 6px; line-height:1; }
  .bellbtn .dot{ position:absolute; top:-1px; right:-1px; min-width:16px; height:16px; box-sizing:border-box; background:#e0556b; color:#fff; font-size:10px; font-weight:700; border-radius:999px; padding:0 4px; display:none; align-items:center; justify-content:center; }
  .actPanel{ position:absolute; top:54px; right:14px; width:min(380px,92vw); max-height:72vh; overflow-y:auto; background:#fff; border:1px solid var(--line); border-radius:14px; box-shadow:0 14px 44px rgba(0,0,0,.18); z-index:30; padding:6px; }
  .actPanel h3{ margin:8px 10px 6px; font-size:14px; }
  .actRow{ display:flex; gap:10px; padding:9px 10px; border-radius:10px; align-items:flex-start; }
  .actRow:hover{ background:rgba(0,0,0,.04); }
  .actRow .ic{ font-size:18px; flex:0 0 auto; line-height:1.3; }
  .actRow .tx{ flex:1; min-width:0; }
  .actRow .tt{ font-weight:600; font-size:13.5px; }
  .actRow .sb{ color:var(--mut); font-size:12px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
  .actRow .tm{ color:var(--mut); font-size:11px; flex:0 0 auto; padding-top:2px; }
  .topbar .hamb{ display:none; background:none; border:0; color:var(--txt); font-size:22px; cursor:pointer; padding:0 4px; }
  .content{ padding:24px 26px 70px; width:100%; max-width:1080px; }
  /* ---- cards & controls ---- */
  .card{ background:var(--card); border:1px solid var(--line); border-radius:16px; padding:18px; margin-bottom:16px; box-shadow:var(--shadow); }
  h3{ margin:0 0 4px; font-size:15px; font-weight:700; }
  .hint{ color:var(--mut); font-size:12.5px; line-height:1.55; margin:0 0 12px; }
  label{ display:block; font-size:12.5px; font-weight:600; color:var(--mut); margin:12px 0 5px; }
  input,select,textarea{ width:100%; padding:11px 13px; background:#fff; border:1px solid var(--line); border-radius:11px; color:var(--txt); font-size:14px; font-family:inherit; transition:.15s; }
  input:focus,select:focus,textarea:focus{ outline:none; border-color:var(--gold); box-shadow:0 0 0 3px var(--gold-soft); }
  textarea{ min-height:72px; resize:vertical; }
  button{ background:var(--gold); color:#fff; border:0; padding:11px 18px; border-radius:11px; font-weight:700; cursor:pointer; font-size:14px; font-family:inherit; transition:.15s; }
  button:hover{ filter:brightness(1.07); } button:active{ transform:translateY(1px); } button:disabled{ opacity:.55; cursor:default; }
  button.ghost{ background:#fff; color:var(--gold); border:1px solid var(--gold-line); }
  button.ghost:hover{ background:var(--gold-soft); }
  button.danger{ background:#fff; color:var(--danger); border:1px solid #f3c7cf; padding:7px 11px; font-size:12px; }
  button.danger:hover{ background:#fdf0f2; }
  .row{ display:flex; gap:10px; flex-wrap:wrap; } .row > *{ flex:1; min-width:150px; }
  .muted{ color:var(--mut); font-size:12px; word-break:break-all; }
  .search{ margin:0 0 13px; background:#fbfbfc; }
  .search:focus{ background:#fff; }
  .ovl{ position:fixed; inset:0; background:rgba(16,24,40,.45); display:flex; align-items:center; justify-content:center; z-index:60; padding:20px; }
  .modalbox{ background:#fff; border-radius:18px; padding:22px; max-width:440px; width:100%; box-shadow:0 16px 50px rgba(0,0,0,.24); max-height:90vh; overflow:auto; }
  .modalbox h3{ margin:0 0 10px; font-size:17px; }
  .modalbox .danger{ padding:11px 18px; font-size:14px; }
  .kv{ display:flex; justify-content:space-between; gap:14px; padding:9px 0; border-top:1px solid var(--line); font-size:13.5px; }
  .kv:first-of-type{ border-top:0; }
  .kv > span{ color:var(--mut); flex:0 0 auto; }
  .kv > b{ text-align:right; word-break:break-word; }
  .hgrid{ display:grid; grid-template-columns:repeat(10,1fr); gap:5px; margin-top:4px; }
  .hjuz{ aspect-ratio:1; border-radius:8px; display:flex; align-items:center; justify-content:center; font-weight:700; font-size:13px; cursor:pointer; transition:.12s; }
  .hjuz:hover{ filter:brightness(.96); }
  @media(max-width:560px){ .hgrid{ grid-template-columns:repeat(6,1fr); } }
  .tabs{ display:none; }
  details{ border:1px solid var(--line); border-radius:14px; margin-bottom:10px; overflow:hidden; background:#fff; }
  summary{ cursor:pointer; padding:13px 15px; font-weight:700; color:var(--txt); list-style:none; display:flex; align-items:center; gap:8px; }
  summary::-webkit-details-marker{ display:none; }
  summary .cnt{ color:var(--mut); font-weight:500; font-size:12px; }
  details[open] > summary{ border-bottom:1px solid var(--line); }
  .items{ padding:4px 14px 12px; }
  .item{ display:flex; gap:11px; align-items:center; padding:11px 0; border-top:1px solid var(--line); }
  .item:first-child{ border-top:0; }
  .item img, .item video, .item .ph{ width:52px; height:52px; object-fit:cover; border-radius:10px; background:#f1f2f5; display:flex; align-items:center; justify-content:center; font-size:20px; flex:0 0 auto; color:var(--mut); }
  .item .meta{ flex:1; min-width:0; }
  .item .meta b{ display:block; font-size:13.5px; }
  .grip{ cursor:grab; color:#bcc2cd; font-size:17px; line-height:1; flex:0 0 auto; user-select:none; padding:0 1px; }
  .grip:active{ cursor:grabbing; }
  .item.dragging{ opacity:.45; background:var(--gold-soft); border-radius:10px; }
  .item.dragover-top{ box-shadow:inset 0 2px 0 var(--gold); }
  .badge{ font-size:11px; color:var(--gold); background:var(--gold-soft); border:1px solid var(--gold-line); border-radius:7px; padding:2px 7px; flex:0 0 auto; font-weight:600; }
  .hide{ display:none; }
  .toast{ position:fixed; bottom:20px; left:50%; transform:translateX(-50%); background:#1b2330; color:#fff; padding:11px 18px; border-radius:11px; font-size:13px; z-index:30; box-shadow:var(--shadow); }
  .note{ background:#f9fafb; border:1px dashed var(--line); border-radius:11px; padding:11px 13px; font-size:12.5px; color:var(--mut); margin-top:10px; }
  .ok{ color:var(--ok); font-weight:600; }
  .txtabs{ display:flex; flex-wrap:wrap; gap:7px; margin:2px 0 14px; }
  .txtab{ padding:6px 13px; border-radius:999px; background:#f1f2f5; color:var(--mut); font-size:12.5px; font-weight:600; cursor:pointer; border:1px solid transparent; transition:.15s; user-select:none; }
  .txtab:hover{ background:#e9ebef; color:var(--txt); }
  .txtab.active{ background:var(--gold-soft); color:var(--gold); border-color:var(--gold-line); }
  .txtab .txcnt{ opacity:.65; font-size:11px; margin-left:2px; }
  .txgroup{ flex-basis:100%; font-size:11px; font-weight:700; color:#a7afbc; text-transform:uppercase; letter-spacing:.5px; margin:8px 2px 0; }
  .backdrop{ display:none; }
  @media(max-width:760px){
    .sidebar{ position:fixed; left:0; top:0; z-index:25; transform:translateX(-100%); transition:.25s; box-shadow:0 0 50px rgba(0,0,0,.18); }
    .sidebar.open{ transform:translateX(0); }
    .topbar .hamb{ display:block; }
    .content{ padding:18px 15px 70px; }
    .backdrop.show{ display:block; position:fixed; inset:0; background:rgba(0,0,0,.32); z-index:20; }
  }
</style>
</head>
<body>
<!-- Giriş -->
<div id="authCard" class="login-screen">
  <div class="login-card">
    <div class="brand">◍ SELAYA</div>
    <p>Yönetim Paneli — yönetici anahtarını gir. Anahtar yalnızca bu tarayıcıda saklanır, sunucuya her istekte güvenli başlıkla gönderilir.</p>
    <input id="token" type="password" placeholder="Yönetici anahtarı" onkeydown="if(event.key==='Enter')connect()">
    <button onclick="connect()">Bağlan</button>
  </div>
</div>

<!-- Panel -->
<div id="app" class="hide dashboard">
  <div class="backdrop" id="backdrop" onclick="toggleSidebar(false)"></div>
  <aside class="sidebar" id="sidebar">
    <div class="logo"><span class="d"></span> SELAYA</div>
    <div class="nav-section">İçerik</div>
    <div id="catNav"></div>
    <div class="nav-item" id="tabTextBtn" onclick="showTab('text')">📝 Metin İçerik</div>
    <div class="nav-section">Sistem</div>
    <div class="nav-item" id="tabNotifyBtn" onclick="showTab('notify')">🔔 Bildirimler</div>
    <div class="nav-item" id="tabStatsBtn" onclick="showTab('stats')">📊 Kullanım</div>
    <div class="nav-item" id="tabUsersBtn" onclick="showTab('users')">👤 Kullanıcılar</div>
    <div class="nav-item" id="tabDuaBtn" onclick="showTab('dua')">🤲 Dua Duvarı<span id="duaBadge" style="margin-left:auto;background:#e0556b;color:#fff;font-size:11px;font-weight:700;border-radius:999px;padding:1px 7px;display:none"></span></div>
    <div class="nav-item" id="tabHatimBtn" onclick="showTab('hatim')">📖 Topluluk Hatmi</div>
    <div class="nav-item" id="tabQuizBtn" onclick="showTab('quiz')">🎯 Bilgi Yarışması</div>
    <div class="nav-item" id="tabReportsBtn" onclick="showTab('reports')">🚩 Şikayetler<span id="reportsBadge" style="margin-left:auto;background:#e0556b;color:#fff;font-size:11px;font-weight:700;border-radius:999px;padding:1px 7px;display:none"></span></div>
    <div class="nav-item" onclick="logout()">🚪 Çıkış</div>
  </aside>
  <main class="main">
    <div class="topbar">
      <button class="hamb" onclick="toggleSidebar()">☰</button>
      <h1 id="pageTitle">İçerikler</h1>
      <button class="bellbtn" onclick="toggleActivity()" title="Bildirimler">🔔<span class="dot" id="actDot"></span></button>
      <div class="actPanel hide" id="actPanel"></div>
    </div>
    <div class="content">

    <!-- ============ İÇERİK ============ -->
    <div id="viewContent">
      <!-- Sesli Hikâye (yalnız "Sesli Hikâyeler" sekmesinde görünür) -->
      <div class="card hide" id="audioBuilder">
        <h3>🎧 Sesli Hikâye Oluştur</h3>
        <p class="hint">Kapak + başlık seç, altına bölümleri (ses + başlık + açıklama) ekle. Uygulamada tek "albüm" olur; çalarken kapak albüm kapağı olur.</p>
        <label>Kapak görseli</label>
        <input id="asCover" type="file" accept="image/*">
        <label>Başlık</label>
        <input id="asTitle" placeholder="Örn: Peygamber Kıssaları">
        <label>Açıklama (opsiyonel)</label>
        <input id="asSub" placeholder="Kısa açıklama">
        <label>Bölümler</label>
        <div id="asEpisodes"></div>
        <button class="ghost" type="button" onclick="addEpisodeRow()" style="margin-top:6px">+ Bölüm ekle</button>
        <div style="margin-top:14px"><button onclick="saveAudioStory()">Sesli Hikâyeyi Kaydet</button> <span id="asStatus" class="muted"></span></div>
      </div>

      <!-- Yükle (seçili kategoriye) -->
      <div class="card" id="uploadForm">
        <h3 id="uploadTitle">İçerik Ekle</h3>
        <p class="hint" id="collDesc" style="margin:2px 0 0"></p>
        <div id="catSelectWrap" style="display:none">
          <label>Kategori</label>
          <select id="upCollection" onchange="onCollectionChange()"></select>
        </div>
        <div id="titleWrap">
          <label>Başlık (opsiyonel)</label>
          <input id="upTitle" placeholder="Örn: Kâbe Gece">
        </div>
        <div id="descWrap">
          <label>Açıklama (opsiyonel)</label>
          <input id="upDesc" placeholder="Kısa açıklama / alt başlık">
        </div>
        <label>Dosya <span class="muted" id="fileHint"></span></label>
        <input id="upFile" type="file" accept="image/*,video/*,audio/*">
        <div id="coverWrap">
          <label>Kapak görseli (opsiyonel) <span class="muted">— ses/video için</span></label>
          <input id="upCover" type="file" accept="image/*">
        </div>
        <label>Sıra (küçük olan önce)</label>
        <input id="upSort" type="number" value="0">
        <div style="margin-top:14px"><button id="upBtn" onclick="upload()">Yükle</button> <span id="upStatus" class="muted"></span></div>
      </div>

      <div class="card">
        <div class="row" style="align-items:center">
          <h3 style="margin:0" id="listTitle">İçerikler</h3>
          <button class="ghost" style="flex:0 0 auto" onclick="loadItems()">Yenile</button>
        </div>
        <p class="hint"><b>Düzenle</b> başlık/açıklama · <b>Değiştir</b> dosya · <b>Gizle</b> uygulamadan kaldırır (silmez) · <b>Sil</b> tamamen kaldırır.</p>
        <input class="search" placeholder="🔍 İçerikte ara — başlık…" oninput="filterRows(this,'list')">
        <div id="list"></div>
      </div>
    </div>

    <!-- ============ BİLDİRİMLER ============ -->
    <div id="viewNotify" class="hide">
      <div class="card">
        <h3>Özel Bildirim Gönder</h3>
        <p class="hint">Tüm kullanıcılara bir duyuru/bildirim gönder. Uygulama açıldığında (ve arada bir kontrol ettiğinde) görünür. Başlık zorunlu; görsel ve bağlantı opsiyonel.</p>
        <label>Başlık</label>
        <input id="nTitle" placeholder="Örn: Regaib Kandiliniz mübarek olsun">
        <label>Metin (opsiyonel)</label>
        <textarea id="nBody" placeholder="Bildirim açıklaması..."></textarea>
        <label>Bağlantı / link (opsiyonel)</label>
        <input id="nLink" placeholder="https://...">
        <div style="margin-top:14px"><button onclick="sendNotify()">Bildirimi Gönder</button> <span id="nStatus" class="muted"></span></div>
      </div>

      <div class="card">
        <div class="row" style="align-items:center">
          <h3 style="margin:0">Gönderilen Bildirimler</h3>
          <button class="ghost" style="flex:0 0 auto" onclick="loadNotifications()">Yenile</button>
        </div>
        <input class="search" placeholder="🔍 Bildirimlerde ara…" oninput="filterRows(this,'nlist')">
        <div id="nlist"></div>
      </div>
    </div>

    <!-- ============ KULLANIM ============ -->
    <div id="viewStats" class="hide">
      <div class="card">
        <div class="row" style="align-items:center">
          <h3 style="margin:0">📊 Cloudflare Kullanımı</h3>
          <button class="ghost" style="flex:0 0 auto" onclick="loadStats()">Yenile</button>
        </div>
        <p class="hint">Free tier'da kalmak için depolama kullanımın. Asıl sınır: R2 (10 GB) ve D1 (5 GB) depolama. İstek/işlem limitleri bir uygulama için çok yüksek.</p>
        <div id="statsBody"><p class="muted">Yükleniyor…</p></div>
      </div>
    </div>

    <!-- ============ KULLANICILAR ============ -->
    <div id="viewUsers" class="hide">
      <div class="card">
        <h3 style="margin:0 0 4px">➕ Yeni Üye Ekle</h3>
        <p class="hint">Panelden elle üye oluştur. Kullanıcı bu e-posta + şifre ile uygulamada giriş yapabilir. <b>E-posta ve rumuz benzersiz olmalı</b> — kayıtlıysa engellenir.</p>
        <div class="row">
          <div><label>Ad</label><input id="cuName" placeholder="Ad"></div>
          <div><label>Soyad</label><input id="cuSurname" placeholder="Soyad (opsiyonel)"></div>
        </div>
        <div class="row">
          <div><label>E-posta</label><input id="cuEmail" type="email" placeholder="ornek@eposta.com"></div>
          <div><label>Şifre</label><input id="cuPass" placeholder="en az 6 karakter"></div>
        </div>
        <label>Rumuz (opsiyonel)</label><input id="cuRumuz" placeholder="Dua duvarında görünecek ad">
        <div style="margin-top:14px"><button onclick="createUser()">Üye Oluştur</button> <span id="cuStatus" class="muted"></span></div>
      </div>
      <div class="card">
        <div class="row" style="align-items:center">
          <h3 style="margin:0">👤 Üyeler</h3>
          <button class="ghost" style="flex:0 0 auto" onclick="loadUsers()">Yenile</button>
        </div>
        <p class="hint">Uygulamaya kaydolan kullanıcılar (rumuz <b>@</b> ile gösterilir). <b>✏️ Düzenle</b> ad/soyad/e-posta/rumuz değiştirir · <b>Şifre Sıfırla</b> yeni şifre belirler · <b>🚫 Banla</b> girişi engeller · <b>Sil</b> hesabı + verisini kalıcı kaldırır (KVKK).</p>
        <input class="search" placeholder="🔍 Üye ara — ad, e-posta veya rumuz…" oninput="filterRows(this,'usersBody')">
        <div id="usersBody"><p class="muted">Yükleniyor…</p></div>
      </div>
    </div>

    <!-- ============ DUA DUVARI ============ -->
    <div id="viewDua" class="hide">
      <div class="card">
        <h3 style="margin:0 0 4px">➕ Panelden Dua Ekle</h3>
        <p class="hint">Senin eklediğin dua doğrudan duvarda <b>yayınlanır</b> (onay beklemez). Rumuz, duada görünecek addır.</p>
        <div class="row">
          <div style="flex:0 0 200px"><label>Rumuz</label><input id="cdRumuz" placeholder="ör. Bir Kul"></div>
          <div><label>Âmin sayısı (opsiyonel)</label><input id="cdAmins" type="number" placeholder="0"></div>
        </div>
        <label>Dua metni</label><textarea id="cdText" placeholder="Dua / istek metni (en çok 280 karakter)"></textarea>
        <div style="margin-top:14px"><button onclick="createDua()">Duvara Ekle</button> <span id="cdStatus" class="muted"></span></div>
      </div>
      <div class="card">
        <div class="row" style="align-items:center">
          <h3 style="margin:0">🤲 Onay Bekleyen Dualar</h3>
          <button class="ghost" style="flex:0 0 auto" onclick="loadDuaWall()">Yenile</button>
        </div>
        <p class="hint">Üyelerin gönderdiği dualar burada onayını bekler. <b>Onayla</b> duayı duvarda yayınlar · <b>Reddet</b> gizler · <b>Sil</b> tamamen kaldırır. Apaçık küfür içerenler zaten otomatik engellenir; yine de son söz sende.</p>
        <div id="duaPendingBody"><p class="muted">Yükleniyor…</p></div>
      </div>
      <div class="card">
        <h3 style="margin:0 0 8px">📿 Yayındaki &amp; Kararlanan Dualar</h3>
        <p class="hint"><b>Gizle</b> duayı duvardan kaldırır (geri alınabilir — <b>Göster</b>) · <b>Sil</b> tamamen kaldırır · <b>🚫 Banla</b> yazarı engeller + tüm dualarını siler.</p>
        <input class="search" placeholder="🔍 Dualarda ara — rumuz veya metin…" oninput="filterRows(this,'duaRecentBody')">
        <div id="duaRecentBody"><p class="muted">—</p></div>
      </div>
    </div>

    <!-- ============ TOPLULUK HATMİ ============ -->
    <div id="viewHatim" class="hide">
      <div class="card">
        <h3 style="margin:0 0 4px">➕ Hatim Başlat</h3>
        <p class="hint">Resmî/niyetli bir topluluk hatmi başlat. 30 cüz açılır; üyeler uygulamadan alıp okur. (En az bir "Topluluk Hatmi" hep açıktır; biri tamamlanınca yenisi otomatik açılır.)</p>
        <div class="row">
          <div><label>Başlık</label><input id="htTitle" placeholder="Örn: Ramazan Hatmi"></div>
          <div><label>Niyet (opsiyonel)</label><input id="htIntent" placeholder="Örn: Merhumlarımız için"></div>
        </div>
        <div style="margin-top:14px"><button onclick="hatimCreate()">Hatim Başlat</button> <span id="htStatus" class="muted"></span></div>
      </div>
      <div class="card">
        <div class="row" style="align-items:center">
          <h3 style="margin:0">📖 Hatimler</h3>
          <button class="ghost" style="flex:0 0 auto" onclick="loadHatim()">Yenile</button>
        </div>
        <p class="hint">Her hatmin 30 cüzü — <b style="color:var(--gold)">altın</b>: boş · <b style="color:#e0a441">turuncu</b>: okunuyor · <b style="color:var(--ok)">yeşil</b>: okundu. Bir cüze tıkla → <b>okuyanın hesap bilgisi</b> + sıfırla. <b>Sil</b> hatmi kaldırır.</p>
        <div id="hatimBody"><p class="muted">Yükleniyor…</p></div>
      </div>
    </div>

    <!-- ============ BİLGİ YARIŞMASI (sıralama) ============ -->
    <div id="viewQuiz" class="hide">
      <div class="card">
        <div class="row" style="align-items:center">
          <h3 style="margin:0">🎯 Haftalık Sıralama</h3>
          <select id="quizWeek" onchange="loadQuizBoard(this.value)" style="flex:0 0 auto;min-width:150px"></select>
          <button class="ghost" style="flex:0 0 auto" onclick="loadQuizBoard()">Yenile</button>
        </div>
        <p class="hint">Bilgi Yarışması'nda her hafta (ISO hafta) kullanıcıların EN İYİ skorları. Skor = doğru×100 + hız bonusu. Madalyalar ilk üç sıradır.</p>
        <div id="quizBody"><p class="muted">Yükleniyor…</p></div>
      </div>
    </div>

    <!-- ============ İÇERİK ŞİKAYETLERİ ============ -->
    <div id="viewReports" class="hide">
      <div class="card">
        <div class="row" style="align-items:center">
          <h3 style="margin:0">🚩 İçerik Şikayetleri</h3>
          <button class="ghost" style="flex:0 0 auto" onclick="loadReports()">Yenile</button>
        </div>
        <p class="hint">Kullanıcıların "Bildir" ile şikayet ettiği içerikler (duvar kâğıdı/video/ses/ayet…). Aynı kişi bir içeriği yalnız bir kez sayar. İçeriği KALDIRMAK için ilgili kategoriden sil; buradaki "Temizle" sadece şikayet kaydını siler.</p>
        <div id="reportsBody"><p class="muted">Yükleniyor…</p></div>
      </div>
    </div>

    <!-- ============ METİN İÇERİK ============ -->
    <div id="viewText" class="hide">
      <div class="card">
        <h3>📝 Metin İçerik Ekle</h3>
        <p class="hint">Dosyasız metin: ayet/hadis/dua uygulamada İlham &amp; "Günün Ayeti/Hadisi" kartlarında; tebrik mesajları Tebrik Kartı şablonlarında görünür. Arka plan otomatik (duvar kâğıtlarından). İstediğin kadar ekle.</p>
        <label>Tür</label>
        <select id="txType">
          <option value="ayet">Ayet</option>
          <option value="hadis">Hadis</option>
          <option value="dua">Dua</option>
          <option value="cuma">Tebrik — Cuma Mesajı</option>
          <option value="bayram">Tebrik — Bayram</option>
          <option value="ramazan">Tebrik — Ramazan</option>
          <option value="kandil">Tebrik — Kandil</option>
          <option value="dogum">Tebrik — Doğum Günü</option>
          <option value="genel">Tebrik — Genel</option>
        </select>
        <label>Arapça (opsiyonel — ayet/hadis/dua için)</label>
        <textarea id="txArabic" placeholder="Arapça metin"></textarea>
        <label>Metin (Türkçe) *</label>
        <textarea id="txText" placeholder="Türkçe meal / mesaj"></textarea>
        <label>Kaynak (opsiyonel — ayet/hadis için)</label>
        <input id="txRef" placeholder="Örn: Bakara 255 · Buhârî">
        <div style="margin-top:14px"><button id="txBtn" onclick="saveText()">Ekle</button> <span id="txStatus" class="muted"></span></div>
      </div>
      <div class="card">
        <div class="row" style="align-items:center">
          <h3 style="margin:0">Eklenen Metinler</h3>
          <button class="ghost" style="flex:0 0 auto" onclick="loadText()">Yenile</button>
        </div>
        <div id="txTabs" class="txtabs"></div>
        <input id="txSearch" class="search" placeholder="🔍 Bu türde ara…" oninput="filterRows(this,'txList')">
        <div id="txList"></div>
      </div>
    </div>

    </div>
  </main>
</div>
<script>
  var TOKEN = localStorage.getItem('selaya_admin_token') || '';
  var CDN = '';
  var openCols = {};  // açık kalan kategori <details>'lerini hatırla (yeniden çizimde kapanmasın)
  // <details> toggle bubbling yapmaz → capture fazında dinle.
  document.addEventListener('toggle', function(e){
    var d = e.target;
    if (d && d.tagName === 'DETAILS' && d.dataset && d.dataset.col){ openCols[d.dataset.col] = d.open; }
  }, true);
  if (TOKEN) document.getElementById('token').value = TOKEN;

  var COLLS = [
    ['wallpapers', 'Duvar Kâğıtları', 'Galeri ekranındaki duvar kâğıtları.'],
    ['feed', 'Videolar (Reels)', 'Akış/keşfet video reel\\'leri.'],
    ['stories', 'Hikâyeler', 'Ana ekran hikâye şeridi kapakları.'],
    ['guide_abdest', 'Abdest Rehberi', 'Abdest adım görselleri.'],
    ['guide_namaz', 'Namaz Rehberi', 'Namaz adım görselleri.']
  ];
  var LABELS = {}; var DESCS = {};
  COLLS.forEach(function(c){ LABELS[c[0]] = c[1]; DESCS[c[0]] = c[2]; });
  // Builder ile yönetildiği için açılır menüde yok ama liste başlığında görünsün:
  LABELS['audio_stories'] = 'Sesli Hikâyeler';
  var CAT_ICONS = { wallpapers:'🖼️', feed:'🎬', inspiration:'✨', stories:'📖', greeting:'💌', bg_videos:'🎞️', guide_abdest:'🕌', guide_namaz:'🧎', audio_stories:'🎧' };
  var currentCat = 'wallpapers'; var ALL_ITEMS = []; var firstLoad = true;

  (function initSelect(){
    var sel = document.getElementById('upCollection');
    sel.innerHTML = COLLS.map(function(c){ return '<option value="' + c[0] + '">' + c[1] + '</option>'; }).join('');
    document.getElementById('catNav').innerHTML = COLLS.map(function(c){
      return '<div class="nav-item cat-nav" data-cat="' + c[0] + '" onclick="showCat(this.dataset.cat)">' + (CAT_ICONS[c[0]] || '📁') + ' ' + c[1] + '</div>';
    }).join('');
    onCollectionChange();
  })();

  function el(id){ return document.getElementById(id); }
  function val(id){ return el(id).value; }
  function toast(m){ var t=document.createElement('div'); t.className='toast'; t.textContent=m; document.body.appendChild(t); setTimeout(function(){ t.remove(); }, 2600); }
  function esc(s){ return String(s == null ? '' : s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }
  function fmtSize(b){ return b > 1048576 ? (b/1048576).toFixed(1)+' MB' : Math.round(b/1024)+' KB'; }
  // Genel istemci-tarafı arama: bir listedeki .item satırlarını metne göre süzer.
  function filterRows(input, containerId){
    var q=(input.value||'').trim().toLowerCase(); var c=el(containerId); if(!c) return;
    var items=c.querySelectorAll('.item'); var shown=0;
    for(var i=0;i<items.length;i++){ var ok=(!q||items[i].textContent.toLowerCase().indexOf(q)!==-1); items[i].style.display=ok?'':'none'; if(ok) shown++; }
    var nf=c.parentNode && c.parentNode.querySelector('.nofound');
    if(q && shown===0){ if(!nf){ nf=document.createElement('p'); nf.className='muted nofound'; c.parentNode.insertBefore(nf,c.nextSibling); } nf.textContent='"'+input.value.trim()+'" için sonuç yok.'; }
    else if(nf){ nf.remove(); }
  }

  // --- Şık modal popup'lar (Chrome'un native confirm/alert/prompt'u yerine) ---
  function _modal(inner){
    var ov=document.createElement('div'); ov.className='ovl';
    ov.innerHTML='<div class="modalbox">'+inner+'</div>';
    document.body.appendChild(ov);
    ov.addEventListener('click',function(e){ if(e.target===ov) ov.remove(); });
    return ov;
  }
  function uiConfirm(msg, onYes, opts){
    opts=opts||{};
    var ov=_modal('<h3>'+esc(opts.title||'Onay')+'</h3><p class="hint" style="white-space:pre-line;font-size:13.5px">'+esc(msg)+'</p><div class="row" style="margin-top:18px"><button class="ghost" data-x>Vazgeç</button><button class="'+(opts.danger?'danger':'')+'" data-y>'+esc(opts.yes||'Onayla')+'</button></div>');
    ov.querySelector('[data-x]').onclick=function(){ ov.remove(); };
    ov.querySelector('[data-y]').onclick=function(){ ov.remove(); if(onYes) onYes(); };
  }
  function uiAlert(msg, title){
    var ov=_modal('<h3>'+esc(title||'Bilgi')+'</h3><p class="hint" style="white-space:pre-line;font-size:13.5px">'+esc(msg)+'</p><div class="row" style="margin-top:18px"><button data-x>Tamam</button></div>');
    ov.querySelector('[data-x]').onclick=function(){ ov.remove(); };
  }
  function uiPrompt(msg, def, onSubmit, opts){
    opts=opts||{};
    var ov=_modal('<h3>'+esc(opts.title||'')+'</h3><p class="hint" style="font-size:13.5px">'+esc(msg)+'</p><input id="_pmtIn"><div class="row" style="margin-top:18px"><button class="ghost" data-x>Vazgeç</button><button data-y>'+esc(opts.yes||'Tamam')+'</button></div>');
    var inp=ov.querySelector('#_pmtIn'); inp.value=def||''; setTimeout(function(){ inp.focus(); },50);
    function go(){ var v=inp.value; ov.remove(); if(onSubmit) onSubmit(v); }
    inp.onkeydown=function(e){ if(e.key==='Enter') go(); };
    ov.querySelector('[data-x]').onclick=function(){ ov.remove(); };
    ov.querySelector('[data-y]').onclick=go;
  }

  function onCollectionChange(){
    var c = val('upCollection');
    el('collDesc').textContent = DESCS[c] || '';
    // Kapak alanı SADECE video kategorilerinde görünür (ses/video için önizleme).
    // Görsel kategorilerinde (duvar kâğıdı, sticker, rehber…) gizlenir + temizlenir
    // → kullanıcı yanlışlıkla aynı resmi kapağa koyup iki kez yüklemesin.
    // Manuel kapak alanı kaldırıldı: videolarda kapak ilk kareden OTOMATİK alınır,
    // görsellerde gerekmez. Bu yüzden her zaman gizli.
    el('coverWrap').style.display = 'none';
    el('upCover').value = '';
    var isVideo = (c === 'feed' || c === 'bg_videos');
    el('fileHint').textContent = isVideo ? '(video seç — kapak ilk kareden otomatik · en fazla 4 MB)' : '';
    // Açıklama: Reels videolarda CAPTION (SELAYA altında görünür) → gösterilir.
    // bg_videos + saf görsel galerilerinde gerekmez.
    var noDesc = (c === 'bg_videos' || c === 'wallpapers' || c === 'stickers' || c === 'radio_art');
    el('descWrap').style.display = noDesc ? 'none' : 'block';
    if (noDesc) el('upDesc').value = '';
    // Arka plan videoları: hiçbir şeye gerek yok, sadece dosya → başlık da gizli.
    var noTitle = (c === 'bg_videos');
    el('titleWrap').style.display = noTitle ? 'none' : 'block';
    if (noTitle) el('upTitle').value = '';
  }

  var TAB_TITLES = { text:'Metin İçerik', notify:'Bildirimler', stats:'Kullanım', users:'Kullanıcılar', dua:'Dua Duvarı', hatim:'Topluluk Hatmi', quiz:'Bilgi Yarışması', reports:'İçerik Şikayetleri' };
  function setActiveNav(node){
    document.querySelectorAll('.nav-item').forEach(function(n){ n.classList.remove('active'); });
    if (node) node.classList.add('active');
  }
  function catLabel(col){ return LABELS[col] || col; }
  // Her içerik kategorisi kendi sekmesi → o kategorinin yükleme formu + listesi.
  function showCat(col){
    currentCat = col;
    el('viewContent').classList.remove('hide');
    ['viewNotify','viewStats','viewText'].forEach(function(v){ var e = el(v); if (e) e.classList.add('hide'); });
    setActiveNav(document.querySelector('.cat-nav[data-cat="' + col + '"]'));
    el('pageTitle').textContent = catLabel(col);
    var isAudio = (col === 'audio_stories');
    el('audioBuilder').classList.toggle('hide', !isAudio);
    el('uploadForm').classList.toggle('hide', isAudio);
    if (!isAudio){
      var sel = el('upCollection'); if (sel) sel.value = col;
      onCollectionChange();
      el('uploadTitle').textContent = catLabel(col) + ' ekle';
    }
    renderCat();
    toggleSidebar(false);
  }
  function showTab(t){
    el('viewContent').classList.add('hide');
    el('viewNotify').classList.toggle('hide', t !== 'notify');
    el('viewStats').classList.toggle('hide', t !== 'stats');
    el('viewText').classList.toggle('hide', t !== 'text');
    el('viewUsers').classList.toggle('hide', t !== 'users');
    el('viewDua').classList.toggle('hide', t !== 'dua');
    el('viewHatim').classList.toggle('hide', t !== 'hatim');
    el('viewQuiz').classList.toggle('hide', t !== 'quiz');
    el('viewReports').classList.toggle('hide', t !== 'reports');
    setActiveNav(el('tab' + t.charAt(0).toUpperCase() + t.slice(1) + 'Btn'));
    var pt = el('pageTitle'); if (pt) pt.textContent = TAB_TITLES[t] || '';
    toggleSidebar(false);
    if (t === 'notify') loadNotifications();
    if (t === 'stats') loadStats();
    if (t === 'text') loadText();
    if (t === 'users') loadUsers();
    if (t === 'dua') loadDuaWall();
    if (t === 'hatim') loadHatim();
    if (t === 'quiz') loadQuizBoard();
    if (t === 'reports') loadReports();
  }
  function toggleSidebar(open){
    var sb = el('sidebar'); if (!sb) return;
    var willOpen = (open === undefined) ? !sb.classList.contains('open') : open;
    sb.classList.toggle('open', willOpen);
    var bd = el('backdrop'); if (bd) bd.classList.toggle('show', willOpen);
  }
  function logout(){ localStorage.removeItem('selaya_admin_token'); location.reload(); }

  // --- Metin içerik (ayet/hadis/dua/tebrik — dosyasız) ---
  // Dua artık KENDİ 'duas' koleksiyonuna yazılır (eskiden 'inspiration'a
  // type=dua düşüyordu → Günün İlhamı / Dualar karışıklığı). Eski kayıtlar
  // txMatch'te ayrıca eşlenir, uygulama da ikisini birden okur.
  var TXMAP = {
    ayet: ['inspiration', 'verse'], hadis: ['hadiths', 'hadith'], dua: ['duas', 'dua'],
    cuma: ['greeting_msg', 'friday'], bayram: ['greeting_msg', 'bayram'], ramazan: ['greeting_msg', 'ramazan'],
    kandil: ['greeting_msg', 'kandil'], dogum: ['greeting_msg', 'birthday'], genel: ['greeting_msg', 'general']
  };
  function saveText(){
    var m = TXMAP[val('txType')]; if (!m) return;
    var coll = m[0], sub = m[1];
    var text = val('txText').trim();
    if (!text){ toast('Metin gerekli'); return; }
    var extra = coll === 'greeting_msg'
      ? { occasion: sub }
      : { type: sub, arabic: val('txArabic'), reference: val('txRef') };
    var btn = el('txBtn'); if (btn) btn.disabled = true;
    var fd = new FormData();
    fd.append('collection', coll);
    fd.append('title', text);
    fd.append('subtitle', coll === 'greeting_msg' ? '' : val('txRef'));
    fd.append('extra', JSON.stringify(extra));
    api('text', { method: 'POST', body: fd }).then(function(res){
      if (btn) btn.disabled = false;
      if (res.j && res.j.ok){
        el('txStatus').innerHTML = '<span class="ok">Eklendi ✓</span>';
        el('txArabic').value = ''; el('txText').value = ''; el('txRef').value = '';
        loadText();
      } else { el('txStatus').textContent = 'Hata: ' + ((res.j && res.j.error) || res.status); }
    }).catch(function(e){ if (btn) btn.disabled = false; el('txStatus').textContent = 'Hata: ' + e; });
  }
  var TX_TABS = [['ayet','Ayet'],['hadis','Hadis'],['dua','Dua'],['cuma','Cuma'],['bayram','Bayram'],['ramazan','Ramazan'],['kandil','Kandil'],['dogum','Doğum'],['genel','Genel']];
  var currentTxType = 'ayet';
  function txMatch(x, type){
    if (x.kind !== 'text') return false;
    var ex = {}; try { ex = JSON.parse(x.extra || '{}'); } catch (e) {}
    // Dua: yeni 'duas' koleksiyonu + ESKİ 'inspiration'+type=dua kayıtları.
    if (type === 'dua'){
      return (x.collection === 'duas' && ex.type === 'dua') ||
             (x.collection === 'inspiration' && ex.type === 'dua');
    }
    var m = TXMAP[type]; if (!m || x.collection !== m[0]) return false;
    return m[0] === 'greeting_msg' ? (ex.occasion === m[1]) : (ex.type === m[1]);
  }
  function showTxTab(type){ currentTxType = type; var s=el('txSearch'); if(s) s.value=''; renderTxTabs(); renderTxList(); }
  function renderTxTabs(){
    var h = '';
    TX_TABS.forEach(function(t){
      if (t[0] === 'ayet') h += '<span class="txgroup">📖 İçerik — Ayet · Hadis · Dua (uygulama bölümlerine gider)</span>';
      if (t[0] === 'cuma') h += '<span class="txgroup">💌 Tebrik Kartları</span>';
      var n = ALL_ITEMS.filter(function(x){ return txMatch(x, t[0]); }).length;
      h += '<div class="txtab' + (t[0] === currentTxType ? ' active' : '') + '" data-tx="' + t[0] + '" onclick="showTxTab(this.dataset.tx)">' + t[1] + ' <span class="txcnt">' + n + '</span></div>';
    });
    el('txTabs').innerHTML = h;
  }
  function renderTxList(){
    var items = ALL_ITEMS.filter(function(x){ return txMatch(x, currentTxType); });
    var h = items.map(function(it){
      var ex = {}; try { ex = JSON.parse(it.extra || '{}'); } catch (e) {}
      var ref = ex.reference || ex.occasion || '';
      return '<div class="item" draggable="true" data-id="' + esc(it.id) + '"><span class="grip" title="Sürükle">⠿</span><div class="ph">📝</div><div class="meta"><b>' + esc((it.title || '').slice(0, 80)) + '</b>' + (ref ? '<span class="muted">' + esc(ref) + '</span>' : '') + '</div>' +
        '<button class="ghost" data-id="' + esc(it.id) + '" onclick="editText(this.dataset.id)">✏️ Düzenle</button> ' +
        '<button class="danger" data-id="' + esc(it.id) + '" onclick="delText(this.dataset.id)">Sil</button></div>';
    }).join('');
    el('txList').innerHTML = h || '<p class="muted">Bu türde henüz metin yok. Yukarıdan ekleyebilirsin.</p>';
  }
  function loadText(){
    api('items').then(function(res){
      ALL_ITEMS = res.j.items || [];
      renderTxTabs();
      renderTxList();
    }).catch(function(e){ toast('Hata: ' + e); });
  }
  function delText(id){
    uiConfirm('Bu metni silmek istediğine emin misin?', function(){
      api('items/' + encodeURIComponent(id), { method: 'DELETE' }).then(function(){ loadText(); });
    }, {danger:true, yes:'Sil'});
  }
  // Metni düzenle: Türkçe metin + (ayet/hadis/dua için) Arapça & kaynak.
  function editText(id){
    var it=null; for(var k=0;k<ALL_ITEMS.length;k++){ if(ALL_ITEMS[k].id===id){ it=ALL_ITEMS[k]; break; } }
    if(!it) return;
    var ex={}; try{ ex=JSON.parse(it.extra||'{}'); }catch(e){}
    var isGreeting=(it.collection==='greeting_msg');
    var ov=document.createElement('div');
    ov.style.cssText='position:fixed;inset:0;background:rgba(16,24,40,.45);display:flex;align-items:center;justify-content:center;z-index:50;padding:20px';
    ov.innerHTML='<div style="background:#fff;border-radius:18px;padding:22px;max-width:430px;width:100%;box-shadow:0 14px 44px rgba(0,0,0,.22);max-height:90vh;overflow:auto">'+
      '<h3 style="margin:0 0 12px">✏️ Metni Düzenle</h3>'+
      (isGreeting?'':'<label>Arapça (opsiyonel)</label><textarea id="etArabic"></textarea>')+
      '<label>Metin (Türkçe)</label><textarea id="etText"></textarea>'+
      (isGreeting?'':'<label>Kaynak (opsiyonel)</label><input id="etRef">')+
      '<div class="row" style="margin-top:18px"><button class="ghost" id="etCancel">Vazgeç</button><button id="etSave">Kaydet</button></div>'+
      '</div>';
    document.body.appendChild(ov);
    if(!isGreeting){ ov.querySelector('#etArabic').value=ex.arabic||''; ov.querySelector('#etRef').value=ex.reference||''; }
    ov.querySelector('#etText').value=it.title||'';
    function close(){ ov.remove(); }
    ov.addEventListener('click',function(e){ if(e.target===ov) close(); });
    ov.querySelector('#etCancel').onclick=close;
    ov.querySelector('#etSave').onclick=function(){
      var text=ov.querySelector('#etText').value.trim();
      if(!text){ toast('Metin gerekli'); return; }
      var ref=isGreeting?'':ov.querySelector('#etRef').value;
      var newExtra=isGreeting?{ occasion:ex.occasion }
        :{ type:ex.type, arabic:ov.querySelector('#etArabic').value, reference:ref };
      api('items/'+encodeURIComponent(id),{ method:'PUT', headers:{'Content-Type':'application/json'},
        body: JSON.stringify({ collection:it.collection, kind:'text', title:text, subtitle:ref, sort:it.sort||0, active:it.active?1:0, extra:newExtra }) })
      .then(function(res){ if(res.j&&res.j.ok){ toast('Güncellendi ✓'); close(); loadText(); } else { toast('Hata: '+((res.j&&res.j.error)||res.status)); } })
      .catch(function(e){ toast('Hata: '+e); });
    };
  }

  // --- Kullanıcılar (üyeler) ---
  function fmtDate(ms){ if(!ms) return '—'; try{ var d=new Date(ms); return d.toLocaleDateString('tr-TR')+' '+d.toLocaleTimeString('tr-TR',{hour:'2-digit',minute:'2-digit'}); }catch(e){ return '—'; } }
  // --- Panelden üye / dua ekleme ---
  function createUser(){
    var name=el('cuName').value.trim(), sur=el('cuSurname').value.trim();
    var email=el('cuEmail').value.trim(), pass=el('cuPass').value, rumuz=el('cuRumuz').value.trim();
    if(!name||!email||pass.length<6){ toast('Ad, e-posta ve en az 6 karakter şifre gerekli'); return; }
    el('cuStatus').textContent='Ekleniyor…';
    var fd=new FormData();
    fd.append('name',name); fd.append('surname',sur); fd.append('email',email);
    fd.append('password',pass); fd.append('rumuz',rumuz);
    api('user-create',{method:'POST',body:fd}).then(function(res){
      el('cuStatus').textContent='';
      if(res.j&&res.j.ok){
        toast('Üye oluşturuldu ✓');
        el('cuName').value=''; el('cuSurname').value=''; el('cuEmail').value=''; el('cuPass').value=''; el('cuRumuz').value='';
        loadUsers();
      } else { var er=(res.j&&res.j.error)||res.status; var mm={email_taken:'Bu e-posta zaten kayıtlı',rumuz_taken:'Bu rumuz zaten kullanılıyor',invalid_email:'Geçersiz e-posta',weak_password:'Şifre en az 6 karakter olmalı',name_required:'Ad zorunlu'}; toast('Hata: '+(mm[er]||er)); }
    }).catch(function(e){ el('cuStatus').textContent=''; toast('Hata: '+e); });
  }
  function createDua(){
    var rumuz=el('cdRumuz').value.trim(), text=el('cdText').value.trim();
    var amins=parseInt(el('cdAmins').value,10); if(isNaN(amins)||amins<0) amins=0;
    if(!rumuz){ toast('Rumuz gerekli'); return; }
    if(text.length<3){ toast('Dua metni çok kısa'); return; }
    if(text.length>280){ toast('En çok 280 karakter olmalı'); return; }
    el('cdStatus').textContent='Ekleniyor…';
    var fd=new FormData(); fd.append('rumuz',rumuz); fd.append('text',text); fd.append('amins',amins);
    api('dua-create',{method:'POST',body:fd}).then(function(res){
      el('cdStatus').textContent='';
      if(res.j&&res.j.ok){
        toast('Dua duvara eklendi ✓');
        el('cdRumuz').value=''; el('cdText').value=''; el('cdAmins').value='';
        loadDuaWall();
      } else { toast('Hata: '+((res.j&&res.j.error)||res.status)); }
    }).catch(function(e){ el('cdStatus').textContent=''; toast('Hata: '+e); });
  }
  function loadUsers(){
    el('usersBody').innerHTML='<p class="muted">Yükleniyor…</p>';
    api('users').then(function(res){
      var us=(res.j&&res.j.users)||[];
      if(!us.length){ el('usersBody').innerHTML='<p class="muted">Henüz kayıtlı kullanıcı yok.</p>'; return; }
      var h='<p class="muted" style="margin:0 0 8px">Toplam: <b>'+us.length+'</b> üye</p>';
      h+=us.map(function(u){
        var name=esc(((u.name||'')+' '+(u.surname||'')).trim()||'—');
        var em=esc(u.email||''); var id=esc(u.id);
        var banned=!!u.banned;
        var ban=banned
          ? '<span style="background:#e0556b;color:#fff;font-size:11px;font-weight:700;border-radius:6px;padding:1px 7px;margin-left:6px">BANLI</span>'
          : '';
        var rumuz=u.rumuz?' · <b style="color:var(--gold)">@'+esc(u.rumuz)+'</b>':' · <span style="color:var(--danger)">rumuz yok</span>';
        var banBtn=banned
          ? '<button class="ghost" data-id="'+id+'" data-email="'+em+'" onclick="unbanUser(this.dataset.id,this.dataset.email)">✓ Yasağı Kaldır</button>'
          : '<button class="danger" data-id="'+id+'" data-email="'+em+'" onclick="banUser(this.dataset.id,this.dataset.email)">🚫 Banla</button>';
        var edit='<button class="ghost" style="flex:0 0 auto" data-id="'+id+'" data-name="'+esc(u.name||'')+'" data-surname="'+esc(u.surname||'')+'" data-email="'+em+'" data-rumuz="'+esc(u.rumuz||'')+'" onclick="editUser(this.dataset.id,this.dataset.name,this.dataset.surname,this.dataset.email,this.dataset.rumuz)">✏️ Düzenle</button>';
        return '<div class="item"'+(banned?' style="opacity:.7"':'')+'><div class="ph">'+(banned?'🚫':'👤')+'</div><div class="meta"><b>'+name+ban+'</b><span class="muted">'+em+rumuz+'</span><span class="muted">Kayıt: '+fmtDate(u.created_at)+' · Son aktif: '+fmtDate(u.last_active)+(u.device?' · '+esc(u.device):'')+'</span></div>'+
          edit+' '+banBtn+' '+
          '<button class="ghost" style="flex:0 0 auto" data-id="'+id+'" data-email="'+em+'" onclick="resetUserPw(this.dataset.id,this.dataset.email)">Şifre Sıfırla</button> '+
          '<button class="danger" data-id="'+id+'" data-email="'+em+'" onclick="deleteUser(this.dataset.id,this.dataset.email)">Sil</button></div>';
      }).join('');
      el('usersBody').innerHTML=h;
    }).catch(function(e){ el('usersBody').innerHTML='<p class="muted">Hata: '+e+'</p>'; });
  }
  // Üyeyi düzenle: ad/soyad/e-posta/rumuz için modal. Değerler .value ile
  // atanır (HTML'e gömülmez) → tırnak/özel karakter güvenli.
  function editUser(id,name,surname,email,rumuz){
    var ov=document.createElement('div');
    ov.style.cssText='position:fixed;inset:0;background:rgba(16,24,40,.45);display:flex;align-items:center;justify-content:center;z-index:50;padding:20px';
    ov.innerHTML='<div style="background:#fff;border-radius:18px;padding:22px;max-width:380px;width:100%;box-shadow:0 14px 44px rgba(0,0,0,.22)">'+
      '<h3 style="margin:0 0 12px">✏️ Üyeyi Düzenle</h3>'+
      '<label>Ad</label><input id="euName">'+
      '<label>Soyad</label><input id="euSurname">'+
      '<label>E-posta</label><input id="euEmail" type="email">'+
      '<label>Rumuz</label><input id="euRumuz" placeholder="(boş bırakılabilir)">'+
      '<div class="row" style="margin-top:18px"><button class="ghost" id="euCancel">Vazgeç</button><button id="euSave">Kaydet</button></div>'+
      '</div>';
    document.body.appendChild(ov);
    ov.querySelector('#euName').value=name||'';
    ov.querySelector('#euSurname').value=surname||'';
    ov.querySelector('#euEmail').value=email||'';
    ov.querySelector('#euRumuz').value=rumuz||'';
    function close(){ ov.remove(); }
    ov.addEventListener('click',function(e){ if(e.target===ov) close(); });
    ov.querySelector('#euCancel').onclick=close;
    ov.querySelector('#euSave').onclick=function(){
      var fd=new FormData(); fd.append('id',id);
      fd.append('name',ov.querySelector('#euName').value.trim());
      fd.append('surname',ov.querySelector('#euSurname').value.trim());
      fd.append('email',ov.querySelector('#euEmail').value.trim());
      fd.append('rumuz',ov.querySelector('#euRumuz').value.trim());
      api('user-update',{method:'POST',body:fd}).then(function(res){
        if(res.j&&res.j.ok){ toast('Güncellendi ✓'); close(); loadUsers(); }
        else { var er=(res.j&&res.j.error)||res.status; var mm={email_taken:'Bu e-posta başka bir üyede kayıtlı',rumuz_taken:'Bu rumuz başka bir üyede kayıtlı',invalid_email:'Geçersiz e-posta',name_required:'Ad zorunlu'}; toast('Hata: '+(mm[er]||er)); }
      }).catch(function(e){ toast('Hata: '+e); });
    };
  }
  function resetUserPw(id,email){
    uiPrompt('"'+email+'" için yeni şifre (en az 6 karakter):', '', function(np){
      if(np===null) return;
      if(np.length<6){ toast('Şifre en az 6 karakter olmalı'); return; }
      var fd=new FormData(); fd.append('id',id); fd.append('password',np);
      api('user-reset-password',{method:'POST',body:fd}).then(function(res){
        if(res.j&&res.j.ok){ try{ if(navigator.clipboard) navigator.clipboard.writeText(np); }catch(e){} uiAlert('Yeni şifre panoya kopyalandı.\\n\\nKullanıcıya ilet:\\n'+email+'\\nYeni şifre: '+np, 'Şifre Sıfırlandı ✓'); }
        else { toast('Hata: '+((res.j&&res.j.error)||res.status)); }
      }).catch(function(e){ toast('Hata: '+e); });
    }, {title:'Şifre Sıfırla', yes:'Sıfırla'});
  }
  function deleteUser(id,email){
    uiConfirm('"'+email+'" hesabını ve TÜM verisini kalıcı silmek istediğine emin misin? (KVKK)', function(){
      var fd=new FormData(); fd.append('id',id);
      api('user-delete',{method:'POST',body:fd}).then(function(res){
        if(res.j&&res.j.ok){ toast('Silindi ✓'); loadUsers(); }
        else { toast('Hata: '+((res.j&&res.j.error)||res.status)); }
      }).catch(function(e){ toast('Hata: '+e); });
    }, {danger:true, yes:'Hesabı Sil', title:'Üyeyi Sil'});
  }

  // --- Dua Duvarı moderasyonu (#10) ---
  var DUA_ALL=[];
  // Yazarın hesap bilgisi + kayıtlı rumuz uyumu (sahte/uyumsuz rumuz yakalanır).
  function duaAuthorLine(d){
    if(d.user_id==='panel-author') return '<span class="muted">🛠️ panelden eklendi</span>';
    if(!d.author_email) return '<span class="muted" style="color:var(--danger)">⚠️ kullanıcı bulunamadı (silinmiş hesap)</span>';
    var nm=((d.author_name||'')+' '+(d.author_surname||'')).trim()||'—';
    var ar=(d.author_rumuz||'').trim();
    var mism=ar && ((d.rumuz||'').toLowerCase()!==ar.toLowerCase());
    var rn=ar ? (mism?' · <span style="color:var(--danger)">kayıtlı rumuz: @'+esc(ar)+' ⚠️</span>':' · <span class="ok">@'+esc(ar)+' ✓</span>') : ' · <span style="color:var(--danger)">rumuz yok</span>';
    return '<span class="muted">👤 '+esc(nm)+' · '+esc(d.author_email)+rn+(d.author_banned?' · <b style="color:var(--danger)">BANLI</b>':'')+'</span>';
  }
  // Duayı düzenle (rumuz / metin).
  function editDua(id){
    var d=null; for(var k=0;k<DUA_ALL.length;k++){ if(DUA_ALL[k].id===id){ d=DUA_ALL[k]; break; } }
    if(!d) return;
    var ov=document.createElement('div');
    ov.style.cssText='position:fixed;inset:0;background:rgba(16,24,40,.45);display:flex;align-items:center;justify-content:center;z-index:50;padding:20px';
    ov.innerHTML='<div style="background:#fff;border-radius:18px;padding:22px;max-width:420px;width:100%;box-shadow:0 14px 44px rgba(0,0,0,.22)">'+
      '<h3 style="margin:0 0 12px">✏️ Duayı Düzenle</h3>'+
      '<label>Rumuz</label><input id="edRumuz">'+
      '<label>Dua metni (en çok 280)</label><textarea id="edText"></textarea>'+
      '<div class="row" style="margin-top:18px"><button class="ghost" id="edCancel">Vazgeç</button><button id="edSave">Kaydet</button></div>'+
      '</div>';
    document.body.appendChild(ov);
    ov.querySelector('#edRumuz').value=d.rumuz||'';
    ov.querySelector('#edText').value=d.text||'';
    function close(){ ov.remove(); }
    ov.addEventListener('click',function(e){ if(e.target===ov) close(); });
    ov.querySelector('#edCancel').onclick=close;
    ov.querySelector('#edSave').onclick=function(){
      var fd=new FormData(); fd.append('id',id);
      fd.append('rumuz',ov.querySelector('#edRumuz').value.trim());
      fd.append('text',ov.querySelector('#edText').value.trim());
      api('dua-update',{method:'POST',body:fd}).then(function(res){
        if(res.j&&res.j.ok){ toast('Güncellendi ✓'); close(); loadDuaWall(); }
        else { var er=(res.j&&res.j.error)||res.status; var mm={rumuz_required:'Rumuz gerekli',too_short:'Metin çok kısa',too_long:'En çok 280 karakter olmalı'}; toast('Hata: '+(mm[er]||er)); }
      }).catch(function(e){ toast('Hata: '+e); });
    };
  }
  // Duaya tıklayınca yazarın tam hesap bilgileri (moderasyon görünümü).
  function showDuaAuthor(id){
    var d=null; for(var k=0;k<DUA_ALL.length;k++){ if(DUA_ALL[k].id===id){ d=DUA_ALL[k]; break; } }
    if(!d) return;
    var uid=d.user_id||'';
    var mine=DUA_ALL.filter(function(x){ return (x.user_id||'')===uid; });
    function row(k,v){ return '<div style="display:flex;justify-content:space-between;gap:14px;padding:8px 0;border-top:1px solid var(--line)"><span class="muted">'+k+'</span><span style="text-align:right;word-break:break-word;font-weight:600">'+v+'</span></div>'; }
    var body, showBan=false, showUnban=false;
    if(uid==='panel-author'){ body='<p class="hint">🛠️ Bu dua panelden eklendi — gerçek bir kullanıcı hesabı yok.</p>'; }
    else if(!d.author_email){ body='<p class="hint" style="color:var(--danger)">⚠️ Kullanıcı bulunamadı — hesap silinmiş olabilir.</p>'; }
    else {
      var full=((d.author_name||'')+' '+(d.author_surname||'')).trim()||'—';
      var ar=(d.author_rumuz||'').trim();
      var mism=ar && (d.rumuz||'').toLowerCase()!==ar.toLowerCase();
      var rr='';
      rr+=row('Ad Soyad', esc(full));
      rr+=row('E-posta', esc(d.author_email));
      rr+=row('Kayıtlı rumuz', ar ? ('@'+esc(ar)+(mism?' <span style="color:var(--danger)">⚠️ duadaki @'+esc(d.rumuz)+' ile farklı</span>':' <span class="ok">✓ uyumlu</span>')) : '<span style="color:var(--danger)">yok</span>');
      rr+=row('E-posta doğrulandı', d.author_verified ? '<span class="ok">evet</span>' : 'hayır');
      rr+=row('Durum', d.author_banned ? '<span style="color:var(--danger)">🚫 BANLI'+(d.author_ban_reason?' — '+esc(d.author_ban_reason):'')+'</span>' : '<span class="ok">aktif</span>');
      rr+=row('Kayıt tarihi', fmtDate(d.author_created));
      rr+=row('Son aktif', fmtDate(d.author_last));
      if(d.author_device) rr+=row('Cihaz', esc(d.author_device));
      rr+=row('Bu listedeki duası', mine.length+' adet');
      body='<div>'+rr+'</div>';
      if(d.author_banned) showUnban=true; else showBan=true;
    }
    var act='<div class="row" style="margin-top:18px">';
    if(showBan) act+='<button class="danger" id="daBan">🚫 Banla (+ dualarını sil)</button>';
    if(showUnban) act+='<button class="ghost" id="daUnban">✓ Yasağı Kaldır</button>';
    act+='<button class="ghost" id="daClose">Kapat</button></div>';
    var ov=document.createElement('div');
    ov.style.cssText='position:fixed;inset:0;background:rgba(16,24,40,.45);display:flex;align-items:center;justify-content:center;z-index:50;padding:20px';
    ov.innerHTML='<div style="background:#fff;border-radius:18px;padding:22px;max-width:430px;width:100%;box-shadow:0 14px 44px rgba(0,0,0,.22);max-height:90vh;overflow:auto">'+
      '<h3 style="margin:0 0 10px">👤 Kullanıcı Bilgileri</h3>'+body+act+'</div>';
    document.body.appendChild(ov);
    function close(){ ov.remove(); }
    ov.addEventListener('click',function(e){ if(e.target===ov) close(); });
    var c1=ov.querySelector('#daClose'); if(c1) c1.onclick=close;
    var bb=ov.querySelector('#daBan'); if(bb) bb.onclick=function(){ close(); banDuaUser(uid, id); };
    var bu=ov.querySelector('#daUnban'); if(bu) bu.onclick=function(){ close(); unbanUser(uid, d.author_email||''); };
  }
  function loadDuaWall(){
    el('duaPendingBody').innerHTML='<p class="muted">Yükleniyor…</p>';
    api('dua-pending').then(function(res){
      var pend=(res.j&&res.j.pending)||[]; var rec=(res.j&&res.j.recent)||[];
      DUA_ALL=pend.concat(rec);
      var badge=el('duaBadge');
      if(badge){ if(pend.length){ badge.style.display='inline-block'; badge.textContent=pend.length; } else { badge.style.display='none'; } }
      if(!pend.length){ el('duaPendingBody').innerHTML='<p class="muted">Onay bekleyen dua yok. 🎉</p>'; }
      else {
        el('duaPendingBody').innerHTML='<p class="muted" style="margin:0 0 8px">Bekleyen: <b>'+pend.length+'</b></p>'+pend.map(function(d){
          var id=esc(d.id); var uid=esc(d.user_id||'');
          return '<div class="item"><div class="ph">🤲</div><div class="meta" data-aid="'+id+'" style="cursor:pointer" title="Kullanıcı bilgilerini gör" onclick="showDuaAuthor(this.dataset.aid)"><b>'+esc(d.rumuz)+'</b><span>'+esc(d.text)+'</span>'+duaAuthorLine(d)+'<span class="muted">'+fmtDate(d.created_at)+' · ℹ️ tıkla</span></div>'+
            '<button class="ghost" title="Düzenle" data-id="'+id+'" onclick="editDua(this.dataset.id)">✏️</button> '+
            '<button data-id="'+id+'" onclick="approveDua(this.dataset.id)">Onayla</button> '+
            '<button class="ghost" data-id="'+id+'" onclick="rejectDua(this.dataset.id,false)">Reddet</button> '+
            '<button class="danger" data-id="'+id+'" onclick="rejectDua(this.dataset.id,true)">Sil</button> '+
            '<button class="danger" data-uid="'+uid+'" data-id="'+id+'" onclick="banDuaUser(this.dataset.uid,this.dataset.id)">🚫 Banla</button></div>';
        }).join('');
      }
      el('duaRecentBody').innerHTML = rec.length ? rec.map(function(d){
        var id=esc(d.id); var uid=esc(d.user_id||'');
        var icon,label,actions;
        if(d.status==='approved'){
          icon='✅'; label='<span class="ok">yayında</span>';
          actions='<button class="ghost" data-id="'+id+'" onclick="hideDua(this.dataset.id,true)">Gizle</button> ';
        } else if(d.status==='hidden'){
          icon='🙈'; label='<span class="muted">gizli</span>';
          actions='<button data-id="'+id+'" onclick="hideDua(this.dataset.id,false)">Göster</button> ';
        } else {
          icon='🚫'; label='<span class="muted">reddedildi</span>'; actions='';
        }
        return '<div class="item"><div class="ph">'+icon+'</div><div class="meta" data-aid="'+id+'" style="cursor:pointer" title="Kullanıcı bilgilerini gör" onclick="showDuaAuthor(this.dataset.aid)"><b>'+esc(d.rumuz)+'</b> '+label+'<span class="muted">'+esc(d.text)+' · ℹ️ tıkla</span>'+duaAuthorLine(d)+'</div>'+
          '<button class="ghost" title="Düzenle" data-id="'+id+'" onclick="editDua(this.dataset.id)">✏️</button> '+
          actions+
          '<button class="danger" data-id="'+id+'" onclick="rejectDua(this.dataset.id,true)">Sil</button> '+
          '<button class="danger" data-uid="'+uid+'" data-id="'+id+'" onclick="banDuaUser(this.dataset.uid,this.dataset.id)">🚫 Banla</button></div>';
      }).join('') : '<p class="muted">—</p>';
    }).catch(function(e){ el('duaPendingBody').innerHTML='<p class="muted">Hata: '+e+'</p>'; });
  }
  function approveDua(id){
    var fd=new FormData(); fd.append('id',id);
    api('dua-approve',{method:'POST',body:fd}).then(function(res){
      if(res.j&&res.j.ok){ toast('Onaylandı ✓'); loadDuaWall(); }
      else { toast('Hata: '+((res.j&&res.j.error)||res.status)); }
    }).catch(function(e){ toast('Hata: '+e); });
  }
  function rejectDua(id,del){
    function doIt(){
      var fd=new FormData(); fd.append('id',id); if(del) fd.append('delete','1');
      api('dua-reject',{method:'POST',body:fd}).then(function(res){
        if(res.j&&res.j.ok){ toast(del?'Silindi ✓':'Reddedildi ✓'); loadDuaWall(); }
        else { toast('Hata: '+((res.j&&res.j.error)||res.status)); }
      }).catch(function(e){ toast('Hata: '+e); });
    }
    if(del){ uiConfirm('Bu duayı tamamen silmek istediğine emin misin?', doIt, {danger:true, yes:'Sil'}); }
    else doIt();
  }
  // Gizle/Göster: yayındaki duayı duvardan kaldır (geri alınabilir) ya da geri yayınla.
  function hideDua(id,hide){
    var fd=new FormData(); fd.append('id',id); fd.append('hidden',hide?'1':'0');
    api('dua-hide',{method:'POST',body:fd}).then(function(res){
      if(res.j&&res.j.ok){ toast(hide?'Gizlendi ✓':'Tekrar yayınlandı ✓'); loadDuaWall(); }
      else { toast('Hata: '+((res.j&&res.j.error)||res.status)); }
    }).catch(function(e){ toast('Hata: '+e); });
  }
  // Banla (dua moderasyonundan): yazarı banla → uygulamadan otomatik çıkar, bir
  // daha giremez, "engellendiniz" görür + TÜM dua duvarı gönderileri silinir (sunucu).
  function banDuaUser(uid,id){
    if(!uid){ toast('Kullanıcı bilgisi yok'); return; }
    uiConfirm('Bu kullanıcı banlanacak; uygulamaya bir daha giremeyecek ve tüm duaları silinecek. Emin misin?', function(){
      uiPrompt('Ban sebebi (opsiyonel — kullanıcıya gösterilmez):', 'Uygunsuz içerik', function(reason){
        if(reason===null) return;
        var fd=new FormData(); fd.append('id',uid); fd.append('reason',reason);
        api('user-ban',{method:'POST',body:fd}).then(function(res){
          if(res.j&&res.j.ok){ toast('Kullanıcı banlandı + duaları silindi ✓'); loadDuaWall(); }
          else { toast('Hata: '+((res.j&&res.j.error)||res.status)); }
        }).catch(function(e){ toast('Hata: '+e); });
      }, {title:'Ban sebebi', yes:'Banla'});
    }, {danger:true, yes:'Devam', title:'Kullanıcıyı Banla'});
  }
  function banUser(id,email){
    uiPrompt('"'+email+'" — ban sebebi (opsiyonel):', '', function(reason){
      if(reason===null) return;
      var fd=new FormData(); fd.append('id',id); fd.append('reason',reason);
      api('user-ban',{method:'POST',body:fd}).then(function(res){
        if(res.j&&res.j.ok){ toast('Banlandı ✓'); loadUsers(); }
        else { toast('Hata: '+((res.j&&res.j.error)||res.status)); }
      }).catch(function(e){ toast('Hata: '+e); });
    }, {title:'Üyeyi Banla', yes:'Banla'});
  }
  function unbanUser(id,email){
    uiConfirm('"'+email+'" yasağını kaldır (af)?', function(){
      var fd=new FormData(); fd.append('id',id);
      api('user-unban',{method:'POST',body:fd}).then(function(res){
        if(res.j&&res.j.ok){ toast('Yasak kaldırıldı ✓'); loadUsers(); }
        else { toast('Hata: '+((res.j&&res.j.error)||res.status)); }
      }).catch(function(e){ toast('Hata: '+e); });
    }, {yes:'Yasağı Kaldır', title:'Af'});
  }

  // --- Topluluk Hatmi (admin: tüm kampanyalar + cüz detayı + yönetim) ---
  var HATIM = [];
  function loadHatim(){
    el('hatimBody').innerHTML='<p class="muted">Yükleniyor…</p>';
    api('hatim').then(function(res){
      HATIM=(res.j&&res.j.campaigns)||[];
      if(!HATIM.length){ el('hatimBody').innerHTML='<p class="muted">Henüz hatim yok.</p>'; return; }
      var active=HATIM.filter(function(c){return c.status==='active';}).length;
      el('hatimBody').innerHTML='<p class="muted" style="margin:0 0 10px">Toplam <b>'+HATIM.length+'</b> hatim · <b>'+active+'</b> aktif</p>'+HATIM.map(renderHatimCampaign).join('');
    }).catch(function(e){ el('hatimBody').innerHTML='<p class="muted">Hata: '+e+'</p>'; });
  }
  function renderHatimCampaign(c){
    var id=esc(c.id);
    var statusBadge = c.status==='completed'
      ? '<span class="badge" style="color:var(--ok);background:#eafaf1;border-color:#bfe8d0">✓ tamamlandı</span>'
      : '<span class="badge">aktif</span>';
    var cells=(c.juz||[]).map(function(j){
      var col,bg;
      if(j.status==='done'){ col='var(--ok)'; bg='#eafaf1'; }
      else if(j.status==='claimed'){ col='#d6912a'; bg='#fdf3e3'; }
      else { col='var(--gold)'; bg='var(--gold-soft)'; }
      return '<div class="hjuz" data-cid="'+id+'" data-juz="'+j.juz_no+'" onclick="showHatimClaimer(this.dataset.cid,this.dataset.juz)" style="background:'+bg+';border:1px solid '+col+';color:'+col+'">'+j.juz_no+'</div>';
    }).join('');
    return '<div class="card" style="margin:0 0 12px">'+
      '<div class="row" style="align-items:center;margin-bottom:4px"><h3 style="margin:0;flex:1">'+esc(c.title)+' '+statusBadge+'</h3>'+
      '<span class="badge">'+(c.done||0)+'/30</span>'+
      '<button class="danger" data-id="'+id+'" onclick="hatimDelete(this.dataset.id)">Sil</button></div>'+
      (c.intention?'<p class="muted" style="margin:0 0 4px">🎯 '+esc(c.intention)+'</p>':'')+
      '<p class="muted" style="margin:0 0 8px">Başlatan: '+esc(c.created_rumuz||'—')+' · '+fmtDate(c.created_at)+' · okunuyor: '+(c.claimed||0)+'</p>'+
      '<div class="hgrid">'+cells+'</div></div>';
  }
  function showHatimClaimer(cid,juz){
    var c=null; for(var k=0;k<HATIM.length;k++){ if(HATIM[k].id===cid){ c=HATIM[k]; break; } }
    if(!c) return;
    var j=null, list=c.juz||[]; for(var i=0;i<list.length;i++){ if(String(list[i].juz_no)===String(juz)){ j=list[i]; break; } }
    if(!j) return;
    if(j.status==='open'){ uiAlert(juz+'. cüz henüz alınmadı — boş.', juz+'. Cüz'); return; }
    var st = j.status==='done'
      ? '<span style="color:var(--ok);font-weight:700">✅ Okundu</span>'
      : '<span style="color:#d6912a;font-weight:700">📖 Okunuyor</span>';
    var rows='<div class="kv"><span>Durum</span><b>'+st+'</b></div>'+
      '<div class="kv"><span>Rumuz</span><b>'+(j.rumuz?'@'+esc(j.rumuz):'(yok)')+'</b></div>'+
      '<div class="kv"><span>Ad</span><b>'+esc(j.claimer_name||'—')+'</b></div>'+
      '<div class="kv"><span>E-posta</span><b>'+esc(j.claimer_email||'(hesap bulunamadı)')+'</b></div>'+
      (j.claimed_at?'<div class="kv"><span>Aldığı</span><b>'+fmtDate(j.claimed_at)+'</b></div>':'')+
      (j.done_at?'<div class="kv"><span>Okuduğu</span><b>'+fmtDate(j.done_at)+'</b></div>':'');
    var ov=_modal('<h3>📖 '+juz+'. Cüz — okuyan</h3>'+rows+
      '<div class="row" style="margin-top:18px"><button class="ghost" data-x>Kapat</button><button class="danger" data-r>Cüzü Sıfırla</button></div>');
    ov.querySelector('[data-x]').onclick=function(){ ov.remove(); };
    ov.querySelector('[data-r]').onclick=function(){
      ov.remove();
      uiConfirm('Bu cüz boşaltılsın mı? Başkası alabilir.', function(){
        var fd=new FormData(); fd.append('id',cid); fd.append('juz',juz);
        api('hatim-juz-reset',{method:'POST',body:fd}).then(function(res){
          if(res.j&&res.j.ok){ toast('Cüz sıfırlandı ✓'); loadHatim(); } else { toast('Hata'); }
        }).catch(function(e){ toast('Hata: '+e); });
      }, {danger:true, yes:'Sıfırla', title:'Cüzü Sıfırla'});
    };
  }
  function hatimDelete(id){
    uiConfirm('Bu hatmi ve tüm cüzlerini silmek istediğine emin misin?', function(){
      var fd=new FormData(); fd.append('id',id);
      api('hatim-delete',{method:'POST',body:fd}).then(function(res){
        if(res.j&&res.j.ok){ toast('Silindi ✓'); loadHatim(); } else { toast('Hata'); }
      }).catch(function(e){ toast('Hata: '+e); });
    }, {danger:true, yes:'Sil', title:'Hatmi Sil'});
  }
  function hatimCreate(){
    var title=el('htTitle').value.trim();
    if(title.length<2){ toast('Başlık gerekli'); return; }
    el('htStatus').textContent='Ekleniyor…';
    var fd=new FormData(); fd.append('title',title); fd.append('intention',el('htIntent').value.trim());
    api('hatim-create',{method:'POST',body:fd}).then(function(res){
      el('htStatus').textContent='';
      if(res.j&&res.j.ok){ toast('Hatim başlatıldı ✓'); el('htTitle').value=''; el('htIntent').value=''; loadHatim(); }
      else { toast('Hata: '+((res.j&&res.j.error)||res.status)); }
    }).catch(function(e){ el('htStatus').textContent=''; toast('Hata: '+e); });
  }

  // --- Bilgi Yarışması haftalık sıralama (admin) ---
  function loadQuizBoard(week){
    el('quizBody').innerHTML='<p class="muted">Yükleniyor…</p>';
    api('quiz-leaderboard'+(week?('?week='+encodeURIComponent(week)):'')).then(function(res){
      var j=res.j||{}; var weeks=j.weeks||[]; var sel=el('quizWeek');
      sel.innerHTML = weeks.length
        ? weeks.map(function(w){ return '<option value="'+esc(w.week)+'"'+(w.week===j.week?' selected':'')+'>'+esc(w.week)+' ('+w.n+' kişi)</option>'; }).join('')
        : '<option>—</option>';
      var rows=j.rows||[];
      if(!rows.length){ el('quizBody').innerHTML='<p class="muted">Bu hafta için kayıt yok.</p>'; return; }
      var h='<table style="width:100%;border-collapse:collapse"><thead><tr>'+
        '<th style="text-align:left;padding:8px 6px;color:var(--mut);font-size:12px">#</th>'+
        '<th style="text-align:left;padding:8px 6px;color:var(--mut);font-size:12px">Rumuz</th>'+
        '<th style="text-align:left;padding:8px 6px;color:var(--mut);font-size:12px">E-posta</th>'+
        '<th style="text-align:right;padding:8px 6px;color:var(--mut);font-size:12px">Doğru</th>'+
        '<th style="text-align:right;padding:8px 6px;color:var(--mut);font-size:12px">Skor</th></tr></thead><tbody>';
      rows.forEach(function(r,i){
        var medal = i===0?'🥇':i===1?'🥈':i===2?'🥉':(i+1)+'.';
        h+='<tr style="border-top:1px solid var(--line)">'+
          '<td style="padding:8px 6px;font-weight:700">'+medal+'</td>'+
          '<td style="padding:8px 6px;font-weight:600">@'+esc(r.rumuz||'—')+'</td>'+
          '<td style="padding:8px 6px;color:var(--mut);font-size:12px">'+esc(r.email||'—')+'</td>'+
          '<td style="padding:8px 6px;text-align:right">'+(r.correct||0)+'/'+(r.total||0)+'</td>'+
          '<td style="padding:8px 6px;text-align:right;font-weight:800;color:var(--gold)">'+(r.score||0)+'</td></tr>';
      });
      el('quizBody').innerHTML=h+'</tbody></table>';
    }).catch(function(e){ el('quizBody').innerHTML='<p class="muted">Hata: '+e+'</p>'; });
  }

  // --- İçerik şikayetleri (Bildir) ---
  function loadReports(){
    el('reportsBody').innerHTML='<p class="muted">Yükleniyor…</p>';
    api('content-reports').then(function(res){
      var rows=(res.j&&res.j.rows)||[];
      var badge=el('reportsBadge');
      if(badge){ if(rows.length){ badge.textContent=rows.length; badge.style.display='inline-block'; } else { badge.style.display='none'; } }
      if(!rows.length){ el('reportsBody').innerHTML='<p class="muted">Şikayet yok 🎉</p>'; return; }
      var h='<table style="width:100%;border-collapse:collapse"><thead><tr>'+
        '<th style="text-align:left;padding:8px 6px;color:var(--mut);font-size:12px">İçerik</th>'+
        '<th style="text-align:left;padding:8px 6px;color:var(--mut);font-size:12px">Tür</th>'+
        '<th style="text-align:right;padding:8px 6px;color:var(--mut);font-size:12px">Şikayet</th>'+
        '<th style="text-align:left;padding:8px 6px;color:var(--mut);font-size:12px">Sebepler</th>'+
        '<th></th></tr></thead><tbody>';
      rows.forEach(function(r){
        var n=r.n||0; var col=n>=5?'#e0556b':(n>=3?'#e0a441':'var(--gold)');
        h+='<tr style="border-top:1px solid var(--line)">'+
          '<td style="padding:8px 6px"><div style="font-weight:600">'+esc(r.ctitle||r.ckey)+'</div><div style="color:var(--mut);font-size:11px">'+esc(r.ckey)+'</div></td>'+
          '<td style="padding:8px 6px;color:var(--mut);font-size:12px">'+esc(r.ctype||'—')+'</td>'+
          '<td style="padding:8px 6px;text-align:right;font-weight:800;color:'+col+'">'+n+'</td>'+
          '<td style="padding:8px 6px;color:var(--mut);font-size:12px;max-width:280px">'+esc(String(r.reasons||'—').slice(0,200))+'</td>'+
          '<td style="padding:8px 6px;text-align:right"><button class="ghost" data-k="'+esc(r.ckey)+'" onclick="clearReport(this.dataset.k)">Temizle</button></td></tr>';
      });
      el('reportsBody').innerHTML=h+'</tbody></table>';
    }).catch(function(e){ el('reportsBody').innerHTML='<p class="muted">Hata: '+esc(String(e))+'</p>'; });
  }
  function clearReport(key){
    uiConfirm('Bu içeriğin şikayet kayıtları silinsin mi?\\n(İçeriğin kendisi silinmez — onu ilgili kategoriden kaldır.)', function(){
      api('content-report-clear',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({key:key})})
        .then(function(){ toast('Şikayet temizlendi'); loadReports(); });
    }, {title:'Şikayeti Temizle', yes:'Temizle', danger:true});
  }

  // 🔔 Bildirim akışı (e-posta yerine — kullanıcı isteği): son üye/dua/şikayet/
  // hatim/beğeni hareketleri. Rozet = en son "görüldü"den beri yeni öğe sayısı.
  var ACT_ICON = { member:'🎉', dua:'🤲', report:'🚩', hatim:'📖', hatimDone:'✅', like:'❤️' };
  var actData = [];
  function actRel(ms){
    var d = Date.now() - (ms||0); if (d < 0) d = 0;
    var m = Math.floor(d/60000);
    if (m < 1) return 'az önce';
    if (m < 60) return m + ' dk';
    var h = Math.floor(m/60); if (h < 24) return h + ' sa';
    return Math.floor(h/24) + ' gün';
  }
  function loadActivity(){
    if (!TOKEN) return;
    api('activity').then(function(r){
      if (!r.j || !r.j.ok) return;
      actData = r.j.activity || [];
      var seen = +(localStorage.getItem('selaya_act_seen') || 0);
      var n = 0; for (var i=0;i<actData.length;i++){ if ((actData[i].at||0) > seen) n++; }
      var dot = el('actDot');
      if (dot){ dot.textContent = n > 99 ? '99+' : String(n); dot.style.display = n > 0 ? 'inline-flex' : 'none'; }
      var p = el('actPanel'); if (p && !p.classList.contains('hide')) renderActivity();
    }).catch(function(){});
  }
  function renderActivity(){
    var h = '<h3>🔔 Son hareketler</h3>';
    if (!actData.length) h += '<p class="muted" style="padding:10px 12px">Henüz hareket yok.</p>';
    actData.forEach(function(a){
      h += '<div class="actRow"><div class="ic">' + (ACT_ICON[a.type]||'•') + '</div>'
        + '<div class="tx"><div class="tt">' + esc(a.title||'')
        + (a.tag ? ' <span class="muted" style="font-size:11px">('+esc(a.tag)+')</span>' : '')
        + '</div>' + (a.sub ? '<div class="sb">' + esc(a.sub) + '</div>' : '') + '</div>'
        + '<div class="tm">' + actRel(a.at) + '</div></div>';
    });
    el('actPanel').innerHTML = h;
  }
  function toggleActivity(){
    var p = el('actPanel'); if (!p) return;
    var willOpen = p.classList.contains('hide');
    p.classList.toggle('hide', !willOpen);
    if (willOpen){
      renderActivity();
      if (actData.length) localStorage.setItem('selaya_act_seen', String(actData[0].at||0));
      var dot = el('actDot'); if (dot) dot.style.display = 'none';
    }
  }
  // Panel dışına tıklayınca kapan.
  document.addEventListener('click', function(e){
    var p = el('actPanel'); if (!p || p.classList.contains('hide')) return;
    if (e.target.closest && (e.target.closest('#actPanel') || e.target.closest('.bellbtn'))) return;
    p.classList.add('hide');
  });

  // --- Kullanım istatistikleri (free tier takibi) ---
  function pctOf(used, limit){ return limit > 0 ? Math.min(100, used / limit * 100) : 0; }
  function gbStr(b){ return (b / 1073741824).toFixed(2) + ' GB'; }
  function mbStr(b){ return (b / 1048576).toFixed(1) + ' MB'; }
  function usageBar(used, limit, sub){
    var p = pctOf(used, limit);
    var col = p > 90 ? '#e0556b' : (p > 70 ? '#e0a441' : '#46d08a');
    return '<div style="margin:8px 0 4px">'
      + '<div style="display:flex;justify-content:space-between;font-size:13px;margin-bottom:5px">'
      + '<span>' + esc(sub) + '</span><b style="color:' + col + '">%' + p.toFixed(1) + '</b></div>'
      + '<div style="height:11px;background:#1b2233;border-radius:6px;overflow:hidden">'
      + '<div style="height:100%;width:' + p.toFixed(2) + '%;background:' + col + '"></div></div></div>';
  }
  function loadStats(){
    el('statsBody').innerHTML = '<p class="muted">Hesaplanıyor…</p>';
    api('stats').then(function(res){ renderStats(res.j); })
      .catch(function(e){ el('statsBody').innerHTML = '<p class="hint">Hata: ' + esc(String(e)) + '</p>'; });
  }
  function statTable(rows, head){
    var h = '<table style="width:100%;border-collapse:collapse;font-size:13px;margin-top:8px">';
    h += '<tr style="color:#8b93a7">' + head + '</tr>' + rows + '</table>';
    return h;
  }
  function renderStats(s){
    if (!s || !s.ok){ el('statsBody').innerHTML = '<p class="hint">Yüklenemedi.</p>'; return; }
    var h = '';
    // R2
    h += '<div class="card" style="margin:10px 0"><h3 style="margin:0 0 4px">🗄️ R2 — Dosya Depolama (CDN)</h3>';
    h += usageBar(s.r2.bytes, s.r2.limitBytes, mbStr(s.r2.bytes) + ' / ' + gbStr(s.r2.limitBytes) + ' · ' + s.r2.count + ' dosya');
    var pf = s.r2.byPrefix || {};
    var ks = Object.keys(pf).sort(function(a,b){ return pf[b].bytes - pf[a].bytes; });
    if (ks.length){
      var rr = '';
      for (var i=0;i<ks.length;i++){ rr += '<tr><td>' + esc(ks[i]) + '</td><td align="right">' + pf[ks[i]].count + '</td><td align="right">' + mbStr(pf[ks[i]].bytes) + '</td></tr>'; }
      h += statTable(rr, '<td>Klasör</td><td align="right">Dosya</td><td align="right">Boyut</td>');
    }
    h += '<p class="hint" style="margin-top:8px">Yazma ' + (s.limits.r2ClassAMonth/1e6) + 'M/ay · Okuma ' + (s.limits.r2ClassBMonth/1e6) + 'M/ay ücretsiz · Dışa trafik (egress) <b>tamamen ücretsiz</b>.</p></div>';
    // D1
    h += '<div class="card" style="margin:10px 0"><h3 style="margin:0 0 4px">🗃️ D1 — İçerik Veritabanı</h3>';
    if (s.d1.bytes > 0){ h += usageBar(s.d1.bytes, s.d1.limitBytes, mbStr(s.d1.bytes) + ' / ' + gbStr(s.d1.limitBytes)); }
    else { h += '<p class="muted" style="font-size:13px">Boyut PRAGMA ile okunamadı; satır sayıları aşağıda.</p>'; }
    var dr = '';
    for (var j=0;j<s.d1.tables.length;j++){ dr += '<tr><td>' + esc(s.d1.tables[j].name) + '</td><td align="right">' + s.d1.tables[j].rows + '</td></tr>'; }
    dr += '<tr style="font-weight:700"><td>Toplam</td><td align="right">' + s.d1.rows + '</td></tr>';
    h += statTable(dr, '<td>Tablo</td><td align="right">Satır</td>');
    h += '<p class="hint" style="margin-top:8px">Okuma ' + (s.limits.d1RowsReadDay/1e6) + 'M satır/gün · Yazma ' + (s.limits.d1RowsWriteDay/1000) + 'K satır/gün ücretsiz.</p></div>';
    // Workers
    h += '<div class="card" style="margin:10px 0"><h3 style="margin:0 0 4px">⚙️ Workers — API</h3><p class="hint" style="margin:0">Ücretsiz: <b>100.000 istek/gün</b> + istek başına 10ms CPU. Depolama limitlerinin çok altındasın; asıl izlenecek R2/D1 depolama.</p></div>';
    h += '<p class="muted" style="font-size:12px;text-align:right">Hesaplandı: ' + esc((s.generatedAt||'').replace('T',' ').slice(0,16)) + '</p>';
    el('statsBody').innerHTML = h;
  }

  function connect(){
    TOKEN = val('token').trim();
    localStorage.setItem('selaya_admin_token', TOKEN);
    loadItems();
    loadActivity();
  }

  function api(path, opts){
    opts = opts || {};
    opts.headers = opts.headers || {};
    opts.headers['X-Admin-Token'] = TOKEN;
    return fetch('/api/' + path, opts).then(function(r){ return r.json().then(function(j){ return { status:r.status, j:j }; }); });
  }

  // --- görseli tarayıcıda WebP'ye çevir (boyut + kalite) ---
  function toWebp(file, maxEdge, q){
    return new Promise(function(resolve){
      if (!file || !file.type || file.type.indexOf('image/') !== 0 || file.type.indexOf('gif') >= 0) { resolve(file); return; }
      var img = new Image();
      var u = URL.createObjectURL(file);
      img.onload = function(){
        var scale = Math.min(1, maxEdge / Math.max(img.width, img.height));
        var cw = Math.max(1, Math.round(img.width * scale));
        var ch = Math.max(1, Math.round(img.height * scale));
        var cv = document.createElement('canvas'); cv.width = cw; cv.height = ch;
        cv.getContext('2d').drawImage(img, 0, 0, cw, ch);
        URL.revokeObjectURL(u);
        cv.toBlob(function(b){
          if (!b) { resolve(file); return; }
          resolve(new File([b], (file.name.replace(/\\.[^.]+$/, '') || 'img') + '.webp', { type: 'image/webp' }));
        }, 'image/webp', q);
      };
      img.onerror = function(){ URL.revokeObjectURL(u); resolve(file); };
      img.src = u;
    });
  }

  // Videonun ilk karesini WebP kapak olarak çıkar (manuel kapak gerekmesin).
  function videoFirstFrame(file){
    return new Promise(function(resolve){
      if (!file || !file.type || file.type.indexOf('video') !== 0){ resolve(null); return; }
      var v = document.createElement('video');
      v.preload = 'metadata'; v.muted = true; v.playsInline = true;
      var u = URL.createObjectURL(file);
      var done = false;
      function fail(){ if (done) return; done = true; URL.revokeObjectURL(u); resolve(null); }
      v.onloadeddata = function(){ try { v.currentTime = Math.min(0.15, (v.duration || 1) / 2); } catch(e){ fail(); } };
      v.onseeked = function(){
        if (done) return; done = true;
        try {
          var cv = document.createElement('canvas');
          cv.width = v.videoWidth || 720; cv.height = v.videoHeight || 1280;
          cv.getContext('2d').drawImage(v, 0, 0, cv.width, cv.height);
          URL.revokeObjectURL(u);
          cv.toBlob(function(b){ resolve(b ? new File([b], 'cover.webp', { type: 'image/webp' }) : null); }, 'image/webp', 0.82);
        } catch(e){ URL.revokeObjectURL(u); resolve(null); }
      };
      v.onerror = fail;
      v.src = u;
    });
  }

  function loadItems(){
    api('items').then(function(res){
      if (res.status === 401){ toast('Anahtar hatalı'); return; }
      el('authCard').classList.add('hide');
      el('app').classList.remove('hide');
      CDN = res.j.cdn || '';
      renderItems(res.j.items || []);
      if (firstLoad){ firstLoad = false; showCat(currentCat); }
    }).catch(function(e){ toast('Hata: ' + e); });
  }

  function renderItems(items){ ALL_ITEMS = items || []; renderCat(); }
  function renderCat(){
      var col = currentCat;
      var arr = ALL_ITEMS.filter(function(it){ return it.collection === col; });
      var inner = '';
      if (col === 'audio_stories') {
        arr.forEach(function(it){
          var ex = {}; try { ex = JSON.parse(it.extra || '{}'); } catch (e) {}
          var eps = ex.episodes || [];
          var epHtml = eps.map(function(e, k){
            return '<div style="margin:5px 0"><div class="muted">' + esc(e.title || ('Bölüm ' + (k + 1))) +
              (e.subtitle ? ' — ' + esc(e.subtitle) : '') +
              '</div><audio controls preload="none" src="' + esc(e.audio) + '" style="width:100%;height:34px"></audio></div>';
          }).join('');
          inner += '<div class="item" draggable="true" data-id="' + esc(it.id) + '" style="align-items:flex-start"><span class="grip" title="Sürükle">⠿</span><img src="' + CDN + '/' + it.key + '" loading="lazy">' +
            '<div class="meta"><b>' + esc(it.title || '') + '</b><span class="muted">' + eps.length + ' bölüm' + (it.size ? ' · ' + fmtSize(it.size) : '') + '</span>' + epHtml + '</div>' +
            '<button class="ghost" data-act="edit" data-id="' + esc(it.id) + '" data-col="audio_stories" data-kind="audio" data-title="' + esc(it.title || '') + '" data-sub="' + esc(it.subtitle || '') + '" data-active="1" data-sort="' + (it.sort || 0) + '">Düzenle</button>' +
            '<button class="ghost" data-act="replace" data-id="' + esc(it.id) + '">Kapak</button>' +
            '<button class="danger" data-act="del" data-id="' + esc(it.id) + '">Sil</button></div>';
        });
      } else {
        arr.forEach(function(it){
          var u = CDN + '/' + it.key;
          var prev = it.kind === 'video' ? '<video src="' + u + '" muted></video>'
            : it.kind === 'audio' ? '<div class="ph">♪</div>'
            : '<img src="' + u + '" loading="lazy">';
          inner += '<div class="item" draggable="true" data-id="' + esc(it.id) + '"><span class="grip" title="Sürükle-bırak ile sırala">⠿</span>' + prev +
            '<div class="meta"><b>' + esc(it.title || it.key.split('/').pop()) + '</b><span class="muted">' + (it.size ? fmtSize(it.size) + ' · ' : '') + esc(it.subtitle || it.key) + '</span></div>' +
            '<span class="badge">' + (it.active ? 'aktif' : 'pasif') + '</span>' +
            '<button class="ghost" data-act="edit" data-id="' + esc(it.id) + '" data-col="' + esc(col) + '" data-kind="' + esc(it.kind) + '" data-title="' + esc(it.title || '') + '" data-sub="' + esc(it.subtitle || '') + '" data-active="' + (it.active ? 1 : 0) + '" data-sort="' + (it.sort || 0) + '">Düzenle</button>' +
            '<button class="ghost" data-act="replace" data-id="' + esc(it.id) + '">Değiştir</button>' +
            '<button class="ghost" data-act="toggle" data-id="' + esc(it.id) + '" data-active="' + (it.active ? 0 : 1) + '" data-col="' + esc(col) + '" data-kind="' + esc(it.kind) + '">' + (it.active ? 'Gizle' : 'Göster') + '</button>' +
            '<button class="danger" data-act="del" data-id="' + esc(it.id) + '">Sil</button>' +
            '</div>';
        });
      }
      var sy = window.scrollY;
      el('list').innerHTML = inner || '<p class="muted">Bu kategoride henüz içerik yok. Yukarıdan ekleyebilirsin.</p>';
      requestAnimationFrame(function(){ window.scrollTo(0, sy); });
      var lt = el('listTitle'); if (lt) lt.textContent = (LABELS[col] || col) + ' · ' + arr.length + ' içerik';
  }

  // --- Sürükle-bırak ile elle sıralama ---
  var _dragEl = null;
  function attachDnd(list){
    list.addEventListener('dragstart', function(e){
      if (e.target.closest('button')){ e.preventDefault(); return; }
      var it = e.target.closest('.item'); if (!it) return;
      _dragEl = it; e.dataTransfer.effectAllowed = 'move';
      try { e.dataTransfer.setData('text/plain', it.dataset.id || ''); } catch(x){}
      setTimeout(function(){ it.classList.add('dragging'); }, 0);
    });
    list.addEventListener('dragover', function(e){
      if (!_dragEl || _dragEl.parentNode !== list) return;
      e.preventDefault();
      var after = dragAfter(list, e.clientY);
      if (after == null) list.appendChild(_dragEl);
      else list.insertBefore(_dragEl, after);
    });
    list.addEventListener('dragend', function(){
      if (!_dragEl) return;
      _dragEl.classList.remove('dragging');
      var lst = _dragEl.parentNode; _dragEl = null;
      saveOrder(lst);
    });
  }
  (function initDnd(){
    var l = el('list'); if (l) attachDnd(l);
    var t = el('txList'); if (t) attachDnd(t);
  })();
  function dragAfter(container, y){
    var els = Array.prototype.slice.call(container.querySelectorAll('.item:not(.dragging)'));
    var closest = null, closestOffset = -Infinity;
    for (var i = 0; i < els.length; i++){
      var box = els[i].getBoundingClientRect();
      var offset = y - box.top - box.height / 2;
      if (offset < 0 && offset > closestOffset){ closestOffset = offset; closest = els[i]; }
    }
    return closest;
  }
  function saveOrder(list){
    if (!list) return;
    var nodes = Array.prototype.slice.call(list.querySelectorAll('.item'));
    var changed = [];
    nodes.forEach(function(node, i){
      var id = node.dataset.id; if (!id) return;
      var it = null;
      for (var k = 0; k < ALL_ITEMS.length; k++){ if (ALL_ITEMS[k].id === id){ it = ALL_ITEMS[k]; break; } }
      if (it && (it.sort || 0) !== i){ changed.push({ it: it, sort: i }); }
    });
    if (!changed.length) return;
    toast('Sıralama kaydediliyor…');
    Promise.all(changed.map(function(c){
      return api('items/' + c.it.id, { method:'PUT', headers:{ 'Content-Type':'application/json' },
        body: JSON.stringify({ title: c.it.title, subtitle: c.it.subtitle, collection: c.it.collection, kind: c.it.kind, active: c.it.active ? 1 : 0, sort: c.sort }) });
    })).then(function(){ toast('Sıralama kaydedildi ✓'); if (list.id === 'txList') loadText(); else loadItems(); });
  }

  async function upload(){
    var f = el('upFile').files[0];
    if (!f){ toast('Önce dosya seç'); return; }
    // Video boyut sınırı: 4 MB. Büyük videolar reddedilir (önce sıkıştır).
    if (f.type && f.type.indexOf('video') === 0 && f.size > 4*1024*1024){
      toast('Video en fazla 4 MB olabilir (şu an ' + fmtSize(f.size) + ')');
      el('upStatus').innerHTML = '<span style="color:var(--danger)">Video 4 MB sınırını aşıyor (' + fmtSize(f.size) + '). Lütfen sıkıştırıp tekrar dene.</span>';
      return;
    }
    var btn = el('upBtn'); if (btn){ btn.disabled = true; btn.textContent = 'Yükleniyor…'; }
    function done(){ if (btn){ btn.disabled = false; btn.textContent = 'Yükle'; } }
    el('upStatus').textContent = 'Hazırlanıyor...';
    var main = await toWebp(f, 2048, 0.85);
    var coverFile = el('upCover').files[0];
    var cover = coverFile ? await toWebp(coverFile, 1280, 0.85) : null;
    // Video + manuel kapak yoksa → ilk kareyi OTOMATİK kapak yap.
    if (!cover && f.type && f.type.indexOf('video') === 0) { cover = await videoFirstFrame(f); }
    // Görsel + manuel kapak yoksa → ızgaralar için KÜÇÜK önizleme üret (≤560px).
    if (!cover && f.type && f.type.indexOf('image/') === 0) { cover = await toWebp(f, 560, 0.78); }
    var fd = new FormData();
    fd.append('file', main);
    if (cover) fd.append('cover', cover);
    fd.append('collection', val('upCollection'));
    fd.append('title', val('upTitle'));
    fd.append('subtitle', val('upDesc'));
    fd.append('sort', val('upSort'));
    el('upStatus').textContent = 'Yükleniyor...';
    api('upload', { method:'POST', body: fd }).then(function(res){
      done();
      if (res.j && res.j.ok){
        el('upStatus').innerHTML = '<span class="ok">Yüklendi ✓ (' + fmtSize(main.size) + ') — kategori/sıra korundu, sıradakini ekleyebilirsin.</span>';
        el('upFile').value = ''; el('upCover').value = ''; el('upTitle').value = ''; el('upDesc').value = '';
        loadItems();
      } else {
        el('upStatus').textContent = 'Hata: ' + ((res.j && res.j.error) || res.status);
      }
    }).catch(function(e){ done(); el('upStatus').textContent = 'Hata: ' + e; });
  }

  // --- bildirimler ---
  function loadNotifications(){
    api('notifications').then(function(res){
      if (res.status === 401){ toast('Anahtar hatalı'); return; }
      CDN = res.j.cdn || CDN;
      var items = res.j.items || [];
      var html = '';
      items.forEach(function(n){
        var img = n.image_key ? '<img src="' + CDN + '/' + n.image_key + '" loading="lazy">' : '<div class="ph">🔔</div>';
        html += '<div class="item">' + img +
          '<div class="meta"><b>' + esc(n.title) + '</b><span class="muted">' + esc(n.body || '') + '</span></div>' +
          '<button class="danger" data-nact="del" data-id="' + esc(n.id) + '">Sil</button>' +
          '</div>';
      });
      el('nlist').innerHTML = html || '<p class="muted">Henüz bildirim gönderilmedi.</p>';
    }).catch(function(e){ toast('Hata: ' + e); });
  }

  async function sendNotify(){
    var title = val('nTitle').trim();
    if (!title){ toast('Başlık gerekli'); return; }
    el('nStatus').textContent = 'Gönderiliyor...';
    var fd = new FormData();
    fd.append('title', title);
    fd.append('body', val('nBody'));
    fd.append('link', val('nLink'));
    api('notify', { method:'POST', body: fd }).then(function(res){
      if (res.j && res.j.ok){
        el('nStatus').innerHTML = '<span class="ok">Gönderildi ✓</span>';
        el('nTitle').value=''; el('nBody').value=''; el('nLink').value='';
        loadNotifications();
      } else { el('nStatus').textContent = 'Hata: ' + ((res.j && res.j.error) || res.status); }
    }).catch(function(e){ el('nStatus').textContent = 'Hata: ' + e; });
  }

  // --- Sesli Hikâye builder (kapak + N bölüm) ---
  function addEpisodeRow(){
    var wrap = el('asEpisodes');
    var i = wrap.children.length;
    var div = document.createElement('div');
    div.className = 'eprow';
    div.style.cssText = 'border:1px solid var(--line);border-radius:10px;padding:10px;margin-bottom:8px';
    div.innerHTML = '<div class="muted" style="margin-bottom:6px">Bölüm ' + (i + 1) + '</div>' +
      '<input type="file" accept="audio/*" class="ep-audio" style="width:100%;margin-bottom:6px">' +
      '<input type="text" class="ep-title" placeholder="Başlık (örn: Gönül Huzuru)" style="width:100%;margin-bottom:6px">' +
      '<input type="text" class="ep-sub" placeholder="Açıklama (örn: Kalbin sükûneti)" style="width:100%">';
    var ai = div.querySelector('.ep-audio');
    ai.addEventListener('change', function(){
      var f = ai.files[0]; if (!f) return;
      var a = document.createElement('audio');
      a.preload = 'metadata';
      a.onloadedmetadata = function(){ div.setAttribute('data-dur', Math.round(a.duration || 0)); };
      a.src = URL.createObjectURL(f);
    });
    wrap.appendChild(div);
  }
  addEpisodeRow(); addEpisodeRow(); addEpisodeRow();

  async function saveAudioStory(){
    var cover = el('asCover').files[0];
    var title = val('asTitle').trim();
    if (!cover){ toast('Kapak görseli seç'); return; }
    if (!title){ toast('Başlık gir'); return; }
    el('asStatus').textContent = 'Hazırlanıyor...';
    var fd = new FormData();
    var cw = await toWebp(cover, 1280, 0.85);
    fd.append('cover', cw);
    fd.append('title', title);
    fd.append('subtitle', val('asSub'));
    var rows = el('asEpisodes').querySelectorAll('.eprow');
    var n = 0;
    for (var r = 0; r < rows.length; r++){
      var af = rows[r].querySelector('.ep-audio').files[0];
      if (!af) continue;
      var at = rows[r].querySelector('.ep-title').value || ('Bölüm ' + (r + 1));
      var asub = rows[r].querySelector('.ep-sub').value || '';
      var adur = rows[r].getAttribute('data-dur') || '0';
      fd.append('ep_audio', af);
      fd.append('ep_title', at);
      fd.append('ep_sub', asub);
      fd.append('ep_dur', adur);
      n++;
    }
    if (n === 0){ el('asStatus').textContent = 'En az 1 ses dosyası ekle'; return; }
    el('asStatus').textContent = n + ' bölüm yükleniyor...';
    api('audio-story', { method:'POST', body: fd }).then(function(res){
      if (res.j && res.j.ok){
        el('asStatus').innerHTML = '<span class="ok">Kaydedildi ✓ (' + res.j.episodes + ' bölüm)</span>';
        el('asCover').value=''; el('asTitle').value=''; el('asSub').value=''; el('asEpisodes').innerHTML='';
        addEpisodeRow(); addEpisodeRow(); addEpisodeRow();
        loadItems();
      } else { el('asStatus').textContent = 'Hata: ' + ((res.j && res.j.error) || res.status); }
    }).catch(function(e){ el('asStatus').textContent = 'Hata: ' + e; });
  }

  // event delegation (içerik + bildirim sil/gizle)
  document.addEventListener('click', function(e){
    var b = e.target.closest ? e.target.closest('button') : null;
    if (!b) return;
    var id = b.getAttribute('data-id');
    if (b.getAttribute('data-act') === 'del'){ uiConfirm('Bu öğe silinsin mi?', function(){ api('items/' + id, { method:'DELETE' }).then(loadItems); }, {danger:true, yes:'Sil'}); }
    else if (b.getAttribute('data-act') === 'edit'){
      var col = b.getAttribute('data-col');
      // Açıklama: video + saf görsel galerilerinde (duvar kâğıdı, sticker, rehber…)
      // gerekmez (upload formunda da gizli) → sorma, mevcut değeri koru.
      var noDesc = (col === 'bg_videos' || col === 'wallpapers' || col === 'stickers' || col === 'radio_art');
      function saveItem(nt, ns){
        api('items/' + id, { method:'PUT', headers:{ 'Content-Type':'application/json' },
          body: JSON.stringify({ title: nt, subtitle: ns, collection: col, kind: b.getAttribute('data-kind'), active: parseInt(b.getAttribute('data-active') || '1', 10), sort: parseInt(b.getAttribute('data-sort') || '0', 10) }) }).then(loadItems);
      }
      uiPrompt('Başlık:', b.getAttribute('data-title') || '', function(nt){
        if (noDesc) { saveItem(nt, b.getAttribute('data-sub') || ''); }
        else { uiPrompt('Açıklama:', b.getAttribute('data-sub') || '', function(ns){ saveItem(nt, ns); }, {title:'Açıklama'}); }
      }, {title:'Başlık'});
    }
    else if (b.getAttribute('data-act') === 'replace'){
      var inp = document.createElement('input');
      inp.type = 'file';
      inp.accept = 'image/*,video/*,audio/*';
      inp.onchange = async function(){
        var f = inp.files[0]; if (!f) return;
        var up = await toWebp(f, 2048, 0.85);
        var fd = new FormData(); fd.append('file', up);
        toast('Yükleniyor...');
        var res = await api('replace/' + id, { method:'POST', body: fd });
        if (res.j && res.j.ok) { toast('Değiştirildi ✓'); loadItems(); }
        else { toast('Hata: ' + ((res.j && res.j.error) || res.status)); }
      };
      inp.click();
    }
    else if (b.getAttribute('data-act') === 'toggle'){
      api('items/' + id, { method:'PUT', headers:{ 'Content-Type':'application/json' },
        body: JSON.stringify({ active: parseInt(b.getAttribute('data-active'), 10), collection: b.getAttribute('data-col'), kind: b.getAttribute('data-kind') }) }).then(loadItems);
    }
    else if (b.getAttribute('data-nact') === 'del'){ uiConfirm('Bu bildirim silinsin mi?', function(){ api('notifications/' + id, { method:'DELETE' }).then(loadNotifications); }, {danger:true, yes:'Sil'}); }
  });

  if (TOKEN) { loadItems(); loadActivity(); }
  // Bildirim akışını periyodik tazele (sekme açıkken canlı kalsın).
  setInterval(loadActivity, 60000);
</script>
</body>
</html>`;
