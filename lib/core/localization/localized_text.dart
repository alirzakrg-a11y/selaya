import 'package:flutter/widgets.dart';

/// Helpers for resolving inline bilingual content stored in demo JSON as
/// `{ "tr": ..., "en": ... }`. Top-level fields stay language-invariant;
/// only the `translations` block is localized. Falls back to `tr`.
extension LocalizedMapX on Map<String, dynamic> {
  /// Returns the localized sub-value (String or Map) for [locale].
  V forLocale<V>(String locale) {
    final value = this[locale] ?? this['tr'] ?? this['en'] ?? values.first;
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
