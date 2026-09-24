import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:anemia/screens/galeri_screen.dart';
import 'package:anemia/services/galeri_service.dart';

/// Widget test galeri pakai FILE ASLI (IO disk) — beda dari test sebelumnya
/// yang semua mock/microtask. Widget test berjalan di zona FakeAsync, jadi
/// IO asli harus dibungkus `tester.runAsync`; seeding pakai varian SYNC.
///
/// Kenapa harus alternasi pump↔runAsync (bukan sekali jalan)?
/// Tiap operasi IO asli (dir.list, file.delete, baca gambar) itu "hop" yang
/// masing-masing butuh real time. Pas IO-nya kelar di OS, kontinuasinya
/// antri sebagai microtask FAKE — cuma jalan pas pump. Jadi susunannya:
///   pump  → flush microtask → hop berikutnya mulai (nge-gantung)
///   runAsync → real time → hop selesai
///   (ulang sampai pipeline gambar/delete kelar semua)
const _pngBytes = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('galeri_test_');
  });

  tearDown(() async {
    // Windows: file bisa lagi di-scan Defender → retry pas deleteSync.
    for (var i = 0; i < 30; i++) {
      try {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        return;
      } on PathAccessException {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  });

  void seedFoto(String nama) {
    File(p.join(tempDir.path, nama)).writeAsBytesSync(_pngBytes);
  }

  /// Alternasi pump (flush microtask) ↔ runAsync (real time) biar pipeline
  /// IO asli bisa rampung — lihat penjelasan di header file.
  Future<void> settleDenganIO(WidgetTester tester, {int kali = 4}) async {
    for (var i = 0; i < kali; i++) {
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
    }
    await tester.pumpAndSettle();
  }

  Future<void> pumpGaleri(WidgetTester tester) async {
    // Load foto di initState = dir.list() asli → mulai di luar FakeAsync
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: GaleriLabPage(
            service: GaleriLabService(getDir: () async => tempDir),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    // Rampungkan render + baca/decode gambar (supaya handle file kebuka
    // sebelum operasi lain — kalau enggak, delete kena lock di Windows).
    await settleDenganIO(tester);
  }

  /// Lepas tree sebelum teardown — biar ImageState kebuang duluan.
  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  /// Format overlay mengikuti app (waktu LOKAL) — test TZ-agnostic.
  String formatOverlay(DateTime d) {
    String dua(int n) => n.toString().padLeft(2, '0');
    return '${d.day} Jan ${d.year}, ${dua(d.hour)}:${dua(d.minute)}';
  }

  testWidgets('galeri menampilkan foto + overlay tanggal dari nama file', (
    tester,
  ) async {
    seedFoto('foto_1000.jpg');
    seedFoto('foto_2000.jpg');
    seedFoto('catatan.txt'); // bukan jpg → diabaikan

    await pumpGaleri(tester);

    expect(find.text('Galeri Hasil Lab (2)'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
    // Overlay tantangan no. 2 — tanggal lokal dari timestamp nama file
    final harapan = formatOverlay(DateTime.fromMillisecondsSinceEpoch(1000));
    expect(find.text(harapan), findsNWidgets(2));
    expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    expect(find.byIcon(Icons.photo_library), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets('galeri kosong menampilkan empty state', (tester) async {
    await pumpGaleri(tester);

    expect(find.text('Galeri Hasil Lab (0)'), findsOneWidget);
    expect(find.text('Belum ada foto hasil lab.'), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets('long-press → AlertDialog → hapus → foto hilang + SnackBar', (
    tester,
  ) async {
    seedFoto('foto_1000.jpg');
    seedFoto('foto_2000.jpg');

    await pumpGaleri(tester);
    expect(find.byType(Image), findsNWidgets(2));

    // Tantangan no. 1 — long-press salah satu foto
    await tester.longPress(
      find.byKey(ValueKey(p.join(tempDir.path, 'foto_2000.jpg'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hapus foto ini?'), findsOneWidget);

    // Batal dulu → foto tetap ada
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNWidgets(2));

    // Ulangi → konfirmasi hapus → delete = IO asli berjenjang
    await tester.longPress(
      find.byKey(ValueKey(p.join(tempDir.path, 'foto_2000.jpg'))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle(); // dialog pop → chain delete() mulai
    expect(find.text('Hapus foto ini?'), findsNothing);

    await settleDenganIO(tester, kali: 5); // delete + reload + render

    expect(find.text('Foto dihapus'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Galeri Hasil Lab (1)'), findsOneWidget);

    // Flush timer SnackBar, lalu lepas tree sebelum teardown
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await disposeTree(tester);
  });
}
