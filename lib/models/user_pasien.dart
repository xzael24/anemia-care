/// Model data pasien dari API — Modul 10.
/// Praktik terbaik: jangan kerja dengan `Map<String, dynamic>` mentah,
/// buat model class + factory fromJson biar type-safe.
class UserPasien {
  final int id;
  final String nama;
  final String email;
  final String kota;
  final String website;

  UserPasien({
    required this.id,
    required this.nama,
    required this.email,
    required this.kota,
    required this.website,
  });

  factory UserPasien.fromJson(Map<String, dynamic> json) {
    final address = json['address'] as Map<String, dynamic>?;
    return UserPasien(
      id: json['id'] as int,
      nama: json['name'] as String,
      email: json['email'] as String,
      kota: (address?['city'] as String?) ?? '',
      website: (json['website'] as String?) ?? '',
    );
  }
}
