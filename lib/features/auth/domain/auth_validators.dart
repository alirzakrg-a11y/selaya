// Ortak doğrulayıcılar — UI'da ANINDA geri bildirim için (backend de aynısını uygular).

/// Geçerli e-posta biçimi (TLD en az 2 karakter).
bool isValidEmail(String e) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(e.trim());

/// Güçlü şifre: en az 6 karakter + en az 1 harf + en az 1 rakam.
bool isStrongPassword(String p) =>
    p.length >= 6 && RegExp(r'[A-Za-z]').hasMatch(p) && RegExp(r'[0-9]').hasMatch(p);
