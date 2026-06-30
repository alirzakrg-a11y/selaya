// Google Play satın-alma SUNUCU-TARAFLI DOĞRULAMA.
// Service account JWT (RS256) → OAuth2 access token → Android Publisher API.
//
// Worker secret'ları (ikisinden biri):
//   GOOGLE_SA_JSON         — servis hesabı JSON'unun TAMAMI (en kolayı)
//   ya da
//   GOOGLE_SA_EMAIL        — client_email
//   GOOGLE_SA_PRIVATE_KEY  — private_key (PEM; \n'ler korunmuş veya \\n kaçışlı)
//
// Servis hesabının Play Console'da uygulamaya erişimi + "finansal veri görüntüle"
// izni olmalı. Secret'lar yoksa verifyPlayPurchase çağrılmaz (auth.js stopgap).

const TOKEN_URL = 'https://oauth2.googleapis.com/token';
const SCOPE = 'https://www.googleapis.com/auth/androidpublisher';

// Bilinen SKU'lar — PremiumIds (Flutter) ile AYNI olmalı.
const SUBS = new Set(['selaya_premium_monthly', 'selaya_premium_yearly']);
const PRODUCTS = new Set(['selaya_premium_lifetime']);

let _cachedToken = null; // { token, expMs } — isolate ömrü boyunca yeniden kullan

function b64url(bytes) {
  let s = '';
  const u8 = new Uint8Array(bytes);
  for (let i = 0; i < u8.length; i++) s += String.fromCharCode(u8[i]);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
function b64urlStr(str) {
  return b64url(new TextEncoder().encode(str));
}

function saCreds(env) {
  if (env.GOOGLE_SA_JSON) {
    const j = JSON.parse(env.GOOGLE_SA_JSON);
    return { email: j.client_email, key: j.private_key };
  }
  return {
    email: env.GOOGLE_SA_EMAIL,
    key: (env.GOOGLE_SA_PRIVATE_KEY || '').replace(/\\n/g, '\n'),
  };
}

// PEM (PKCS8) private key → CryptoKey (RS256 imzalama için).
async function importKey(pem) {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    'pkcs8',
    der.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

// Servis hesabı için OAuth2 access token al (1 saat; cache'lenir).
async function getAccessToken(env, nowMs) {
  if (_cachedToken && _cachedToken.expMs > nowMs + 60_000) return _cachedToken.token;
  const { email, key } = saCreds(env);
  if (!email || !key) throw new Error('sa_missing');
  const iat = Math.floor(nowMs / 1000);
  const exp = iat + 3600;
  const unsigned =
    b64urlStr(JSON.stringify({ alg: 'RS256', typ: 'JWT' })) +
    '.' +
    b64urlStr(JSON.stringify({ iss: email, scope: SCOPE, aud: TOKEN_URL, iat, exp }));
  const cryptoKey = await importKey(key);
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(unsigned),
  );
  const jwt = unsigned + '.' + b64url(sig);
  const res = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body:
      'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=' +
      encodeURIComponent(jwt),
  });
  const d = await res.json().catch(() => ({}));
  if (!res.ok || !d.access_token) {
    throw new Error('token_fail:' + (d.error || res.status));
  }
  _cachedToken = { token: d.access_token, expMs: nowMs + (d.expires_in || 3600) * 1000 };
  return _cachedToken.token;
}

// Satın almayı DOĞRULA. Dönüş:
//   { ok:true,  expiryMs }  → geçerli/aktif (premium ver; lifetime'da expiryMs=0)
//   { ok:false, reason }    → reddet
export async function verifyPlayPurchase(env, { packageName, productId, purchaseToken }, nowMs) {
  if (!packageName || !productId || !purchaseToken) {
    return { ok: false, reason: 'missing_fields' };
  }
  const isSub = SUBS.has(productId);
  const isProd = PRODUCTS.has(productId);
  if (!isSub && !isProd) return { ok: false, reason: 'unknown_product' };

  let token;
  try {
    token = await getAccessToken(env, nowMs);
  } catch (e) {
    return { ok: false, reason: 'auth:' + (e && e.message ? e.message : 'err') };
  }

  const base =
    'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/' +
    encodeURIComponent(packageName) +
    '/purchases';
  const url = isSub
    ? base +
      '/subscriptions/' +
      encodeURIComponent(productId) +
      '/tokens/' +
      encodeURIComponent(purchaseToken)
    : base +
      '/products/' +
      encodeURIComponent(productId) +
      '/tokens/' +
      encodeURIComponent(purchaseToken);

  let res, d;
  try {
    res = await fetch(url, { headers: { Authorization: 'Bearer ' + token } });
    d = await res.json().catch(() => ({}));
  } catch (_) {
    return { ok: false, reason: 'api_fetch' };
  }
  if (!res.ok) {
    return { ok: false, reason: 'api:' + ((d.error && d.error.status) || res.status) };
  }

  if (isSub) {
    // subscriptions.get: expiryTimeMillis + paymentState (0=pending,1=received).
    // İptal edilse bile expiry'ye kadar geçerli.
    const expiry = parseInt(d.expiryTimeMillis || '0', 10);
    if (!expiry || expiry < nowMs) return { ok: false, reason: 'expired' };
    if (d.paymentState === 0) return { ok: false, reason: 'payment_pending' };
    return { ok: true, expiryMs: expiry };
  }
  // products.get: purchaseState 0=purchased, 1=canceled, 2=pending.
  if (d.purchaseState !== 0) return { ok: false, reason: 'state:' + d.purchaseState };
  return { ok: true, expiryMs: 0 }; // lifetime → süresiz
}
