// Google Play, hesap silme için herkese açık bir URL ister (uygulama içi silme
// olsa bile). api.selaya.app/delete-account bunu karşılar. TR + EN.
export const DELETE_ACCOUNT_HTML = `<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Hesap & Veri Silme — SELAYA</title>
<style>
  body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;
    max-width:760px;margin:0 auto;padding:28px 20px;line-height:1.65;color:#1a1f29;background:#fff}
  h1{font-size:24px;margin:0 0 4px} h2{font-size:18px;margin:26px 0 8px}
  .muted{color:#667085;font-size:14px} ul{padding-left:22px} li{margin:5px 0}
  .box{background:#f6f7f9;border:1px solid #e6e8ec;border-radius:12px;padding:16px 18px;margin:14px 0}
  a{color:#b8860b} hr{border:none;border-top:1px solid #e6e8ec;margin:28px 0}
  code{background:#f0f1f3;padding:1px 6px;border-radius:5px;font-size:13px}
</style>
</head>
<body>
<h1>Hesap ve Veri Silme</h1>
<p class="muted">SELAYA · Karga Dijital — Güncelleme: 2026</p>

<p>SELAYA hesabını ve hesabına bağlı tüm verileri istediğin zaman silebilirsin. İki yol vardır:</p>

<h2>1) Uygulama içinden (anında)</h2>
<div class="box">
<ul>
  <li>SELAYA'yı aç → <b>Hesap</b> (profil) ekranına gir</li>
  <li><b>Hesabı Sil</b>'e dokun → onayla</li>
  <li>Hesabın ve aşağıdaki tüm verilerin <b>kalıcı olarak</b> silinir</li>
</ul>
</div>

<h2>2) E-posta ile</h2>
<p>Uygulamaya erişemiyorsan, kayıtlı e-posta adresinden
<a href="mailto:contact@selaya.app">contact@selaya.app</a> adresine "Hesap silme talebi" konulu bir e-posta gönder.
Talebin <b>en geç 30 gün</b> içinde işlenir.</p>

<hr>

<h2>Silinen veriler</h2>
<ul>
  <li>Hesap bilgilerin: ad, soyad, e-posta adresi, rumuz</li>
  <li>Buluta yedeklenen ayarların (bildirim/ezan tercihleri, hesaplama yöntemi, okuma ilerlemen)</li>
  <li>Dua Duvarı paylaşımların ve "âmin"lerin</li>
  <li>İçerik beğenilerin ve uygulama etkileşim kayıtların</li>
  <li>Cihaz oturum kayıtların</li>
</ul>
<p class="muted">Not: Cihazında yerel tutulan veriler (örn. kadınlara özel takip) zaten yalnızca senin cihazındadır ve buluta gönderilmez; uygulamayı kaldırınca silinir.</p>

<h2>Saklama süresi</h2>
<p>Hesap silindiğinde verilerin sunuculardan <b>anında</b> kaldırılır. Yedeklerde kalan kopyalar
en geç <b>30 gün</b> içinde tamamen silinir. Yasal yükümlülük gerektirmedikçe veri saklanmaz.</p>

<hr>
<h2 style="color:#667085;font-weight:600">English summary</h2>
<p class="muted">To delete your SELAYA account and all associated data: open the app → <b>Account</b> → <b>Delete Account</b> → confirm (immediate). Or email <a href="mailto:contact@selaya.app">contact@selaya.app</a> from your registered address (processed within 30 days). Deleted data: name, email, nickname, cloud-synced settings, prayer-wall posts &amp; reactions, likes, device sessions. Server data is removed immediately; backup copies within 30 days. On-device-only data (e.g. women's tracking) never leaves your device and is removed when you uninstall.</p>

<p style="margin-top:26px"><a href="https://api.selaya.app/privacy">Gizlilik Politikası →</a></p>
</body>
</html>`;

export function handleDeleteAccount(request, path) {
  if (path === '/delete-account' || path === '/account-deletion') {
    return new Response(DELETE_ACCOUNT_HTML, {
      headers: {
        'Content-Type': 'text/html; charset=utf-8',
        'Cache-Control': 'public, max-age=3600',
      },
    });
  }
  return null;
}
