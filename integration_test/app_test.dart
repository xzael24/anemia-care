import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:anemia/main.dart' as app;

/// Modul 13 — Integration Test (puncak piramida testing, dosen).
/// Jalan di emulator/device NYATA (bukan headless):
///   flutter test integration_test/app_test.dart
///
/// Catatan jujur:
/// - File ini TIDAK kebawa `flutter test` biasa (default cuma folder test/),
///   jadi suite unit+widget kita tetap cepat.
/// - Sengaja nggak buka tab Direktori: butuh jaringan/API JSONPlaceholder,
///   biar test mandiri (tidak bergantung internet).
/// - Idempoten: bersihin sisa "selesai" dari run sebelumnya dulu, biar bisa
///   dijalanin berulang-ulang tanpa reset data.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E2E: catat pasien ke jadwal, toggle, hapus', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    expect(find.text('Dashboard Anemia'), findsOneWidget);

    // Idempotensi: kalau ada sisa item "selesai" dari run sebelumnya, hapus.
    await tester.tap(find.text('Jadwal'));
    await tester.pumpAndSettle();
    if (find.text('Hapus Semua Selesai').evaluate().isNotEmpty) {
      await tester.tap(find.text('Hapus Semua Selesai'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Beranda'));
    await tester.pumpAndSettle();

    // Happy path: pasien → detail → Catat ke Jadwal
    await tester.tap(find.text('Silvi Rahmawati'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Catat ke Jadwal'));
    await tester.pumpAndSettle();

    // Jadwal: item muncul → toggle selesai → hapus → kosong
    await tester.tap(find.text('Jadwal'));
    await tester.pumpAndSettle();
    expect(find.text('Silvi Rahmawati'), findsOneWidget);

    await tester.tap(find.text('Silvi Rahmawati'));
    await tester.pumpAndSettle();
    expect(find.text('0 belum selesai'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada jadwal.'), findsOneWidget);
  });
}
