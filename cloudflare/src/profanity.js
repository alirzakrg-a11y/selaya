// SELAYA — küfür / hakaret filtresi (Dua Duvarı + rumuz için ortak guard).
// Amaç: APAÇIK küfürleri otomatik ilk elemeden geçirmek. İnsan moderasyonu
// (panel onayı) ASIL koruma; bu filtre bariz olanları en başta keser.
//
// TASARIM İLKESİ — yanlış-pozitiften kaçın: bir kullanıcının İÇTEN duasını
// yanlışlıkla engellemek, bir küfürü insana (panele) bırakmaktan daha kötüdür.
// Bu yüzden eşleşme KELİME bazlıdır (tüm metni sıkıştırıp substring aramak
// "akşamki namaz" → "amk", "anlamına" → "amına", "klasik" → "sik" gibi sahte
// pozitifler ürettiğinden KULLANILMAZ). Yaratıcı kaçırma ("s i k t i r") panele
// düşer; insan görür ve reddeder.
//
// Eşleşme modları (kelime normalize edildikten sonra):
//   EXACT   : kelime tam olarak eşit olmalı (çok kısa/baş harf kısaltmaları)
//   PREFIX  : kelime şununla BAŞLAMALI (çekimli küfürler: siktir, sikeyim…)
//   CONTAINS: kelimenin İÇİNDE geçmeli (yalnızca masum kelimede bulunamayacak
//             kadar uzun/benzersiz kökler)

// Kelime TAM eşit olmalı (kısaltmalar / tek başına küfür). "akşamki" gibi uzun
// kelimeler bunlardan biri OLMADIĞI için güvende.
const EXACT = new Set([
  'amk', 'amq', 'aq', 'mq', 'sg', 'oç', 'oc', 'aminako', 'amınako',
  'mal', // tek başına hakaret amaçlı; "malını" vb. kelimeler etkilenmez
  'göt', 'got', // tek başına kaba; "götür"/"göt第" KELİME bölünmesiyle etkilenmez
]);

// Kelime şununla BAŞLAMALI. (Bare "sik"/"göt" YOK — "sikke","götür","klasik",
// "kesik" gibi masum kelimeleri vurmasın diye yalnızca çekimli/birleşik formlar.)
const PREFIX = [
  'siktir', 'sikeyim', 'sikiyim', 'sikik', 'sikici', 'sikerim', 'sikim',
  'siker', 'sikti', 'sikiş', 'sikis', 'siksin', 'sikseydin',
  'amcık', 'amcik', 'amına', 'amınako', 'aminako',
  'orospu', 'oróspu', 'yarrak', 'yarak', 'pezevenk', 'pezevek',
  'kahpe', 'kahbe', 'kaltak', 'gavat', 'godoş', 'godos',
  'yavşak', 'yavsak', 'puşt', 'pust', 'ibne', 'ibina',
  'piç', 'şerefsiz', 'serefsiz', 'oç', 'göto', 'göty', 'götver', 'gotver',
];

// Kelimenin herhangi bir yerinde geçebilir (yalnızca uzun + benzersiz kökler).
const CONTAINS = [
  'orospu', 'pezevenk', 'siktir', 'sikeyim', 'amcık', 'amcik', 'yarrak',
  'piçkurusu', 'pickurusu', 'götveren', 'gotveren', 'götver', 'gotver',
  'şerefsiz', 'fuck', 'shit', 'bitch', 'asshole', 'cunt', 'pussy',
  'whore', 'nigger', 'faggot', 'motherf',
];

// ── Dini hakaret + kutsal isim koruması (kullanıcı 2026-06-18) ──────────────
// Kutsal kelime + (≤3 bağlaç harfi) + NET küfür kökü BİTİŞİK kaçırmasını yakalar
// ("allahasiktir", "dininesikeyim", "kuranaorospu"). Boşluklu hâli ("Allah'a
// siktir") zaten kelime bazlı küfür taramasında yakalanır. Kısa/çift-anlamlı
// kökler (sik/göt/bok) burada KULLANILMAZ ("din psikoloji" gibi sahte pozitif
// olmasın) → yalnız çekimli/uzun küfürler.
const BLASPHEMY_RE =
    /(allah|tanr[iı]|din|kur[a]?n|kitab|peygamber|islam|ilah|rab|mevla)[a-zçğıiöşü]{0,3}(siktir|sikeyim|sikiyim|sikik|sikici|sikim|orospu|amk|amq|kahpe|yarrak|yarak|pezevenk|g[oö]tver|ibne|pu[şs]t|piçkurusu)/;

// Rumuzda yasak — TAM eşleşme: Allah'ı/ilahlığı doğrudan çağrıştıran terimler.
// "Abdullah", "Allah'ın Kulu", "Kerim" gibi normal/itaatkâr adlar engellenmez.
const SACRED_EXACT = new Set([
  'allah', 'allahım', 'allahu', 'allahuteala', 'rab', 'rabbim', 'rabbimiz',
  'rabbena', 'tanrı', 'tanrım', 'ilah', 'ilahım', 'ilahi', 'mevla', 'mevlam',
  'yaradan', 'yaratan', 'yaratıcı', 'halık', 'hüda', 'hüdam', 'subhan',
  'sübhan', 'cenabıhak', 'cenabihak', 'peygamber', 'peygamberim',
  'resulullah', 'resulallah', 'nebiyullah', 'rabbül', 'zülcelal',
]);

// Esma-ül Hüsna (99) — yalnız "EL-/ER-/ES-…" tanım edatıyla (ilahî sıfat olarak)
// kullanılınca yasak; çıplak hâli (Kerim, Rahim, Aziz…) normal addır, serbesttir.
const ESMA = new Set([
  'rahman', 'rahim', 'melik', 'kuddüs', 'kuddus', 'selam', 'mümin', 'müheymin',
  'aziz', 'cebbar', 'mütekebbir', 'halık', 'halik', 'bari', 'musavvir',
  'gaffar', 'kahhar', 'vehhab', 'rezzak', 'fettah', 'alim', 'kabıd', 'basıt',
  'hafıd', 'rafi', 'muiz', 'müzil', 'semi', 'basir', 'hakem', 'adl', 'latif',
  'habir', 'halim', 'azim', 'gafur', 'şekur', 'sekur', 'kebir', 'hafız',
  'mukit', 'hasib', 'celil', 'kerim', 'rakib', 'mucib', 'vasi', 'hakim',
  'vedud', 'mecid', 'bais', 'şehid', 'sehid', 'vekil', 'kavi', 'metin', 'veli',
  'hamid', 'muhsi', 'mübdi', 'muid', 'muhyi', 'mümit', 'hayy', 'kayyum',
  'vacid', 'macid', 'vahid', 'ahad', 'samed', 'kadir', 'muktedir', 'mukaddim',
  'muahhir', 'evvel', 'ahir', 'zahir', 'batın', 'vali', 'müteali', 'berr',
  'tevvab', 'müntekim', 'afüvv', 'rauf', 'malik', 'muksit', 'cami', 'gani',
  'mugni', 'mani', 'darr', 'nafi', 'nur', 'hadi', 'bedi', 'baki', 'varis',
  'reşid', 'resid', 'sabur',
]);
const ARTICLES = ['el', 'er', 'es', 'eş', 'ez', 'en', 'ed', 'et', 'ül', 'ul'];

const LEET = { '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't', '@': 'a', '$': 's', '!': 'i', '|': 'i' };

// Görünmez karakterler (zero-width, BOM, yön işaretleri, soft-hyphen) — araya
// gizli karakter koyup filtreyi atlatmayı engelle ("a‍m‍k" → "amk").
function stripInvisible(s) {
  return s.replace(/[​-‏‪-‮⁠-⁤﻿­]/g, "");
}
// Benzer-görünümlü (homoglyph) Kiril/Yunan harfleri Latin'e indir → "Аllah"
// (baştaki Kiril А) gibi kutsal-isim/küfür kaçırmaları yakalanır.
const HOMOGLYPH = {
  'а': 'a', 'е': 'e', 'о': 'o', 'р': 'p', 'с': 'c', 'у': 'y', 'х': 'x', 'к': 'k',
  'м': 'm', 'н': 'h', 'т': 't', 'в': 'b', 'ѕ': 's', 'і': 'i', 'ј': 'j', 'ԁ': 'd',
  'α': 'a', 'ο': 'o', 'ε': 'e', 'ρ': 'p', 'τ': 't', 'υ': 'y', 'χ': 'x', 'κ': 'k',
  'ι': 'i', 'ν': 'v',
};
function mapHomoglyph(s) {
  let out = '';
  for (const ch of s) out += (HOMOGLYPH[ch] !== undefined ? HOMOGLYPH[ch] : ch);
  return out;
}

// Türkçe-duyarlı küçük harf (JS toLowerCase 'I'→'i' yapar; biz 'ı' isteriz).
function lowerTr(s) {
  return s.replace(/İ/g, 'i').replace(/I/g, 'ı').toLowerCase();
}
function mapLeet(s) {
  let out = '';
  for (const ch of s) out += (LEET[ch] !== undefined ? LEET[ch] : ch);
  return out;
}
// Tekrar eden harfleri tek/çift harfe indir ("siiiktir" → "siktir").
function collapseRepeats(s) { return s.replace(/(.)\1{2,}/g, '$1'); }

// Kelimeyi normalize et: leet + Türkçe küçük harf + sadece harf + tekrar daralt.
function normWord(w) {
  let s = mapHomoglyph(mapLeet(lowerTr(stripInvisible(w))));
  s = s.replace(/[^a-zçğıiöşü]/g, '');
  return collapseRepeats(s);
}

function wordIsProfane(n) {
  if (n.length < 2) return false;
  if (EXACT.has(n)) return true;
  for (const p of PREFIX) if (n.startsWith(p)) return true;
  for (const c of CONTAINS) if (n.includes(c)) return true;
  return false;
}

/**
 * Metinde apaçık küfür/hakaret var mı? (true = engelle)
 * Kelime bazlı; içten duaları yanlışlıkla engellememek için bilinçli olarak
 * temkinli. Yaratıcı kaçırmalar panel (insan) onayında yakalanır.
 */
export function containsProfanity(input) {
  if (!input || typeof input !== 'string') return false;
  const raw = stripInvisible(input.normalize('NFKC'));
  const words = raw.split(/[\s./\\_\-+,;:|()\[\]{}'"`~!?*<>@#]+/);
  for (const w of words) {
    if (wordIsProfane(normWord(w))) return true;
  }
  // Çok kısa, harf-arası ayraçla kaçırılmış kısaltmalar ("a.q", "a m k", "o.ç"):
  // TÜM mesaj sıkıştırılmış hâliyle ≤5 harfse ve bir baş-harf kısaltmasına
  // eşitse engelle. Yalnızca mesajın TAMAMI bir kısaltmadan ibaretse tetiklenir
  // → "akşamki namaz" gibi uzun metinler asla yakalanmaz (sahte pozitif yok).
  const squeezed = collapseRepeats(mapHomoglyph(mapLeet(lowerTr(raw))).replace(/[^a-zçğıiöşü]/g, ''));
  if (squeezed.length <= 5 && EXACT.has(squeezed)) return true;
  // Dini hakaret: kutsal kelime + bitişik küfür ("allahasiktir", "dininesik...").
  if (BLASPHEMY_RE.test(squeezed)) return true;
  return false;
}

/// Rumuz kutsal bir ismi/ilahlığı doğrudan çağrıştırıyor mu? (TAM eşleşme +
/// EL-/ER- edatlı Esma). "Abdullah", "Allah'ın Kulu", "Kerim" engellenmez.
function isSacredRumuz(raw) {
  const n = mapHomoglyph(mapLeet(lowerTr(stripInvisible(raw)))).replace(/[^a-zçğıiöşü]/g, '');
  if (n.length < 2) return false;
  // KATI (kullanıcı 2026-06-18): "Allah/Tanrı geçen her şeyi engelle".
  if (n.includes('allah') || n.includes('tanrı') || n.includes('tanri')) {
    return true;
  }
  if (SACRED_EXACT.has(n)) return true;
  for (const a of ARTICLES) {
    if (n.startsWith(a) && ESMA.has(n.slice(a.length))) return true;
  }
  return false;
}

/**
 * Rumuz (takma ad) geçerli mi? Küfür içermemeli + uzunluk/karakter kuralları.
 * Döner: { ok:true, value } | { ok:false, error:'...' }
 */
export function validateRumuz(input) {
  const r = (input || '').toString().trim();
  if (r.length < 2 || r.length > 24) return { ok: false, error: 'rumuz_length' };
  // Harf/rakam/boşluk/altçizgi/nokta/kesme(') — link/etiket/özel karakter yok.
  if (!/^[\p{L}0-9 ._'’ʼ]+$/u.test(r)) return { ok: false, error: 'rumuz_chars' };
  if (containsProfanity(r)) return { ok: false, error: 'rumuz_profanity' };
  // Allah'ın/ilahın isimleri rumuz olarak kullanılamaz (dine saygı).
  if (isSacredRumuz(r)) return { ok: false, error: 'rumuz_sacred' };
  return { ok: true, value: r };
}
