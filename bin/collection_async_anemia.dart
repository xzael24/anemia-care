// Modul 5 — Collection & Async (tema: daftar & data pasien dari "server")
// ignore_for_file: avoid_print

void main() async {
  // 3 dibuat dulu di atas, karena dipakai oleh collection literal di bawah
  Map<String, dynamic> silvi = {'nama': 'Silvi', 'hb': 10.2, 'umur': 22};
  Map<String, dynamic> budi = {'nama': 'Budi', 'hb': 13.5, 'umur': 25};
  Map<String, dynamic> dono = {'nama': 'Dono', 'hb': 11.0, 'umur': 30};

  // 1. LIST — antrian pasien hari ini (berurutan, index 0)
  List<String> antrian = ['Silvi', 'Budi', 'Dono'];
  antrian.add('Rina');
  antrian.removeAt(0); // Silvi sudah diperiksa, keluar dari antrian
  print('Antrian tersisa: $antrian');

  // 2. SET — kode pasien yang sudah diskrining (wajib unik)
  Set<String> sudahSkrining = <String>{};
  sudahSkrining.add('PSN-0001');
  sudahSkrining.add('PSN-0002');
  sudahSkrining.add('PSN-0001'); // duplikat → otomatis dibuang
  print('Sudah diskrining: $sudahSkrining');

  var sesiPagi = {'PSN-0001', 'PSN-0002'};
  var sesiSore = {'PSN-0002', 'PSN-0003'};
  print('Union (semua sesi)  : ${sesiPagi.union(sesiSore)}');
  print('Intersection (doang) : ${sesiPagi.intersection(sesiSore)}');

  // 3. MAP — data pasien, format persis JSON dari API
  print('Nama: ${silvi['nama']} | Hb: ${silvi['hb']} g/dL');
  budi['kota'] = 'Tegal'; // tambah entry baru
  print('Budi sekarang: $budi');
  budi.forEach((key, value) => print('  $key: $value'));

  // 4. SPREAD + COLLECTION IF/FOR
  bool semuaBerhasil = antrian.isNotEmpty;
  var semuaPasien = [
    silvi,
    budi,
    if (semuaBerhasil) dono, // collection if
    for (var n in ['Eka', 'Fajar']) // collection for
      {'nama': n, 'hb': 14.0, 'umur': 20},
  ];
  print('Total data pasien: ${semuaPasien.length}');

  // 5. HIGHER-ORDER: map / where / any / every / reduce
  List<String> namaPasien =
      semuaPasien.map((p) => p['nama'] as String).toList();
  var pasienAnemia =
      semuaPasien.where((p) => (p['hb'] as num) < 12.0).toList();
  var totalHb = semuaPasien
      .map((p) => (p['hb'] as num).toDouble())
      .reduce((a, b) => a + b);

  print('Semua nama       : $namaPasien');
  print('Anemia (Hb<12)   : ${pasienAnemia.map((p) => p['nama']).toList()}');
  print('Ada yang Hb<8?   : ${semuaPasien.any((p) => (p['hb'] as num) < 8)}');
  print('Semua Hb valid?  : ${semuaPasien.every((p) => (p['hb'] as num) > 0)}');
  print('Rata-rata Hb     : ${(totalHb / semuaPasien.length).toStringAsFixed(1)}');

  // 6. FUTURE + ASYNC/AWAIT — simulasi ambil hasil lab dari server
  print('---');
  var hasilLab = await ambilHasilLab('PSN-0001');
  print(hasilLab);

  // 7. TRY-CATCH-FINALLY — operasi async bisa gagal kapan saja
  try {
    var user = await ambilUser(-1);
    print(user);
  } catch (e) {
    print('Error: $e');
  } finally {
    print('Proses selesai');
  }

  // 8. STREAM — telemetri Hb real-time (misal dari alat ukur)
  print('---');
  await for (var hb in telemetriHb(8.5)) {
    print('Baca sensor: $hb g/dL');
  }
}

// Simulasi koneksi server (lambat, kayak jaringan beneran)
Future<String> ambilHasilLab(String kode) async {
  print('Mengambil hasil lab $kode...');
  await Future.delayed(const Duration(seconds: 2));
  return 'Hasil lab $kode: Hb 10.2 g/dL (ANEMIA)';
}

Future<String> ambilUser(int id) async {
  await Future.delayed(const Duration(seconds: 1));
  if (id < 0) throw Exception('ID tidak valid');
  return 'User #$id';
}

// Stream: nilai datang bertahap, satu per satu
Stream<double> telemetriHb(double awal) async* {
  for (int i = 0; i < 3; i++) {
    await Future.delayed(const Duration(milliseconds: 500));
    yield awal + i * 0.5;
  }
}