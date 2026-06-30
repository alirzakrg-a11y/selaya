-- Premium (reklamsız) + resmî hesap + IAP makbuz alanları.
-- Bu kolonlar base auth_schema.sql'de YOK; eskiden elle ALTER ile eklenmişti
-- (schema drift). DB sıfırdan kurulursa GET /v1/me bunları SELECT ettiği için
-- 500 verir → sıfırdan kurulumda bu dosyayı çalıştır (auth_migration_2/3 gibi).
-- Worker da çalışma anında ensurePremiumCols() ile idempotent garanti eder.
ALTER TABLE users ADD COLUMN is_premium INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN is_official INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN premium_token TEXT;     -- Play purchaseToken (doğrulama için saklanır)
ALTER TABLE users ADD COLUMN premium_product TEXT;   -- ör. selaya_premium_yearly
ALTER TABLE users ADD COLUMN premium_at INTEGER;      -- epoch ms (audit)
ALTER TABLE users ADD COLUMN premium_expiry INTEGER;  -- abonelik bitiş (ms); lifetime=NULL
