// Modul 4 — Function & OOP (tema: skrining anemia)
// ignore_for_file: avoid_print

// ===== 1. FUNCTION DASAR + ARROW =====
double rataRataHb(double hb1, double hb2) => (hb1 + hb2) / 2; // arrow, 1 ekspresi

void logPemeriksaan(String pesan) {
  print('[LOG] $pesan');
}

// ===== 2. NAMED & OPTIONAL PARAMETERS =====
void periksaPasien({required String nama, int? usia, bool catat = true}) {
  var umur = usia != null ? ' ($usia tahun)' : ' (usia belum diisi)';
  var prefix = catat ? '[LOG] ' : '';
  print('$prefix Periksa $nama$umur');
}

String sapaPasien(String nama, [String gelar = '']) =>
    gelar.isEmpty ? 'Halo, $nama!' : 'Halo, $gelar $nama!';

// ===== 3. CLASS & OBJECT + ENCAPSULATION =====
class Pasien {
  final String _kode; // underscore = private level file (encapsulation)
  String nama;
  double hemoglobin;
  int? usia;

  Pasien({required String kode, required this.nama, required this.hemoglobin})
      // ignore: prefer_initializing_formals — param publik 'kode' → field privat '_kode'
      : _kode = kode;

  bool get berisikoAnemia => hemoglobin < 12.0; // getter + logika
  String get kesimpulan => berisikoAnemia ? 'ANEMIA' : 'normal';

  String info() => '$_kode | $nama | Hb $hemoglobin g/dL → $kesimpulan';
}

// ===== 4. INHERITANCE & POLYMORPHISM via abstract =====
abstract class Skrining {
  String namaSkrining(); // abstract method — wajib diimplementasikan child
  bool terindikasi();

  // abstract class BOLEH punya method konkret
  String ringkasan() =>
      '${namaSkrining()}: ${terindikasi() ? 'TERINDIKASI ⚠️' : 'aman ✅'}';
}

class SkriningAnemia extends Skrining {
  final Pasien pasien;

  SkriningAnemia(this.pasien);

  @override
  String namaSkrining() => 'Skrining Anemia';

  @override
  bool terindikasi() => pasien.berisikoAnemia;
}

class SkriningKelelahan extends Skrining {
  final bool seringLelah;

  SkriningKelelahan(this.seringLelah);

  @override
  String namaSkrining() => 'Skrining Kelelahan';

  @override
  bool terindikasi() => seringLelah;
}

// ===== 5. MIXIN — tempel kemampuan (hindari multiple inheritance) =====
mixin TercatatDiRekamMedis {
  final List<String> _catatan = [];

  void catat(String masuk) => _catatan.add(masuk);

  List<String> get catatan => List.unmodifiable(_catatan);
}

class PasienTercatat extends Pasien with TercatatDiRekamMedis {
  PasienTercatat({required super.kode, required super.nama, required super.hemoglobin});
}

void main() {
  // Function + arrow
  print('Rata-rata Hb 2 kali cek: ${rataRataHb(10.2, 11.8)} g/dL');
  logPemeriksaan('pasien baru didaftarkan');

  // Named & optional positional
  periksaPasien(nama: 'Silvi');
  periksaPasien(nama: 'Budi', usia: 25, catat: false);
  print(sapaPasien('Silvi'));
  print(sapaPasien('Arif', 'Pak'));

  // Object + getter
  var silvi = Pasien(kode: 'PSN-0001', nama: 'Silvi', hemoglobin: 10.2);
  var budi = Pasien(kode: 'PSN-0002', nama: 'Budi', hemoglobin: 13.5);
  print('---');
  print(silvi.info());
  print(budi.info());

  // Polymorphism — satu List<Skrining>, dua perilaku berbeda
  print('---');
  List<Skrining> daftarSkrining = [
    SkriningAnemia(silvi),
    SkriningAnemia(budi),
    SkriningKelelahan(true),
  ];
  for (var s in daftarSkrining) {
    print(s.ringkasan());
  }

  // Mixin — PasienTercatat "menempel" kemampuan catat-mencatat
  print('---');
  var dono = PasienTercatat(kode: 'PSN-0003', nama: 'Dono', hemoglobin: 11.0);
  dono..catat('datang 08:00')..catat('Hb 11.0 g/dL, keluhan pusing');
  print(dono.info());
  print('Catatan rekam medis: ${dono.catatan}');
  // print(silvi._kode); // ❌ di file lain error — encapsulation
}