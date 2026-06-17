-- SELAYA üyelik & senkron tabloları (D1: selaya-content)
-- Şifreler PBKDF2-SHA256 + salt ile hash'lenir; düz metin saklanmaz.

CREATE TABLE IF NOT EXISTS users (
  id             TEXT PRIMARY KEY,
  name           TEXT NOT NULL,                 -- ad
  surname        TEXT,                          -- soyad
  email          TEXT NOT NULL UNIQUE,
  pass_hash      TEXT NOT NULL,                 -- base64 PBKDF2 türev
  pass_salt      TEXT NOT NULL,                 -- base64 salt
  iters          INTEGER NOT NULL DEFAULT 100000,
  email_verified INTEGER NOT NULL DEFAULT 0,
  created_at     INTEGER NOT NULL DEFAULT 0,
  last_active    INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- Kullanıcının buluta yedeklenen verisi (tek JSON blob; son-yazan kazanır).
CREATE TABLE IF NOT EXISTS user_data (
  user_id     TEXT PRIMARY KEY,
  data        TEXT NOT NULL DEFAULT '{}',
  device      TEXT,                             -- son senkronlayan cihaz etiketi
  updated_at  INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Şifre sıfırlama / e-posta doğrulama kodları (Faz 5 — Resend ile e-posta).
CREATE TABLE IF NOT EXISTS auth_codes (
  id          TEXT PRIMARY KEY,
  user_id     TEXT NOT NULL,
  kind        TEXT NOT NULL,                    -- reset | verify
  code_hash   TEXT NOT NULL,                    -- kod base64 hash
  expires_at  INTEGER NOT NULL,
  used        INTEGER NOT NULL DEFAULT 0,
  created_at  INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_authcodes_user ON auth_codes(user_id, kind);

-- En fazla 2 aktif cihaz (kullanıcı 2026-06-17): her kullanıcının kayıtlı
-- cihazları (kalıcı device_id). Hesap 3. cihazda açılınca EN ESKİ (last_seen)
-- cihaz silinir → o cihazın token'ı sonraki istekte 401 olur (sessionRevoked).
CREATE TABLE IF NOT EXISTS user_devices (
  user_id    TEXT NOT NULL,
  device_id  TEXT NOT NULL,
  label      TEXT,
  created_at INTEGER NOT NULL DEFAULT 0,
  last_seen  INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, device_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_user_devices_user ON user_devices(user_id, last_seen);
