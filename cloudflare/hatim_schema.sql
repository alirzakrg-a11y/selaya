-- SELAYA — Topluluk Hatmi şeması. TAMAMEN EK (mevcut tabloları bozmaz).
--   • hatim_campaigns : bir hatim kampanyası (varsayılan "Topluluk Hatmi" veya niyetli)
--   • hatim_juz       : kampanyanın 30 cüzü (open | claimed | done)

CREATE TABLE IF NOT EXISTS hatim_campaigns (
  id            TEXT PRIMARY KEY,
  title         TEXT NOT NULL,
  intention     TEXT,                              -- niyet (ör. "merhum X için")
  status        TEXT NOT NULL DEFAULT 'active',     -- active | completed
  created_by    TEXT,                               -- user id ('system' = otomatik)
  created_rumuz TEXT,
  created_at    INTEGER NOT NULL DEFAULT 0,
  completed_at  INTEGER
);
CREATE INDEX IF NOT EXISTS idx_hatim_status ON hatim_campaigns(status, created_at);

CREATE TABLE IF NOT EXISTS hatim_juz (
  campaign_id TEXT NOT NULL,
  juz_no      INTEGER NOT NULL,                     -- 1..30
  user_id     TEXT,
  rumuz       TEXT,
  status      TEXT NOT NULL DEFAULT 'open',         -- open | claimed | done
  claimed_at  INTEGER,
  done_at     INTEGER,
  PRIMARY KEY (campaign_id, juz_no)
);
CREATE INDEX IF NOT EXISTS idx_hatim_juz_user ON hatim_juz(user_id);
