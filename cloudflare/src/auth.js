// SELAYA üyelik & senkron — auth modülü (api.selaya.app).
// Uçlar:
//   POST /v1/auth/register {name, surname, email, password} -> {token, user}
//   POST /v1/auth/login    {email, password}                -> {token, user}
//   GET  /v1/me            (Bearer)                          -> {user}
//   GET  /v1/me/data       (Bearer)                          -> {data, updated_at}
//   PUT  /v1/me/data       (Bearer) {data:{}, device}        -> {updated_at}
// Şifreler PBKDF2-SHA256 + salt ile hash'lenir (düz metin SAKLANMAZ).
// Oturum = HMAC-SHA256 ile imzalı JWT (secret: env.AUTH_SECRET).

import { validateRumuz, containsProfanity } from './profanity.js';

const enc = new TextEncoder();

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

function safeParse(s) { try { return JSON.parse(s); } catch (_) { return null; } }
async function readJson(request) { try { return await request.json(); } catch (_) { return null; } }
function validEmail(e) { return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(e); }
// Şifre: en az 6 karakter + EN AZ 1 harf + EN AZ 1 rakam.
function validPassword(p) {
  return typeof p === 'string' && p.length >= 6 &&
      /[A-Za-z]/.test(p) && /[0-9]/.test(p);
}

// ---------- base64 yardımcıları ----------
function b64FromBytes(bytes) {
  let bin = '';
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin);
}
function bytesFromB64(str) {
  const bin = atob(str);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}
function b64urlFromBytes(bytes) {
  return b64FromBytes(bytes).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
function bytesFromB64url(str) {
  str = str.replace(/-/g, '+').replace(/_/g, '/');
  while (str.length % 4) str += '=';
  return bytesFromB64(str);
}
function b64urlFromStr(str) {
  return b64urlFromBytes(enc.encode(str));
}
function strFromB64url(str) {
  return new TextDecoder().decode(bytesFromB64url(str));
}

// ---------- şifre (PBKDF2-SHA256) ----------
async function pbkdf2(password, saltBytes, iters) {
  const km = await crypto.subtle.importKey(
    'raw', enc.encode(password), { name: 'PBKDF2' }, false, ['deriveBits']);
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', salt: saltBytes, iterations: iters, hash: 'SHA-256' }, km, 256);
  return new Uint8Array(bits);
}

export async function hashPassword(password) {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const iters = 100000;
  const hash = await pbkdf2(password, salt, iters);
  return { hash: b64FromBytes(hash), salt: b64FromBytes(salt), iters };
}

export function timingSafeEqual(a, b) {
  if (a.length !== b.length) return false;
  let r = 0;
  for (let i = 0; i < a.length; i++) r |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return r === 0;
}

async function verifyPassword(password, saltB64, hashB64, iters) {
  const salt = bytesFromB64(saltB64);
  const hash = await pbkdf2(password, salt, iters || 100000);
  return timingSafeEqual(b64FromBytes(hash), hashB64);
}

// ---------- JWT (HS256) ----------
async function hmacKey(secret) {
  return crypto.subtle.importKey(
    'raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign', 'verify']);
}

async function signJWT(payload, secret) {
  const head = b64urlFromStr(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const body = b64urlFromStr(JSON.stringify(payload));
  const data = head + '.' + body;
  const key = await hmacKey(secret);
  const sig = await crypto.subtle.sign('HMAC', key, enc.encode(data));
  return data + '.' + b64urlFromBytes(new Uint8Array(sig));
}

async function verifyJWT(token, secret) {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    const data = parts[0] + '.' + parts[1];
    const key = await hmacKey(secret);
    const ok = await crypto.subtle.verify('HMAC', key, bytesFromB64url(parts[2]), enc.encode(data));
    if (!ok) return null;
    const payload = safeParse(strFromB64url(parts[1]));
    if (!payload) return null;
    if (payload.exp && Math.floor(Date.now() / 1000) > payload.exp) return null;
    return payload;
  } catch (_) { return null; }
}

const TOKEN_TTL = 60 * 60 * 24 * 90; // 90 gün (sec_version ile iptal edilebilir)

async function issueToken(env, user, deviceId) {
  const now = Math.floor(Date.now() / 1000);
  // sv = sec_version: şifre değişimi/reset/ban'da artar → eski token'lar geçersiz.
  const payload = {
    sub: user.id, email: user.email, iat: now, exp: now + TOKEN_TTL,
    sv: Number(user.sec_version) || 0,
  };
  if (deviceId) payload.did = deviceId; // en fazla 2 cihaz: token'ı cihaza bağla
  return signJWT(payload, env.AUTH_SECRET);
}

// users.sec_version kolonunu (oturum iptali için) bir kez, isolate başına garanti
// et. Eski deploy'larda kolon olmayabilir → ekle; varsa hata yutulur.
let _secColOk = false;
async function ensureSecCol(env) {
  if (_secColOk) return;
  try {
    await env.DB.prepare(
      'ALTER TABLE users ADD COLUMN sec_version INTEGER NOT NULL DEFAULT 0'
    ).run();
  } catch (_) {}
  _secColOk = true;
}

// Reset (şifremi unuttum) kodu kötüye-kullanım sınırı için sayaç kolonları:
// kullanıcı başına GÜNDE en fazla 3 kod istenebilir (e-posta kotası + spam
// koruması). Eski deploy'larda kolon yoksa eklenir; varsa hata yutulur.
let _resetColOk = false;
async function ensureResetCols(env) {
  if (_resetColOk) return;
  try {
    await env.DB.prepare(
      'ALTER TABLE users ADD COLUMN reset_count INTEGER NOT NULL DEFAULT 0'
    ).run();
  } catch (_) {}
  try {
    await env.DB.prepare('ALTER TABLE users ADD COLUMN reset_day TEXT').run();
  } catch (_) {}
  _resetColOk = true;
}

function publicUser(u) {
  return {
    id: u.id, name: u.name, surname: u.surname || '', email: u.email,
    rumuz: u.rumuz || '',
  };
}

// En fazla 2 aktif cihaz. Cihazı kaydet/tazele; yeni cihaz sınırı aşıyorsa EN
// ESKİ (last_seen) cihaz(lar)ı düşür → onların token'ı sonraki istekte 401 olur.
const MAX_DEVICES = 4;
async function registerDevice(env, userId, deviceId, label) {
  if (!deviceId) return;
  const now = Date.now();
  const existing = await env.DB.prepare(
    'SELECT device_id FROM user_devices WHERE user_id=? AND device_id=?'
  ).bind(userId, deviceId).first();
  if (existing) {
    await env.DB.prepare(
      'UPDATE user_devices SET last_seen=?, label=? WHERE user_id=? AND device_id=?'
    ).bind(now, label || '', userId, deviceId).run();
    return;
  }
  // Yeni cihaz → bu cihazı eklediğimizde toplam MAX'ı aşacaksa en eskileri düşür.
  const { results } = await env.DB.prepare(
    'SELECT device_id FROM user_devices WHERE user_id=? ORDER BY last_seen ASC'
  ).bind(userId).all();
  const evict = results.slice(0, Math.max(0, results.length - (MAX_DEVICES - 1)));
  for (const r of evict) {
    await env.DB.prepare('DELETE FROM user_devices WHERE user_id=? AND device_id=?')
      .bind(userId, r.device_id).run();
  }
  await env.DB.prepare(
    'INSERT INTO user_devices (user_id,device_id,label,created_at,last_seen) VALUES (?,?,?,?,?)'
  ).bind(userId, deviceId, label || '', now, now).run();
}

// Bearer token'dan kullanıcıyı doğrula → payload | null
export async function requireUser(request, env) {
  if (!env.AUTH_SECRET) return null;
  const auth = request.headers.get('Authorization') || '';
  const m = auth.match(/^Bearer\s+(.+)$/i);
  if (!m) return null;
  const payload = await verifyJWT(m[1], env.AUTH_SECRET);
  if (!payload) return null;
  await ensureSecCol(env);
  // Banlı kullanıcı → 'banned' sentineli (çağıran 403 döner; uygulama
  // "engellendiniz" gösterip oturumu kapatır). Banlanınca hiçbir authed istek geçmez.
  // ⚠️ Ban kontrolü cihaz kontrolünden ÖNCE: ban, user_devices kayıtlarını da
  // sildiği için aşağıdaki "did hâlâ kayıtlı mı" kontrolü null (401) döndürür ve
  // uygulamaya yanlışlıkla "başka cihazda açıldı (en fazla 2 cihaz)" mesajı
  // gösterirdi. Banlı kullanıcı net biçimde "engellendiniz" görsün diye en başta.
  const u = await env.DB.prepare('SELECT banned, sec_version FROM users WHERE id=?')
      .bind(payload.sub).first();
  if (!u) return null; // silinen/var-olmayan kullanıcı → token geçersiz
  if (u.banned) return 'banned';
  // Oturum iptali: şifre değişimi/reset/ban sec_version'ı artırır → eski token'lar
  // (düşük sv) burada düşer. Eski (sv'siz) token'lar 0 sayılır; ilk artışta düşer.
  if ((Number(payload.sv) || 0) !== (Number(u.sec_version) || 0)) return null;
  // En fazla 2 cihaz: token bir cihaza bağlıysa (did) o cihaz HÂLÂ kayıtlı olmalı.
  // Hesap başka cihazda açılınca bu cihaz düşürülür (did silinir) → burada 401.
  // Eski (did'siz) token'lar geriye dönük çalışır; yeniden girişte did kazanır.
  if (payload.did) {
    const dev = await env.DB.prepare(
      'SELECT device_id FROM user_devices WHERE user_id=? AND device_id=?'
    ).bind(payload.sub, payload.did).first();
    if (!dev) return null;
    await env.DB.prepare(
      'UPDATE user_devices SET last_seen=? WHERE user_id=? AND device_id=?'
    ).bind(Date.now(), payload.sub, payload.did).run();
  }
  return payload;
}

// 6 haneli sıfırlama kodu + SHA-256 hex (kod kısa ömürlü; bcrypt'e gerek yok).
function genCode() {
  return (crypto.getRandomValues(new Uint32Array(1))[0] % 1000000)
      .toString().padStart(6, '0');
}
async function sha256Hex(s) {
  const buf = await crypto.subtle.digest('SHA-256', enc.encode(s));
  return Array.from(new Uint8Array(buf))
      .map((b) => b.toString(16).padStart(2, '0')).join('');
}
// Resend ile e-posta gönder (RESEND_API_KEY secret'i gerekir; yoksa false).
async function sendResetEmail(env, email, code) {
  if (!env.RESEND_API_KEY) return false;
  try {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': 'Bearer ' + env.RESEND_API_KEY,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: env.RESEND_FROM || 'SELAYA <noreply@selaya.app>',
        to: [email],
        reply_to: env.ADMIN_EMAIL || 'alirza.krg@gmail.com',
        subject: 'SELAYA — Şifre Sıfırlama Kodu',
        html:
          '<div style="font-family:system-ui,Segoe UI,sans-serif;max-width:480px;margin:auto;padding:8px">' +
          '<h2 style="color:#b8860b;margin:0 0 8px">SELAYA · Şifre Sıfırlama</h2>' +
          '<p style="color:#333;margin:0 0 6px">Şifre sıfırlama kodun:</p>' +
          '<p style="font-size:30px;font-weight:800;letter-spacing:6px;color:#111;margin:8px 0">' + code + '</p>' +
          '<p style="color:#777;font-size:13px">Kod 15 dakika geçerli. Bu isteği sen yapmadıysan bu e-postayı yok say.</p></div>',
      }),
    });
    return res.ok;
  } catch (_) {
    return false;
  }
}

function escHtml(s) {
  return String(s == null ? '' : s)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}
// Yönetici bildirim e-postası (alirza.krg@gmail.com) — yeni üye / dua / şikayet.
// RESEND_API_KEY yoksa sessizce atlar. ctx.waitUntil ile çağrılır → ana isteği
// bloklamaz. [lines] DÜZ METİN (HTML kaçışı burada yapılır).
export async function notifyAdmin(env, subject, lines) {
  if (!env.RESEND_API_KEY) return false;
  const to = env.ADMIN_EMAIL || 'alirza.krg@gmail.com';
  try {
    const body = (Array.isArray(lines) ? lines : [lines])
      .map((l) => '<p style="margin:5px 0;color:#333">' + escHtml(l) + '</p>').join('');
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': 'Bearer ' + env.RESEND_API_KEY,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: env.RESEND_FROM || 'SELAYA <noreply@selaya.app>',
        to: [to],
        subject: 'SELAYA · ' + subject,
        html:
          '<div style="font-family:system-ui,Segoe UI,sans-serif;max-width:520px;margin:auto;padding:8px">' +
          '<h2 style="color:#b8860b;margin:0 0 10px">SELAYA — ' + escHtml(subject) + '</h2>' + body +
          '<p style="color:#999;font-size:12px;margin-top:14px">SELAYA yönetim bildirimi · panel.selaya.app</p></div>',
      }),
    });
    return res.ok;
  } catch (_) {
    return false;
  }
}

// Auth rotası ise Response döner, değilse null (index.js akışı devam etsin).
export async function handleAuth(request, env, path, ctx) {
  if (!path.startsWith('/v1/auth/') &&
      path !== '/v1/me' && path !== '/v1/me/data' && path !== '/v1/me/password' &&
      path !== '/v1/me/delete') {
    return null;
  }
  if (!env.AUTH_SECRET) return json({ ok: false, error: 'server_misconfig' }, 500);

  // Rate limit (IP başına) — yazma uçları PBKDF2/D1'e GİRMEDEN önce kesilir;
  // aksi halde rastgele-email login seli Worker CPU + D1 kotasını/faturasını
  // yakabilir. Binding yoksa (eski deploy) sessizce atlanır (fail-open).
  if (request.method === 'POST' && env.AUTH_RL &&
      (path === '/v1/auth/register' || path === '/v1/auth/login' ||
       path === '/v1/auth/forgot' || path === '/v1/auth/reset' ||
       path === '/v1/auth/google')) {
    const ip = request.headers.get('CF-Connecting-IP') || 'anon';
    const { success } = await env.AUTH_RL.limit({ key: 'auth:' + ip });
    if (!success) return json({ ok: false, error: 'too_many_attempts' }, 429);
  }
  await ensureSecCol(env); // oturum-iptali kolonu (register/reset için garanti)

  // ---- KAYIT ----
  if (request.method === 'POST' && path === '/v1/auth/register') {
    const b = await readJson(request);
    if (!b) return json({ ok: false, error: 'bad_body' }, 400);
    const name = (b.name || '').toString().trim();
    const surname = (b.surname || '').toString().trim();
    const email = (b.email || '').toString().trim().toLowerCase();
    const password = (b.password || '').toString();
    if (!name) return json({ ok: false, error: 'name_required' }, 400);
    // Ad/soyad küfür/hakaret içeremez (tüm kullanıcı girişlerinde koruma).
    if (containsProfanity(name) || (surname && containsProfanity(surname))) {
      return json({ ok: false, error: 'name_profanity' }, 400);
    }
    if (!validEmail(email)) return json({ ok: false, error: 'invalid_email' }, 400);
    if (!validPassword(password)) return json({ ok: false, error: 'weak_password' }, 400);
    // Rumuz ZORUNLU (kullanıcı 2026-06-18: kayıt olurken rumuz istensin) +
    // küfür/kutsal-isim/uzunluk denetimi.
    const rv = validateRumuz(b.rumuz);
    if (!rv.ok) return json({ ok: false, error: rv.error }, 400);
    const rumuz = rv.value;

    const exists = await env.DB.prepare('SELECT id FROM users WHERE email=?').bind(email).first();
    if (exists) return json({ ok: false, error: 'email_taken' }, 409);
    // Rumuz benzersiz olmalı (kimlik taklidi engeli — panel ile aynı kural).
    const rTaken = await env.DB.prepare('SELECT id FROM users WHERE rumuz=? COLLATE NOCASE')
        .bind(rumuz).first();
    if (rTaken) return json({ ok: false, error: 'rumuz_taken' }, 409);

    const { hash, salt, iters } = await hashPassword(password);
    const id = crypto.randomUUID();
    const now = Date.now();
    try {
      await env.DB.prepare(
        'INSERT INTO users (id,name,surname,email,rumuz,pass_hash,pass_salt,iters,email_verified,created_at,last_active) ' +
        'VALUES (?,?,?,?,?,?,?,?,0,?,?)'
      ).bind(id, name, surname, email, rumuz, hash, salt, iters, now, now).run();
    } catch (_) {
      // E-posta UNIQUE çakışması (eşzamanlı kayıt yarışı) → yine email_taken.
      return json({ ok: false, error: 'email_taken' }, 409);
    }
    await env.DB.prepare('INSERT INTO user_data (user_id,data,updated_at) VALUES (?,?,?)')
      .bind(id, '{}', now).run();

    const user = { id, name, surname, email, rumuz: rumuz || '' };
    const deviceId = (b.deviceId || '').toString().slice(0, 80);
    const deviceLabel = (b.device || '').toString().slice(0, 80);
    await registerDevice(env, id, deviceId, deviceLabel);
    // Yönetici e-postası GÖNDERİLMEZ (kullanıcı isteği): yeni üyeler panelde +
    // bildirim akışında (/api/activity) görünür.
    return json({ ok: true, token: await issueToken(env, user, deviceId), user });
  }

  // ---- GİRİŞ (5 hatalı denemede 15 dk hesap kilidi) ----
  if (request.method === 'POST' && path === '/v1/auth/login') {
    const b = await readJson(request);
    if (!b) return json({ ok: false, error: 'bad_body' }, 400);
    const email = (b.email || '').toString().trim().toLowerCase();
    const password = (b.password || '').toString();
    if (!validEmail(email) || !password) return json({ ok: false, error: 'invalid_credentials' }, 401);

    const u = await env.DB.prepare('SELECT * FROM users WHERE email=?').bind(email).first();
    // Sabit-zamanlı his: kullanıcı yoksa da bir hash hesapla (kullanıcı sayımı sızmasın).
    if (!u) { await hashPassword(password); return json({ ok: false, error: 'invalid_credentials' }, 401); }
    const now = Date.now();
    if ((u.locked_until || 0) > now) return json({ ok: false, error: 'too_many_attempts' }, 429);

    const ok = await verifyPassword(password, u.pass_salt, u.pass_hash, u.iters);
    if (!ok) {
      const attempts = (u.failed_attempts || 0) + 1;
      if (attempts >= 5) {
        await env.DB.prepare('UPDATE users SET failed_attempts=0, locked_until=? WHERE id=?')
          .bind(now + 15 * 60 * 1000, u.id).run();
      } else {
        await env.DB.prepare('UPDATE users SET failed_attempts=? WHERE id=?').bind(attempts, u.id).run();
      }
      return json({ ok: false, error: 'invalid_credentials' }, 401);
    }

    // Banlı kullanıcı giriş yapamaz (uygulama "engellendiniz" gösterir).
    if (u.banned) return json({ ok: false, error: 'banned' }, 403);

    await env.DB.prepare('UPDATE users SET last_active=?, failed_attempts=0, locked_until=0 WHERE id=?')
      .bind(now, u.id).run();
    const deviceId = (b.deviceId || '').toString().slice(0, 80);
    const deviceLabel = (b.device || '').toString().slice(0, 80);
    await registerDevice(env, u.id, deviceId, deviceLabel);
    return json({ ok: true, token: await issueToken(env, u, deviceId), user: publicUser(u) });
  }

  // ---- GOOGLE İLE GİRİŞ ----
  // Flutter google_sign_in idToken'ı Google'da DOĞRULANIR (tokeninfo: aud = Web
  // Client ID + email_verified). Mevcut e-posta → giriş (şifresiz). Yeni e-posta →
  // rumuz ZORUNLU (Dua Duvarı) → rumuz yoksa Flutter tek-seferlik adım gösterir.
  if (request.method === 'POST' && path === '/v1/auth/google') {
    const b = await readJson(request);
    if (!b) return json({ ok: false, error: 'bad_body' }, 400);
    const idToken = (b.idToken || '').toString();
    if (!idToken) return json({ ok: false, error: 'no_token' }, 400);
    let info;
    try {
      const r = await fetch(
        'https://oauth2.googleapis.com/tokeninfo?id_token=' +
          encodeURIComponent(idToken));
      if (!r.ok) return json({ ok: false, error: 'google_verify_failed' }, 401);
      info = await r.json();
    } catch (_) {
      return json({ ok: false, error: 'google_verify_failed' }, 401);
    }
    const expectedAud = (env.GOOGLE_WEB_CLIENT_ID || '').toString();
    if (!expectedAud || (info.aud || '').toString() !== expectedAud) {
      return json({ ok: false, error: 'google_aud_mismatch' }, 401);
    }
    if (String(info.email_verified) !== 'true') {
      return json({ ok: false, error: 'email_not_verified' }, 401);
    }
    // Güven sınırını kendi içinde tut (tokeninfo HTTP durumuna bel bağlama):
    // issuer Google olmalı + token süresi dolmamış olmalı (savunma derinliği).
    const gIss = (info.iss || '').toString();
    if (gIss !== 'accounts.google.com' && gIss !== 'https://accounts.google.com') {
      return json({ ok: false, error: 'google_verify_failed' }, 401);
    }
    if (!info.exp || Math.floor(Date.now() / 1000) >= Number(info.exp)) {
      return json({ ok: false, error: 'google_verify_failed' }, 401);
    }
    const email = (info.email || '').toString().trim().toLowerCase();
    if (!email) return json({ ok: false, error: 'no_email' }, 401);
    const now = Date.now();
    const deviceId = (b.deviceId || '').toString().slice(0, 80);
    const deviceLabel = (b.device || '').toString().slice(0, 80);

    // Mevcut kullanıcı → giriş (ban kontrolü; Google hesabı = şifresiz).
    const u = await env.DB.prepare('SELECT * FROM users WHERE email=?').bind(email).first();
    if (u) {
      if (u.banned) return json({ ok: false, error: 'banned' }, 403);
      await env.DB.prepare('UPDATE users SET last_active=? WHERE id=?').bind(now, u.id).run();
      await registerDevice(env, u.id, deviceId, deviceLabel);
      return json({ ok: true, token: await issueToken(env, u, deviceId), user: publicUser(u) });
    }

    // YENİ kullanıcı → rumuz ZORUNLU. Yoksa Flutter'a "rumuz seç" sinyali (200, ok:false).
    const rv = validateRumuz(b.rumuz);
    if (!rv.ok) {
      // Rumuz HİÇ verilmediyse → "rumuz seç" sinyali. Verildi ama geçersizse
      // (kısa/yasak karakter/küfür/kutsal) → spesifik kodu döndür ki Flutter
      // kullanıcıya NEDEN'ini gösterip tekrar sorabilsin (register ile parite).
      const supplied = (b.rumuz || '').toString().trim().length > 0;
      return json({
        ok: false, error: supplied ? rv.error : 'rumuz_required', detail: rv.error,
        email, name: (info.given_name || info.name || '').toString(),
      });
    }
    const rumuz = rv.value;
    const rTaken = await env.DB.prepare('SELECT id FROM users WHERE rumuz=? COLLATE NOCASE')
        .bind(rumuz).first();
    if (rTaken) return json({ ok: false, error: 'rumuz_taken' }, 409);
    const name = (info.given_name || info.name || 'Kullanıcı').toString().trim().slice(0, 60);
    const surname = (info.family_name || '').toString().trim().slice(0, 60);
    const id = crypto.randomUUID();
    try {
      await env.DB.prepare(
        'INSERT INTO users (id,name,surname,email,rumuz,pass_hash,pass_salt,iters,email_verified,created_at,last_active) ' +
        'VALUES (?,?,?,?,?,?,?,?,1,?,?)'
      ).bind(id, name, surname, email, rumuz, '', '', 0, now, now).run();
    } catch (_) {
      return json({ ok: false, error: 'email_taken' }, 409);
    }
    await env.DB.prepare('INSERT INTO user_data (user_id,data,updated_at) VALUES (?,?,?)')
      .bind(id, '{}', now).run();
    await registerDevice(env, id, deviceId, deviceLabel);
    const newUser = { id, name, surname, email, rumuz };
    return json({ ok: true, token: await issueToken(env, newUser, deviceId), user: newUser });
  }

  // ---- ŞİFREMİ UNUTTUM: e-postaya kod gönder ----
  if (request.method === 'POST' && path === '/v1/auth/forgot') {
    if (!env.RESEND_API_KEY) return json({ ok: false, error: 'email_not_configured' }, 503);
    const b = await readJson(request);
    if (!b) return json({ ok: false, error: 'bad_body' }, 400);
    const email = (b.email || '').toString().trim().toLowerCase();
    if (!validEmail(email)) return json({ ok: false, error: 'invalid_email' }, 400);
    const u = await env.DB.prepare('SELECT id FROM users WHERE email=?').bind(email).first();
    // Net geri bildirim (SELAYA banka değil): kayıt yoksa açıkça söyle, ilerleme.
    if (!u) return json({ ok: false, error: 'email_not_found' }, 404);
    const now = Date.now();
    // Kötüye-kullanım sınırı: kullanıcı başına GÜNDE en fazla 3 kod isteği.
    await ensureResetCols(env);
    const today = new Date(now).toISOString().slice(0, 10);
    const rc = await env.DB.prepare(
      'SELECT reset_count, reset_day FROM users WHERE id=?'
    ).bind(u.id).first();
    const usedToday =
      rc && rc.reset_day === today ? (Number(rc.reset_count) || 0) : 0;
    if (usedToday >= 3) {
      return json({ ok: false, error: 'too_many_resets' }, 429);
    }
    // Spam / e-posta kotası koruması: aynı hesaba 60 sn'de en fazla 1 kod.
    const recent = await env.DB.prepare(
      'SELECT created_at FROM auth_codes WHERE user_id=? AND kind=? ORDER BY created_at DESC LIMIT 1'
    ).bind(u.id, 'reset').first();
    if (recent && now - recent.created_at < 60000) {
      return json({ ok: false, error: 'too_soon' }, 429);
    }
    const code = genCode();
    await env.DB.prepare('DELETE FROM auth_codes WHERE user_id=? AND kind=?').bind(u.id, 'reset').run();
    await env.DB.prepare(
      'INSERT INTO auth_codes (id,user_id,kind,code_hash,expires_at,used,created_at) VALUES (?,?,?,?,?,0,?)'
    ).bind(crypto.randomUUID(), u.id, 'reset', await sha256Hex(code), now + 15 * 60 * 1000, now).run();
    const sent = await sendResetEmail(env, email, code);
    if (!sent) return json({ ok: false, error: 'email_send_failed' }, 502);
    // Başarıyla gönderildi → günlük sayaç artır (gün değişince ensure üstünde sıfırlanır).
    await env.DB.prepare('UPDATE users SET reset_count=?, reset_day=? WHERE id=?')
      .bind(usedToday + 1, today, u.id).run();
    return json({ ok: true });
  }

  // ---- ŞİFREMİ UNUTTUM: kodla yeni şifre ----
  if (request.method === 'POST' && path === '/v1/auth/reset') {
    const b = await readJson(request);
    if (!b) return json({ ok: false, error: 'bad_body' }, 400);
    const email = (b.email || '').toString().trim().toLowerCase();
    const code = (b.code || '').toString().trim();
    const newPw = (b.newPassword || '').toString();
    if (!validPassword(newPw)) return json({ ok: false, error: 'weak_password' }, 400);
    const u = await env.DB.prepare('SELECT id FROM users WHERE email=?').bind(email).first();
    if (!u) return json({ ok: false, error: 'invalid_code' }, 400);
    const row = await env.DB.prepare(
      'SELECT * FROM auth_codes WHERE user_id=? AND kind=? AND used=0 ORDER BY created_at DESC LIMIT 1'
    ).bind(u.id, 'reset').first();
    if (!row || row.expires_at < Date.now()) return json({ ok: false, error: 'invalid_code' }, 400);
    // Brute-force kilidi: 5 yanlış denemede kodu öldür (6 haneli kod tahmin edilemesin).
    if ((row.attempts || 0) >= 5) {
      await env.DB.prepare('UPDATE auth_codes SET used=1 WHERE id=?').bind(row.id).run();
      return json({ ok: false, error: 'invalid_code' }, 400);
    }
    if (row.code_hash !== (await sha256Hex(code))) {
      await env.DB.prepare('UPDATE auth_codes SET attempts=attempts+1 WHERE id=?').bind(row.id).run();
      return json({ ok: false, error: 'invalid_code' }, 400);
    }
    const np = await hashPassword(newPw);
    // sec_version++ → sıfırlama, ele geçirilmiş eski tüm oturumları geçersizler.
    await env.DB.prepare(
      'UPDATE users SET pass_hash=?, pass_salt=?, iters=?, failed_attempts=0, locked_until=0, sec_version=COALESCE(sec_version,0)+1 WHERE id=?'
    ).bind(np.hash, np.salt, np.iters, u.id).run();
    await env.DB.prepare('UPDATE auth_codes SET used=1 WHERE id=?').bind(row.id).run();
    return json({ ok: true });
  }

  // ---- PROFİL & VERİ (Bearer şart) ----
  if (path === '/v1/me' || path === '/v1/me/data' || path === '/v1/me/password' ||
      path === '/v1/me/delete') {
    const payload = await requireUser(request, env);
    if (payload === 'banned') return json({ ok: false, error: 'banned' }, 403);
    if (!payload) return json({ ok: false, error: 'unauthorized' }, 401);
    const uid = payload.sub;

    // ---- HESABI SİL (KVKK + Play): şifre teyitli, tüm kullanıcı verisini siler ----
    if (path === '/v1/me/delete' && request.method === 'POST') {
      const b = await readJson(request);
      const pw = ((b && b.password) || '').toString();
      const u = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(uid).first();
      if (!u) return json({ ok: false, error: 'not_found' }, 404);
      // Google hesapları şifresiz (pass_hash=''). Oturum (Bearer) zaten requireUser
      // ile doğrulandı → şifresiz hesapta parola teyidini atla (in-app silme Play/KVKK
      // gereği çalışsın); şifreli hesapta eskisi gibi parola teyidi şart.
      const hasPw = !!(u.pass_hash && u.pass_salt);
      if (hasPw && !(await verifyPassword(pw, u.pass_salt, u.pass_hash, u.iters))) {
        return json({ ok: false, error: 'wrong_password' }, 401);
      }
      // Yardımcı tablolar (özellik hiç kullanılmadıysa tablo olmayabilir →
      // tek tek dene, hatayı yut). hatim cüzleri serbest bırakılır.
      const aux = [
        'DELETE FROM user_devices WHERE user_id=?',
        'DELETE FROM dua_wall WHERE user_id=?',
        'DELETE FROM dua_amins WHERE user_id=?',   // FK CASCADE D1'de tetiklenmez → elle
        'DELETE FROM dua_reports WHERE user_id=?',
        'DELETE FROM quiz_scores WHERE user_id=?',
        'DELETE FROM auth_codes WHERE user_id=?',
        "UPDATE hatim_juz SET status='open', user_id=NULL, rumuz=NULL, claimed_at=NULL, done_at=NULL WHERE user_id=?",
      ];
      for (const sql of aux) {
        try { await env.DB.prepare(sql).bind(uid).run(); } catch (_) {}
      }
      // Çekirdek: bulut senkron verisi + hesap.
      await env.DB.prepare('DELETE FROM user_data WHERE user_id=?').bind(uid).run();
      await env.DB.prepare('DELETE FROM users WHERE id=?').bind(uid).run();
      return json({ ok: true });
    }

    // ---- ŞİFRE DEĞİŞTİR (girişli kullanıcı; eski şifre doğrulanır) ----
    if (path === '/v1/me/password' && request.method === 'POST') {
      const b = await readJson(request);
      if (!b) return json({ ok: false, error: 'bad_body' }, 400);
      const oldPw = (b.oldPassword || '').toString();
      const newPw = (b.newPassword || '').toString();
      if (!validPassword(newPw)) return json({ ok: false, error: 'weak_password' }, 400);
      const u = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(uid).first();
      if (!u) return json({ ok: false, error: 'not_found' }, 404);
      // Google hesabı (şifresiz) → ilk parolayı eski-parola teyidi olmadan kurabilsin.
      const hasPwd = !!(u.pass_hash && u.pass_salt);
      if (hasPwd && !(await verifyPassword(oldPw, u.pass_salt, u.pass_hash, u.iters))) {
        return json({ ok: false, error: 'wrong_password' }, 401);
      }
      const np = await hashPassword(newPw);
      // sec_version++ → diğer cihaz/oturumlardaki eski token'lar geçersiz olur.
      await env.DB
          .prepare('UPDATE users SET pass_hash=?, pass_salt=?, iters=?, sec_version=COALESCE(sec_version,0)+1 WHERE id=?')
          .bind(np.hash, np.salt, np.iters, uid).run();
      // BU cihazı düşürme: yeni sec_version'lı taze token ver (uygulama kaydeder).
      const fresh = await env.DB
          .prepare('SELECT email, sec_version FROM users WHERE id=?').bind(uid).first();
      const token = await issueToken(
          env, { id: uid, email: fresh.email, sec_version: fresh.sec_version }, payload.did);
      return json({ ok: true, token });
    }

    // ---- PROFİL GÜNCELLE (ad/soyad) ----
    if (path === '/v1/me' && request.method === 'PUT') {
      const b = await readJson(request);
      if (!b) return json({ ok: false, error: 'bad_body' }, 400);
      const name = (b.name || '').toString().trim();
      const surname = (b.surname || '').toString().trim();
      if (!name) return json({ ok: false, error: 'name_required' }, 400);
      await env.DB.prepare('UPDATE users SET name=?, surname=? WHERE id=?')
        .bind(name, surname, uid).run();
      const u = await env.DB
        .prepare('SELECT id,name,surname,email FROM users WHERE id=?').bind(uid).first();
      return json({ ok: true, user: u });
    }

    if (path === '/v1/me' && request.method === 'GET') {
      const u = await env.DB.prepare(
        'SELECT id,name,surname,email,rumuz,email_verified,created_at,last_active FROM users WHERE id=?'
      ).bind(uid).first();
      if (!u) return json({ ok: false, error: 'not_found' }, 404);
      return json({ ok: true, user: u });
    }

    if (path === '/v1/me/data' && request.method === 'GET') {
      const row = await env.DB.prepare('SELECT data, updated_at FROM user_data WHERE user_id=?').bind(uid).first();
      return json({ ok: true, data: row ? (safeParse(row.data) || {}) : {}, updated_at: row ? row.updated_at : 0 });
    }

    if (path === '/v1/me/data' && request.method === 'PUT') {
      const b = await readJson(request);
      if (!b || typeof b.data !== 'object' || b.data === null) return json({ ok: false, error: 'bad_body' }, 400);
      const dataStr = JSON.stringify(b.data);
      if (dataStr.length > 1024 * 1024) return json({ ok: false, error: 'too_large' }, 413); // 1 MB
      const device = (b.device || '').toString().slice(0, 80);
      const now = Date.now();
      await env.DB.prepare(
        'INSERT INTO user_data (user_id,data,device,updated_at) VALUES (?,?,?,?) ' +
        'ON CONFLICT(user_id) DO UPDATE SET data=excluded.data, device=excluded.device, updated_at=excluded.updated_at'
      ).bind(uid, dataStr, device, now).run();
      await env.DB.prepare('UPDATE users SET last_active=? WHERE id=?').bind(now, uid).run();
      return json({ ok: true, updated_at: now });
    }
  }

  return json({ ok: false, error: 'not_found' }, 404);
}
