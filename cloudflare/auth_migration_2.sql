-- Hesap kilidi (brute-force koruması): 5 hatalı girişte 15 dk kilit.
ALTER TABLE users ADD COLUMN failed_attempts INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN locked_until INTEGER NOT NULL DEFAULT 0;
