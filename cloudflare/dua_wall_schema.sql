-- SELAYA — Dua Duvarı (#10) şeması. TAMAMEN EK (mevcut tabloları bozmaz):
--   • users.rumuz  : kullanıcının takma adı (dua duvarında görünen ad)
--   • dua_wall     : gönderilen dualar (pending/approved/rejected)
--   • dua_amins    : "Âmin" tekrarını kullanıcı başına 1'e indiren dedup tablosu
-- Güvenlik: yalnızca üyeler yazar (user_id), küfür filtresi + panel onayı,
-- kullanıcı başına bekleyen sınırı + hız limiti (Worker tarafında).

-- rumuz kolonu (SQLite: IF NOT EXISTS yok → migration'da hata yutulur).
ALTER TABLE users ADD COLUMN rumuz TEXT;

CREATE TABLE IF NOT EXISTS dua_wall (
  id          TEXT PRIMARY KEY,
  user_id     TEXT NOT NULL,
  rumuz       TEXT NOT NULL,                  -- gönderim anındaki rumuz (snapshot)
  text        TEXT NOT NULL,                  -- dua metni (≤ 280)
  status      TEXT NOT NULL DEFAULT 'pending',-- pending | approved | rejected
  amins       INTEGER NOT NULL DEFAULT 0,     -- "Âmin" sayısı
  created_at  INTEGER NOT NULL DEFAULT 0,
  decided_at  INTEGER NOT NULL DEFAULT 0,     -- onay/ret zamanı
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_dua_status ON dua_wall(status, created_at);
CREATE INDEX IF NOT EXISTS idx_dua_user ON dua_wall(user_id, created_at);

CREATE TABLE IF NOT EXISTS dua_amins (
  dua_id   TEXT NOT NULL,
  user_id  TEXT NOT NULL,
  PRIMARY KEY (dua_id, user_id),
  FOREIGN KEY (dua_id) REFERENCES dua_wall(id) ON DELETE CASCADE
);
