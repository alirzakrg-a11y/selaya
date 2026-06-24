import 'package:flutter/widgets.dart';

/// Helpers for resolving inline bilingual content stored in demo JSON as
/// `{ "tr": ..., "en": ... }`. Top-level fields stay language-invariant;
/// only the `translations` block is localized. İçerik verisi yalnız tr/en
/// çevirili olduğundan, UI dili ar/de/id/fr ise İNGİLİZCE'ye düşülür (Türkçe
/// yerine — uluslararası kullanıcı için daha doğru); o da yoksa tr.
extension LocalizedMapX on Map<String, dynamic> {
  /// Returns the localized sub-value (String or Map) for [locale].
  V forLocale<V>(String locale) {
    final value = this[locale] ?? this['en'] ?? this['tr'] ?? values.first;
    return value as V;
  }

  String stringFor(String locale) => forLocale<String>(locale);

  Map<String, dynamic> mapFor(String locale) =>
      (forLocale<Object>(locale) as Map).cast<String, dynamic>();
}

extension LocaleContextX on BuildContext {
  /// Current language code ('tr' | 'en'). Driven by easy_localization.
  String get langCode => Localizations.localeOf(this).languageCode;

  bool get isTurkish => langCode == 'tr';
}
