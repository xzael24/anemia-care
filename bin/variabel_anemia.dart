// Modul 3 — Variabel & Tipe Data (tema: data pasien anemia)
// ignore_for_file: avoid_print

void main() {
  // 1. var — type inference (tipe ditentukan otomatis dari nilainya)
  var nama = 'Silvi';     // String
  var umur = 22;          // int
  var hemoglobin = 10.2;  // double

  // 2. Deklarasi eksplisit — tipe ditulis langsung
  String golonganDarah = 'A';
  int jumlahTrombosit = 250000;
  double beratBadan = 48.5;
  bool berisikoAnemia = true;

  // 3. final — sekali di-assign, tidak bisa diubah lagi
  final kodePasien = 'PSN-0001';
  // kodePasien = 'PSN-0002'; // ❌ ERROR: final sudah terkunci

  // 4. const — konstanta compile-time
  const batasHbNormal = 12.0; // g/dL, ambang WHO

  // 5. num — supertype int & double, bisa menampung keduanya
  num nilaiLab = 99;
  nilaiLab = 98.5;
  print('Nilai lab (num): $nilaiLab');

  print('=== Data Pasien ===');
  print('Nama      : $nama ($kodePasien)');
  print('Umur      : $umur tahun');
  print('Gol.Darah : $golonganDarah');
  print('Hemoglobin: $hemoglobin g/dL (batas normal: $batasHbNormal)');
  print('Trombosit : $jumlahTrombosit');
  print('Berat     : $beratBadan kg');
  print('Berisiko  : $berisikoAnemia');
  print('Evaluasi  : ${hemoglobin < batasHbNormal ? 'ANEMIA' : 'normal'}');

  // 6. Operasi String
  var diagnosa = '  anemia defisiensi besi  ';
  print('---');
  print(diagnosa.trim().toUpperCase());
  print('mengandung kata anemia : ${diagnosa.contains('anemia')}');
  print(diagnosa.replaceAll('besi', 'folat'));

  // Multi-line String
  var catatan = '''
Catatan: pasien melaporkan
kelelahan sejak 2 minggu terakhir.
''';
  print(catatan);

  // 7. Collection: List, Map, Set
  List<String> gejala = ['lemah', 'pucat', 'pusing'];
  gejala.add('sesak napas');
  print('Gejala (${gejala.length}): $gejala');

  Map<String, dynamic> hasilLab = {
    'hemoglobin': 10.2,
    'mcv': 74.3,
    'ferritin': 8.9,
  };
  print('Hasil lab → Hb: ${hasilLab['hemoglobin']} | MCV: ${hasilLab['mcv']}');

  Set<String> golDarahKamar = <String>{};
  golDarahKamar.add('A');
  golDarahKamar.add('B');
  golDarahKamar.add('O');
  golDarahKamar.add('A'); // duplikat → otomatis dibuang waktu add
  print('Golongan darah di kamar: $golDarahKamar'); // {A, B, O}

  // 8. Null Safety
  // Nilai dari "database" bisa null → di sinilah ?. dan ?? bekerja sungguhan.
  double? hbSebelum = cekLabLama();
  print('---');
  print('Hb dari lab lain   : ${hbSebelum ?? 'belum ada hasil'}');
  print('Panjang string Hb  : ${hbSebelum?.toString().length}'); // null → aman, hasil null

  String alamat = cekAlamat() ?? 'alamat belum diisi'; // ?? → fallback kalau null
  print('Alamat              : $alamat');
  print('Alamat kapital      : ${alamat.toUpperCase()}');

  // 9. Konversi tipe (sering dipakai untuk input dari form/TextField)
  var inputDariForm = '12.5'; // dari UI selalu String
  double hbParsed = double.parse(inputDariForm);
  print('---');
  print('Hb dihitung ulang : ${hbParsed.toStringAsFixed(1)}');
  print('Nilai bulat (hbParsed.toInt()): ${hbParsed.toInt()}'); // 12, terpotong!
}

// Helper kecil — detailnya dibahas di Modul 4 (Function & OOP).
// Kembalian String?/double? artinya "bisa null", jadi ?. dan ?? di atas beneran kepake.
double? cekLabLama() => null; // misal: hasil lab lama nggak ketemu di database
String? cekAlamat() => 'Tegal'; // misal: alamat pasien ketemu