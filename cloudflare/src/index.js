// SELAYA içerik API'si + yönetim paneli — tek Worker.
// Host'a göre yönlenir:
//   api.selaya.app   -> herkese açık: GET /v1/manifest, GET /v1/notifications, /health
//   panel.selaya.app -> yönetim paneli UI + korumalı yazma API'si (X-Admin-Token)
// Bağlamalar: DB (D1: selaya-content), CDN (R2: selaya-cdn), CDN_BASE (var),
//             ADMIN_TOKEN (secret), AUTH_SECRET (secret — JWT imzası)

import { handleAuth, hashPassword } from './auth.js';

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
function bustManifest(ctx) {
  if (!ctx) return;
  try { ctx.waitUntil(caches.default.delete(MANIFEST_CK)); } catch (_) {}
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

      // ÜYELİK & SENKRON (kayıt/giriş/profil/veri) — ayrı modül, auth değilse null.
      const authResp = await handleAuth(request, env, path);
      if (authResp) return authResp;

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
        return json({ ok: true, items }, { maxage: 30 });
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
          await env.DB.prepare(
            'INSERT INTO likes (key, count) VALUES (?1, 1) ' +
            'ON CONFLICT(key) DO UPDATE SET count = count + 1'
          ).bind(key).run();
          const row = await env.DB.prepare(
            'SELECT count FROM likes WHERE key = ?1'
          ).bind(key).first();
          return json({ ok: true, key, count: row ? row.count : 1 });
        }
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
        if (!env.ADMIN_TOKEN || token !== env.ADMIN_TOKEN) {
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
            'SELECT u.id, u.name, u.surname, u.email, u.email_verified, u.created_at, ' +
            'u.last_active, d.updated_at AS data_updated, d.device ' +
            'FROM users u LEFT JOIN user_data d ON d.user_id = u.id ' +
            'ORDER BY u.created_at DESC LIMIT 1000'
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

          const type = file.type || 'application/octet-stream';
          const kind = type.startsWith('video') ? 'video' : type.startsWith('audio') ? 'audio' : 'image';
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
          await env.DB.prepare(
            'UPDATE content_items SET collection=?, kind=?, title=?, subtitle=?, sort=?, active=?, updated_at=? WHERE id=?'
          ).bind(
            b.collection, b.kind || 'image',
            b.title == null ? null : b.title,
            b.subtitle == null ? null : b.subtitle,
            b.sort || 0, b.active === 0 ? 0 : 1, now, id
          ).run();
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
    <div class="nav-item" onclick="logout()">🚪 Çıkış</div>
  </aside>
  <main class="main">
    <div class="topbar">
      <button class="hamb" onclick="toggleSidebar()">☰</button>
      <h1 id="pageTitle">İçerikler</h1>
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
        <div class="row" style="align-items:center">
          <h3 style="margin:0">👤 Üyeler</h3>
          <button class="ghost" style="flex:0 0 auto" onclick="loadUsers()">Yenile</button>
        </div>
        <p class="hint">Uygulamaya kaydolan kullanıcılar. <b>Şifre Sıfırla</b> yeni şifre belirler (kullanıcıya iletirsin) · <b>Sil</b> hesabı + verisini kalıcı kaldırır (KVKK).</p>
        <div id="usersBody"><p class="muted">Yükleniyor…</p></div>
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
    ['bg_videos', 'Arka Plan Videoları', 'Ana ekran/karşılama arka plan döngüleri.'],
    ['guide_abdest', 'Abdest Rehberi', 'Abdest adım görselleri.'],
    ['guide_namaz', 'Namaz Rehberi', 'Namaz adım görselleri.']
  ];
  var LABELS = {}; var DESCS = {};
  COLLS.forEach(function(c){ LABELS[c[0]] = c[1]; DESCS[c[0]] = c[2]; });
  // (Sesli Hikâyeler / audio_stories KALDIRILDI — medya oynatıcı silindi.)
  var CAT_ICONS = { wallpapers:'🖼️', feed:'🎬', inspiration:'✨', stories:'📖', greeting:'💌', bg_videos:'🎞️', guide_abdest:'🕌', guide_namaz:'🧎' };
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
    el('fileHint').textContent = isVideo ? '(video seç — kapak ilk kareden otomatik)' : '';
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

  var TAB_TITLES = { text:'Metin İçerik', notify:'Bildirimler', stats:'Kullanım', users:'Kullanıcılar' };
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
    setActiveNav(el('tab' + t.charAt(0).toUpperCase() + t.slice(1) + 'Btn'));
    var pt = el('pageTitle'); if (pt) pt.textContent = TAB_TITLES[t] || '';
    toggleSidebar(false);
    if (t === 'notify') loadNotifications();
    if (t === 'stats') loadStats();
    if (t === 'text') loadText();
    if (t === 'users') loadUsers();
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
  function showTxTab(type){ currentTxType = type; renderTxTabs(); renderTxList(); }
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
    api('items/' + encodeURIComponent(id), { method: 'DELETE' }).then(function(){ loadText(); });
  }

  // --- Kullanıcılar (üyeler) ---
  function fmtDate(ms){ if(!ms) return '—'; try{ var d=new Date(ms); return d.toLocaleDateString('tr-TR')+' '+d.toLocaleTimeString('tr-TR',{hour:'2-digit',minute:'2-digit'}); }catch(e){ return '—'; } }
  function loadUsers(){
    el('usersBody').innerHTML='<p class="muted">Yükleniyor…</p>';
    api('users').then(function(res){
      var us=(res.j&&res.j.users)||[];
      if(!us.length){ el('usersBody').innerHTML='<p class="muted">Henüz kayıtlı kullanıcı yok.</p>'; return; }
      var h='<p class="muted" style="margin:0 0 8px">Toplam: <b>'+us.length+'</b> üye</p>';
      h+=us.map(function(u){
        var name=esc(((u.name||'')+' '+(u.surname||'')).trim()||'—');
        var em=esc(u.email||''); var id=esc(u.id);
        return '<div class="item"><div class="ph">👤</div><div class="meta"><b>'+name+'</b><span class="muted">'+em+'</span><span class="muted">Kayıt: '+fmtDate(u.created_at)+' · Son aktif: '+fmtDate(u.last_active)+(u.device?' · '+esc(u.device):'')+'</span></div>'+
          '<button class="ghost" style="flex:0 0 auto" data-id="'+id+'" data-email="'+em+'" onclick="resetUserPw(this.dataset.id,this.dataset.email)">Şifre Sıfırla</button> '+
          '<button class="danger" data-id="'+id+'" data-email="'+em+'" onclick="deleteUser(this.dataset.id,this.dataset.email)">Sil</button></div>';
      }).join('');
      el('usersBody').innerHTML=h;
    }).catch(function(e){ el('usersBody').innerHTML='<p class="muted">Hata: '+e+'</p>'; });
  }
  function resetUserPw(id,email){
    var np=prompt('"'+email+'" için yeni şifre (en az 6 karakter):');
    if(np===null) return;
    if(np.length<6){ toast('Şifre en az 6 karakter olmalı'); return; }
    var fd=new FormData(); fd.append('id',id); fd.append('password',np);
    api('user-reset-password',{method:'POST',body:fd}).then(function(res){
      if(res.j&&res.j.ok){ alert('Şifre sıfırlandı ✓\\n\\nKullanıcıya ilet:\\n'+email+'\\nYeni şifre: '+np); }
      else { toast('Hata: '+((res.j&&res.j.error)||res.status)); }
    }).catch(function(e){ toast('Hata: '+e); });
  }
  function deleteUser(id,email){
    if(!confirm('"'+email+'" hesabını ve TÜM verisini kalıcı silmek istediğine emin misin? (KVKK)')) return;
    var fd=new FormData(); fd.append('id',id);
    api('user-delete',{method:'POST',body:fd}).then(function(res){
      if(res.j&&res.j.ok){ toast('Silindi ✓'); loadUsers(); }
      else { toast('Hata: '+((res.j&&res.j.error)||res.status)); }
    }).catch(function(e){ toast('Hata: '+e); });
  }

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
    if (b.getAttribute('data-act') === 'del'){ if (confirm('Bu öğe silinsin mi?')) api('items/' + id, { method:'DELETE' }).then(loadItems); }
    else if (b.getAttribute('data-act') === 'edit'){
      var nt = prompt('Başlık:', b.getAttribute('data-title') || '');
      if (nt === null) return;
      var col = b.getAttribute('data-col');
      // Açıklama: video + saf görsel galerilerinde (duvar kâğıdı, sticker, rehber…)
      // gerekmez (upload formunda da gizli) → sorma, mevcut değeri koru.
      var noDesc = (col === 'bg_videos' || col === 'wallpapers' || col === 'stickers' || col === 'radio_art');
      var ns;
      if (noDesc) { ns = b.getAttribute('data-sub') || ''; }
      else { ns = prompt('Açıklama:', b.getAttribute('data-sub') || ''); if (ns === null) return; }
      api('items/' + id, { method:'PUT', headers:{ 'Content-Type':'application/json' },
        body: JSON.stringify({ title: nt, subtitle: ns, collection: col, kind: b.getAttribute('data-kind'), active: parseInt(b.getAttribute('data-active') || '1', 10), sort: parseInt(b.getAttribute('data-sort') || '0', 10) }) }).then(loadItems);
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
    else if (b.getAttribute('data-nact') === 'del'){ if (confirm('Bu bildirim silinsin mi?')) api('notifications/' + id, { method:'DELETE' }).then(loadNotifications); }
  });

  if (TOKEN) loadItems();
</script>
</body>
</html>`;
