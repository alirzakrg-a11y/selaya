/// Giriş yapmış kullanıcının profili (sunucudan döner, prefs'te saklanır).
class AuthUser {
  final String id;
  final String name; // ad
  final String surname; // soyad
  final String email;
  final String rumuz; // Dua Duvarı takma adı (opsiyonel; boş olabilir)
  final bool isPremium; // reklamsız (HESABA bağlı; sunucu /v1/me'den döner)
  const AuthUser({
    required this.id,
    required this.name,
    required this.surname,
    required this.email,
    this.rumuz = '',
    this.isPremium = false,
  });

  String get fullName =>
      surname.trim().isEmpty ? name.trim() : '${name.trim()} ${surname.trim()}';

  /// Ad-soyadtan baş harfler (avatar için), boşsa e-postanın ilk harfi.
  String get initials {
    final n = name.trim();
    final s = surname.trim();
    final a = n.isNotEmpty ? n[0] : (email.isNotEmpty ? email[0] : '?');
    final b = s.isNotEmpty ? s[0] : '';
    return (a + b).toUpperCase();
  }

  AuthUser copyWith({String? rumuz, bool? isPremium}) => AuthUser(
        id: id,
        name: name,
        surname: surname,
        email: email,
        rumuz: rumuz ?? this.rumuz,
        isPremium: isPremium ?? this.isPremium,
      );

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        surname: (j['surname'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        rumuz: (j['rumuz'] ?? '').toString(),
        isPremium: j['is_premium'] == 1 || j['is_premium'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'surname': surname,
        'email': email,
        'rumuz': rumuz,
        'is_premium': isPremium ? 1 : 0,
      };
}
