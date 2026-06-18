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

const LEET = { '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't', '@': 'a', '$': 's', '!': 'i', '|': 'i' };

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
  let s = mapLeet(lowerTr(w));
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
  const raw = input.normalize('NFKC');
  const words = raw.split(/[\s./\\_\-+,;:|()\[\]{}'"`~!?*<>@#]+/);
  for (const w of words) {
    if (wordIsProfane(normWord(w))) return true;
  }
  // Çok kısa, harf-arası ayraçla kaçırılmış kısaltmalar ("a.q", "a m k", "o.ç"):
  // TÜM mesaj sıkıştırılmış hâliyle ≤5 harfse ve bir baş-harf kısaltmasına
  // eşitse engelle. Yalnızca mesajın TAMAMI bir kısaltmadan ibaretse tetiklenir
  // → "akşamki namaz" gibi uzun metinler asla yakalanmaz (sahte pozitif yok).
  const squeezed = collapseRepeats(mapLeet(lowerTr(raw)).replace(/[^a-zçğıiöşü]/g, ''));
  if (squeezed.length <= 5 && EXACT.has(squeezed)) return true;
  return false;
}

/**
 * Rumuz (takma ad) geçerli mi? Küfür içermemeli + uzunluk/karakter kuralları.
 * Döner: { ok:true, value } | { ok:false, error:'...' }
 */
export function validateRumuz(input) {
  const r = (input || '').toString().trim();
  if (r.length < 2 || r.length > 24) return { ok: false, error: 'rumuz_length' };
  // Harf/rakam/boşluk/altçizgi/nokta — link/etiket/özel karakter yok.
  if (!/^[\p{L}0-9 ._]+$/u.test(r)) return { ok: false, error: 'rumuz_chars' };
  if (containsProfanity(r)) return { ok: false, error: 'rumuz_profanity' };
  return { ok: true, value: r };
}
