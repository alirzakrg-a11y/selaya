-- Özel bildirimler (panelden gönderilir, app /v1/notifications'tan çeker).
CREATE TABLE IF NOT EXISTS notifications (
  id          TEXT PRIMARY KEY,
  title       TEXT NOT NULL,
  body        TEXT,
  image_key   TEXT,
  link        TEXT,
  active      INTEGER NOT NULL DEFAULT 1,
  created_at  INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_notifications_active ON notifications(active, created_at);
