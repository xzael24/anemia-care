import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anemia/screens/kamera_capture_screen.dart';

/// Widget test layar kamera: plugin kamera native TIDAK tersedia di
/// lingkungan test, jadi jalur yang diuji adalah fallback (kamera tidak
/// tersedia → tombol galeri/kembali). Jalur preview live hanya bisa diuji
/// di perangkat/emulator (lih. test manual di README app).
void main() {
  testWidgets('kamera tidak tersedia (test env) → fallback + galeri', (
    tester,
  ) async {
    var galeriDipanggil = false;
    await tester.pumpWidget(
      MaterialApp(
        home: KameraCaptureScreen(
          mode: 'kuku',
          // Kamera native tidak ada di widget test — paksa jalur error
          // supaya UI fallback teruji deterministik.
          initOverride: () async => throw Exception(
            'tidak ada kamera di lingkungan test',
          ),
          pickGallery: () async {
            galeriDipanggil = true;
            return null;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kamera tidak tersedia'), findsOneWidget);
    expect(find.text('Buka Galeri'), findsOneWidget);

    await tester.tap(find.text('Buka Galeri'));
    await tester.pumpAndSettle();
    expect(galeriDipanggil, isTrue);
  });

  testWidgets('fallback: tombol Kembali menutup layar (pop null)', (
    tester,
  ) async {
    File? hasil;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                hasil = await Navigator.push<File>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => KameraCaptureScreen(
                      initOverride: () async => throw Exception('uji fallback'),
                    ),
                  ),
                );
              },
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(find.text('Kamera tidak tersedia'), findsOneWidget);

    await tester.tap(find.text('Kembali'));
    await tester.pumpAndSettle();
    expect(hasil, isNull);
  });
}