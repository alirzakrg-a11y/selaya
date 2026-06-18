-- Ban sistemi (kullanıcı 2026-06-18): panelden banlanan kullanıcı uygulamaya
-- hiçbir şekilde giriş yapamaz; otomatik çıkış + "engellendiniz" görür. EK sütun.
ALTER TABLE users ADD COLUMN banned INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN ban_reason TEXT;
ALTER TABLE users ADD COLUMN banned_at INTEGER NOT NULL DEFAULT 0;
