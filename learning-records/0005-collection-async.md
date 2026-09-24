# Collection & Async di Dart — selesai (Modul 5)

Modul 5 selesai: teori dari materi dosen (collection-async.html) dipraktikkan di `bin/collection_async_anemia.dart` bertema data pasien "dari server". Semua topik dikerjakan: List/Set/Map + operasi himpunan, spread & collection if/for, higher-order (map/where/any/every/reduce), Future + async/await, try-catch-finally, dan Stream (async*/yield + await for). Output `dart run` sesuai urutan eksekusi async (delay 2 detik terasa), `flutter analyze` No issues.

## Implications
- Ini jembatan ke UI Flutter: ListView dari List data, FutureBuilder/StreamBuilder. Mahasiswa sudah paham bentuk datanya sebelum ketemu widgetnya di Modul 6+.
- Pola `Map<String, dynamic>` = format JSON dari API — sudah otomatis terpakai. Menyambung ke Modul 10 (REST API).
- Kesadaran penting yang ditanamkan: tanpa `await`, UI jalan duluan → bug "data belum ada" (sering disebut race condition di UI). Mahasiswa diminta merasakan delay `Future.delayed` supaya nyambung mental ke jaringan nanti.
- Pola skrining anemia (`where((p) => (p['hb'] as num) < 12.0)`) adalah cikal bakal logika screening real app.
- Zona perkembangan berikutnya: Widget Dasar (Modul 6) — akhirnya UI Flutter: StatelessWidget/StatefulWidget, MaterialApp, Scaffold, Text/Button/Image. Dasar bahasa sudah komplit (M3-M5), sekarang bangun visual.