-- SELAYA içerik kayıt tablosu (D1)
-- Her satır = app'in çekeceği bir medya öğesi (görsel/video/ses).
CREATE TABLE IF NOT EXISTS content_items (
  id          TEXT PRIMARY KEY,
  collection  TEXT NOT NULL,                 -- feed | wallpapers | stories | inspiration | bg_videos | guide_abdest | guide_namaz | radio_art
  kind        TEXT NOT NULL DEFAULT 'image', -- image | video | audio
  key         TEXT NOT NULL,                 -- R2 anahtarı, ör: images/wallpapers/wp_mosque_2.jpg
  title       TEXT,
  subtitle    TEXT,
  thumb_key   TEXT,                          -- video için kapak görseli anahtarı
  extra       TEXT,                          -- serbest JSON (ek alanlar)
  sort        INTEGER NOT NULL DEFAULT 0,
  active      INTEGER NOT NULL DEFAULT 1,
  created_at  INTEGER NOT NULL DEFAULT 0,
  updated_at  INTEGER NOT NULL DEFAULT 0,
  lang        TEXT NOT NULL DEFAULT 'tr'      -- madde 16: içerik dili (app locale'e göre çeker, TR yedek)
);

CREATE INDEX IF NOT EXISTS idx_content_collection ON content_items(collection, active, sort);
