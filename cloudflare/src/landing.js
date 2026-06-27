// selaya.app kök (+ www) → tanıtım/landing sayfası. Worker tarafından servis
// edilir (api./panel. ile aynı Worker, kök host). Statik, bağımlılıksız → hızlı
// + CWV dostu. "Google Play'den İndir" butonu uygulama yayınlanınca bağlanacak.
export const LANDING_HTML = `<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SELAYA — Kur'an, Namaz Vakitleri ve İslami Yaşam Uygulaması</title>
<meta name="description" content="SELAYA; Kur'an-ı Kerim (meal + sesli okuma), Diyanet namaz vakitleri, kıble, dua duvarı, zikirmatik, İslami takvim ve daha fazlasını tek uygulamada sunar. Reklamsız, 10 dil.">
<meta name="theme-color" content="#05070d">
<link rel="canonical" href="https://selaya.app/">
<meta property="og:type" content="website">
<meta property="og:title" content="SELAYA — Kur'an, Namaz Vakitleri ve İslami Yaşam">
<meta property="og:description" content="Kur'an, namaz vakitleri, kıble, dua duvarı, zikirmatik ve daha fazlası — tek uygulamada, reklamsız.">
<meta property="og:url" content="https://selaya.app/">
<meta property="og:image" content="https://cdn.selaya.app/og.png">
<meta name="twitter:card" content="summary_large_image">
<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E%3Ctext y='26' font-size='26'%3E%E2%97%8D%3C/text%3E%3C/svg%3E">
<script type="application/ld+json">
{"@context":"https://schema.org","@type":"MobileApplication","name":"SELAYA","operatingSystem":"Android","applicationCategory":"LifestyleApplication","offers":{"@type":"Offer","price":"0","priceCurrency":"TRY"},"description":"Kur'an-ı Kerim, namaz vakitleri, kıble, dua duvarı, zikirmatik ve İslami takvim uygulaması.","publisher":{"@type":"Organization","name":"Karga Dijital","url":"https://kargadijital.com"}}
</script>
<style>
  :root{
    --bg:#05070d; --bg2:#0a0e17; --card:#0e1320; --line:rgba(212,175,110,.16);
    --gold:#d4af6e; --gold2:#e9cf9b; --txt:#f1ece1; --mut:#9aa3b2;
  }
  *{box-sizing:border-box;margin:0;padding:0}
  html{scroll-behavior:smooth}
  body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,system-ui,sans-serif;
    background:var(--bg);color:var(--txt);line-height:1.6;-webkit-font-smoothing:antialiased;overflow-x:hidden}
  a{color:inherit;text-decoration:none}
  .wrap{max-width:1080px;margin:0 auto;padding:0 22px}
  .gold{color:var(--gold)}
  /* üst bar */
  header{position:sticky;top:0;z-index:10;backdrop-filter:blur(10px);
    background:rgba(5,7,13,.7);border-bottom:1px solid var(--line)}
  .nav{display:flex;align-items:center;gap:14px;padding:14px 22px;max-width:1080px;margin:0 auto}
  .brand{font-weight:800;font-size:20px;letter-spacing:.5px;flex:1}
  .brand span{color:var(--gold)}
  .nav a.lnk{color:var(--mut);font-size:14px;font-weight:600}
  .nav a.lnk:hover{color:var(--txt)}
  @media(max-width:640px){.nav a.lnk{display:none}}
  /* hero */
  .hero{position:relative;text-align:center;padding:84px 0 64px;
    background:radial-gradient(1200px 480px at 50% -10%,rgba(212,175,110,.14),transparent 70%)}
  .logo{font-size:64px;line-height:1}
  .hero h1{font-size:clamp(30px,6vw,52px);font-weight:800;letter-spacing:1px;margin:14px 0 6px}
  .hero h1 span{background:linear-gradient(120deg,var(--gold),var(--gold2));-webkit-background-clip:text;background-clip:text;color:transparent}
  .hero p{color:var(--mut);font-size:clamp(15px,2.4vw,19px);max-width:620px;margin:8px auto 0}
  .cta{display:flex;gap:12px;justify-content:center;flex-wrap:wrap;margin-top:30px}
  .badge{display:inline-flex;align-items:center;gap:10px;padding:13px 22px;border-radius:14px;
    font-weight:700;font-size:15px;border:1px solid var(--line)}
  .badge.soon{background:linear-gradient(120deg,var(--gold),var(--gold2));color:#1a1206;border:none}
  .badge.ghost{background:var(--card);color:var(--txt)}
  .badge small{display:block;font-size:11px;font-weight:600;opacity:.8}
  /* bölümler */
  section{padding:64px 0}
  .eyebrow{color:var(--gold);font-weight:700;font-size:13px;letter-spacing:1.5px;text-transform:uppercase;text-align:center}
  h2{font-size:clamp(24px,4vw,34px);font-weight:800;text-align:center;margin:8px 0 8px}
  .sub{color:var(--mut);text-align:center;max-width:560px;margin:0 auto 38px}
  .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:16px}
  .feat{background:var(--card);border:1px solid var(--line);border-radius:18px;padding:22px}
  .feat .ic{font-size:30px}
  .feat h3{font-size:17px;margin:12px 0 6px;font-weight:700}
  .feat p{color:var(--mut);font-size:14px}
  /* şerit istatistik */
  .strip{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:14px;
    background:var(--bg2);border:1px solid var(--line);border-radius:20px;padding:26px}
  .strip div{text-align:center}
  .strip b{display:block;font-size:28px;font-weight:800;color:var(--gold)}
  .strip span{color:var(--mut);font-size:13px}
  /* kapanış */
  .closing{text-align:center;background:radial-gradient(900px 360px at 50% 120%,rgba(212,175,110,.12),transparent 70%)}
  /* footer */
  footer{border-top:1px solid var(--line);padding:34px 0;color:var(--mut);font-size:13px}
  .frow{display:flex;gap:18px;flex-wrap:wrap;align-items:center;justify-content:space-between}
  footer a{color:var(--mut)} footer a:hover{color:var(--gold)}
  .fl{display:flex;gap:18px;flex-wrap:wrap}
</style>
</head>
<body>
<header><div class="nav">
  <div class="brand"><span>◍</span> SELAYA</div>
  <a class="lnk" href="#ozellikler">Özellikler</a>
  <a class="lnk" href="#indir">İndir</a>
  <a class="lnk" href="https://api.selaya.app/privacy">Gizlilik</a>
</div></header>

<main>
  <section class="hero">
    <div class="wrap">
      <div class="logo">◍</div>
      <h1>Maneviyatın <span>tek</span> uygulamada</h1>
      <p>Kur'an-ı Kerim, namaz vakitleri, kıble, dua duvarı, zikirmatik ve daha fazlası — sade, reklamsız ve 10 dilde.</p>
      <div class="cta" id="indir">
        <span class="badge soon">▶ Yakında Google Play'de<small>Çok yakında yayında</small></span>
        <a class="badge ghost" href="#ozellikler">Özellikleri keşfet</a>
      </div>
    </div>
  </section>

  <section id="ozellikler">
    <div class="wrap">
      <div class="eyebrow">Neler var</div>
      <h2>İhtiyacın olan her şey</h2>
      <p class="sub">Günlük ibadet hayatını kolaylaştıran, özenle hazırlanmış araçlar.</p>
      <div class="grid">
        <div class="feat"><div class="ic">📖</div><h3>Kur'an-ı Kerim</h3><p>Mushaf görünümü, sesli okuma ve 9 dilde yetkili meal. Sure favorileri, arama, okuma planı.</p></div>
        <div class="feat"><div class="ic">🕌</div><h3>Namaz Vakitleri</h3><p>Diyanet hesabı, ezan bildirimleri, vakit geri sayımı ve imsakiye.</p></div>
        <div class="feat"><div class="ic">🧭</div><h3>Kıble Pusulası</h3><p>Bulunduğun yerden Kâbe yönünü hassas biçimde göster.</p></div>
        <div class="feat"><div class="ic">🤲</div><h3>Dua Duvarı</h3><p>Dualarını toplulukla paylaş, başkalarının duasına "âmin" de.</p></div>
        <div class="feat"><div class="ic">📿</div><h3>Zikirmatik & Tesbihat</h3><p>Dijital tesbih, namaz sonrası tesbihat ve günlük zikir takibi.</p></div>
        <div class="feat"><div class="ic">🗓️</div><h3>İslami Takvim</h3><p>Kandiller, mübarek günler, geri sayım ve her günün anlamı.</p></div>
        <div class="feat"><div class="ic">📚</div><h3>Rehberler</h3><p>İlmihal, abdest & namaz rehberi, Hac & Umre, seyahat modu.</p></div>
        <div class="feat"><div class="ic">🌙</div><h3>Ramazan</h3><p>İmsakiye, oruç takibi, mukabele ve Ramazan'a özel akış.</p></div>
        <div class="feat"><div class="ic">🖼️</div><h3>İslami Duvar Kâğıtları</h3><p>Özenle seçilmiş arka planlar — telefonun her gün ilham versin.</p></div>
      </div>
    </div>
  </section>

  <section>
    <div class="wrap">
      <div class="strip">
        <div><b>10</b><span>Dil desteği</span></div>
        <div><b>9</b><span>Dilde Kur'an meali</span></div>
        <div><b>0₺</b><span>Reklamsız & ücretsiz</span></div>
        <div><b>∞</b><span>Maneviyat</span></div>
      </div>
    </div>
  </section>

  <section class="closing">
    <div class="wrap">
      <div class="eyebrow">Hazır mısın?</div>
      <h2>SELAYA çok yakında</h2>
      <p class="sub">Uygulama yayınlandığında buradan indirebileceksin. Sorularını <a class="gold" href="mailto:contact@selaya.app">contact@selaya.app</a> adresine yazabilirsin.</p>
      <div class="cta"><span class="badge soon">▶ Yakında Google Play'de</span></div>
    </div>
  </section>
</main>

<footer><div class="wrap frow">
  <div>© <span id="y">2026</span> <a href="https://kargadijital.com">Karga Dijital</a> — SELAYA</div>
  <div class="fl">
    <a href="https://api.selaya.app/privacy">Gizlilik Politikası</a>
    <a href="mailto:contact@selaya.app">İletişim</a>
  </div>
</div></footer>
<script>document.getElementById('y').textContent=new Date().getFullYear();</script>
</body>
</html>`;
