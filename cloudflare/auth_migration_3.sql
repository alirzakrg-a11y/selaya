-- Sıfırlama kodu brute-force kilidi: 5 yanlış denemede kod ölür.
ALTER TABLE auth_codes ADD COLUMN attempts INTEGER NOT NULL DEFAULT 0;
