CREATE TABLE IF NOT EXISTS likes (
  key TEXT PRIMARY KEY,
  count INTEGER NOT NULL DEFAULT 0
);
INSERT OR IGNORE INTO likes (key, count) VALUES
  ('verse:ins01', 342), ('verse:ins02', 277), ('verse:ins04', 189),
  ('verse:ins06', 156), ('verse:ins08', 203), ('verse:ins13', 98),
  ('verse:ins14', 121), ('verse:ins25', 167), ('verse:ins28', 144),
  ('hadith:h01', 254), ('hadith:h02', 198), ('hadith:h05', 142),
  ('hadith:h07', 176), ('hadith:h10', 133), ('hadith:h21', 119),
  ('dua:morning_01', 211), ('dua:x_salavat', 305), ('dua:x_istigfar', 188),
  ('dua:x_cennet', 162);
