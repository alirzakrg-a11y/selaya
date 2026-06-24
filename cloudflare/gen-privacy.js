// store/privacy-policy.html -> src/privacy.js (Worker'da /privacy servis eder).
// Politikayı düzenleyince: store/privacy-policy.html'i güncelle + bunu tekrar çalıştır.
const fs = require('fs');
const html = fs.readFileSync(__dirname + '/../store/privacy-policy.html', 'utf8');
// Template-literal kaçışı: ters-eğik, backtick ve ${...}
const esc = html.replace(/\\/g, '\\\\').replace(/`/g, '\\`').replace(/\$\{/g, '\\${');
const out =
  '// OTOMATİK ÜRETİLDİ — elle düzenleme. Kaynak: store/privacy-policy.html\n' +
  '// Güncellemek için: node cloudflare/gen-privacy.js\n' +
  'export const PRIVACY_HTML = `' + esc + '`;\n\n' +
  'export function handlePrivacy(request, path) {\n' +
  "  if (request.method === 'GET' && path === '/privacy') {\n" +
  '    return new Response(PRIVACY_HTML, {\n' +
  "      headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'public, max-age=3600' },\n" +
  '    });\n' +
  '  }\n' +
  '  return null;\n' +
  '}\n';
fs.writeFileSync(__dirname + '/src/privacy.js', out, 'utf8');
console.log('src/privacy.js üretildi (' + html.length + ' karakter HTML)');
