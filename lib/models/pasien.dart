/// Akun pasien pengguna mobile (Tahap 3 — endpoint `/api/pasien`).
class Pasien {
  const Pasien({
    required this.id,
    required this.username,
    required this.nama,
    required this.usia,
    required this.gender,
    this.tipeKulit,
    this.hamil = false,
    this.riwayatAnemia = false,
  });

  final String id;
  final String username;
  final String nama;
  final int usia;

  /// 'laki' | 'perempuan'
  final String gender;

  /// 'terang' | 'sedang' | 'gelap' (default konteks fuzzy).
  final String? tipeKulit;
  final bool hamil;
  final bool riwayatAnemia;

  bool get perempuan => gender == 'perempuan';

  String get labelGender => perempuan ? 'Perempuan' : 'Laki-laki';

  factory Pasien.fromJson(Map<String, dynamic> j) {
    return Pasien(
      id: j['id'] as String? ?? '',
      username: j['username'] as String? ?? '',
      nama: j['nama'] as String? ?? '',
      usia: (j['usia'] as num?)?.toInt() ?? 0,
      gender: j['gender'] as String? ?? 'laki',
      tipeKulit: j['tipeKulit'] as String?,
      hamil: j['hamil'] as bool? ?? false,
      riwayatAnemia: j['riwayatAnemia'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'nama': nama,
    'usia': usia,
    'gender': gender,
    'tipeKulit': tipeKulit,
    'hamil': hamil,
    'riwayatAnemia': riwayatAnemia,
  };

  @override
  String toString() => 'Pasien($username)';
}

/// Hasil daftar/login pasien: token JWT + profil.
class PasienAuth {
  const PasienAuth({required this.accessToken, required this.pasien});

  final String accessToken;
  final Pasien pasien;

  factory PasienAuth.fromJson(Map<String, dynamic> j) {
    return PasienAuth(
      accessToken: j['accessToken'] as String? ?? '',
      pasien: Pasien.fromJson(j['pasien'] as Map<String, dynamic>? ?? const {}),
    );
  }
}