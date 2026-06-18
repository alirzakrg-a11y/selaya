/// Giriş yapmış kullanıcının profili (sunucudan döner, prefs'te saklanır).
class AuthUser {
  final String id;
  final String name; // ad
  final String surname; // soyad
  final String email;
  final String rumuz; // Dua Duvarı takma adı (opsiyonel; boş olabilir)
  const AuthUser({
    required this.id,
    required this.name,
    required this.surname,
    required this.email,
    this.rumuz = '',
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

  AuthUser copyWith({String? rumuz}) => AuthUser(
        id: id,
        name: name,
        surname: surname,
        email: email,
        rumuz: rumuz ?? this.rumuz,
      );

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        surname: (j['surname'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        rumuz: (j['rumuz'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'surname': surname,
        'email': email,
        'rumuz': rumuz,
      };
}
