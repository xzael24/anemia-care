/// Satu entri jadwal pemantauan — model Modul 11 (pola Note dosen):
/// `toMap` untuk insert/update, `fromMap` untuk hasil query.
class JadwalItem {
  final int? id; // null saat catatan baru, auto-fill setelah insert DB
  final String namaPasien;
  bool selesai;
  final String dibuatAt;

  JadwalItem({
    this.id,
    required this.namaPasien,
    this.selesai = false,
    String? dibuatAt,
  }) : dibuatAt = dibuatAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
    'id': id,
    'nama': namaPasien,
    'selesai': selesai ? 1 : 0,
    'dibuatAt': dibuatAt,
  };

  factory JadwalItem.fromMap(Map<String, dynamic> m) => JadwalItem(
    id: m['id'] as int?,
    namaPasien: m['nama'] as String,
    selesai: m['selesai'] == 1,
    dibuatAt: m['dibuatAt'] as String? ?? '',
  );
}
