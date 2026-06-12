// SELAYA üyelik & senkron — auth modülü (api.selaya.app).
// Uçlar:
//   POST /v1/auth/register {name, surname, email, password} -> {token, user}
//   POST /v1/auth/login    {email, password}                -> {token, user}
//   GET  /v1/me            (Bearer)                          -> {user}
//   GET  /v1/me/data       (Bearer)                          -> {data, updated_at}
//   PUT  /v1/me/data       (Bearer) {data:{}, device}        -> {updated_at}
// Şifreler PBKDF2-SHA256 + salt ile hash'lenir (düz metin SAKLANMAZ).
// Oturum = HMAC-SHA256 ile imzalı JWT (secret: env.AUTH_SECRET).

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

function timingSafeEqual(a, b) {
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

const TOKEN_TTL = 60 * 60 * 24 * 180; // 180 gün

async function issueToken(env, user) {
  const now = Math.floor(Date.now() / 1000);
  return signJWT({ sub: user.id, email: user.email, iat: now, exp: now + TOKEN_TTL }, env.AUTH_SECRET);
}

function publicUser(u) {
  return { id: u.id, name: u.name, surname: u.surname || '', email: u.email };
}

// Bearer token'dan kullanıcıyı doğrula → payload | null
export async function requireUser(request, env) {
  if (!env.AUTH_SECRET) return null;
  const auth = request.headers.get('Authorization') || '';
  const m = auth.match(/^Bearer\s+(.+)$/i);
  if (!m) return null;
  return verifyJWT(m[1], env.AUTH_SECRET);
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

// Auth rotası ise Response döner, değilse null (index.js akışı devam etsin).
export async function handleAuth(request, env, path) {
  if (!path.startsWith('/v1/auth/') &&
      path !== '/v1/me' && path !== '/v1/me/data' && path !== '/v1/me/password') {
    return null;
  }
  if (!env.AUTH_SECRET) return json({ ok: false, error: 'server_misconfig' }, 500);

  // ---- KAYIT ----
  if (request.method === 'POST' && path === '/v1/auth/register') {
    const b = await readJson(request);
    if (!b) return json({ ok: false, error: 'bad_body' }, 400);
    const name = (b.name || '').toString().trim();
    const surname = (b.surname || '').toString().trim();
    const email = (b.email || '').toString().trim().toLowerCase();
    const password = (b.password || '').toString();
    if (!name) return json({ ok: false, error: 'name_required' }, 400);
    if (!validEmail(email)) return json({ ok: false, error: 'invalid_email' }, 400);
    if (!validPassword(password)) return json({ ok: false, error: 'weak_password' }, 400);

    const exists = await env.DB.prepare('SELECT id FROM users WHERE email=?').bind(email).first();
    if (exists) return json({ ok: false, error: 'email_taken' }, 409);

    const { hash, salt, iters } = await hashPassword(password);
    const id = crypto.randomUUID();
    const now = Date.now();
    try {
      await env.DB.prepare(
        'INSERT INTO users (id,name,surname,email,pass_hash,pass_salt,iters,email_verified,created_at,last_active) ' +
        'VALUES (?,?,?,?,?,?,?,0,?,?)'
      ).bind(id, name, surname, email, hash, salt, iters, now, now).run();
    } catch (_) {
      // E-posta UNIQUE çakışması (eşzamanlı kayıt yarışı) → yine email_taken.
      return json({ ok: false, error: 'email_taken' }, 409);
    }
    await env.DB.prepare('INSERT INTO user_data (user_id,data,updated_at) VALUES (?,?,?)')
      .bind(id, '{}', now).run();

    const user = { id, name, surname, email };
    return json({ ok: true, token: await issueToken(env, user), user });
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

    await env.DB.prepare('UPDATE users SET last_active=?, failed_attempts=0, locked_until=0 WHERE id=?')
      .bind(now, u.id).run();
    return json({ ok: true, token: await issueToken(env, u), user: publicUser(u) });
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
    await env.DB.prepare(
      'UPDATE users SET pass_hash=?, pass_salt=?, iters=?, failed_attempts=0, locked_until=0 WHERE id=?'
    ).bind(np.hash, np.salt, np.iters, u.id).run();
    await env.DB.prepare('UPDATE auth_codes SET used=1 WHERE id=?').bind(row.id).run();
    return json({ ok: true });
  }

  // ---- PROFİL & VERİ (Bearer şart) ----
  if (path === '/v1/me' || path === '/v1/me/data' || path === '/v1/me/password') {
    const payload = await requireUser(request, env);
    if (!payload) return json({ ok: false, error: 'unauthorized' }, 401);
    const uid = payload.sub;

    // ---- ŞİFRE DEĞİŞTİR (girişli kullanıcı; eski şifre doğrulanır) ----
    if (path === '/v1/me/password' && request.method === 'POST') {
      const b = await readJson(request);
      if (!b) return json({ ok: false, error: 'bad_body' }, 400);
      const oldPw = (b.oldPassword || '').toString();
      const newPw = (b.newPassword || '').toString();
      if (!validPassword(newPw)) return json({ ok: false, error: 'weak_password' }, 400);
      const u = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(uid).first();
      if (!u) return json({ ok: false, error: 'not_found' }, 404);
      if (!(await verifyPassword(oldPw, u.pass_salt, u.pass_hash, u.iters))) {
        return json({ ok: false, error: 'wrong_password' }, 401);
      }
      const np = await hashPassword(newPw);
      await env.DB
          .prepare('UPDATE users SET pass_hash=?, pass_salt=?, iters=? WHERE id=?')
          .bind(np.hash, np.salt, np.iters, uid).run();
      return json({ ok: true });
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
        'SELECT id,name,surname,email,email_verified,created_at,last_active FROM users WHERE id=?'
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
