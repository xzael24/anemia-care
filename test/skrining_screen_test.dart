import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:anemia/models/hasil_skrining.dart';
import 'package:anemia/screens/skrining_screen.dart';
import 'package:anemia/services/skrining_service.dart';

import 'fakes/in_memory_riwayat_store.dart';
import 'fakes/in_memory_session_store.dart';

/// Service palsu — tanpa HTTP sungguhan (widget test).
class _FakeSkriningService extends SkriningService {
  _FakeSkriningService(this._hasil, [this._error]);

  final HasilSkrining? _hasil;
  final Exception? _error;

  @override
  Future<HasilSkrining> skriningFoto(File foto, {String? token}) async {
    final err = _error;
    if (err != null) throw err;
    final hasil = _hasil;
    if (hasil == null) {
      throw StateError('test: hasil belum di-set');
    }
    return hasil;
  }
}

HasilSkrining _hasilAnemia() => HasilSkrining(
  id: 'abc-1',
  indication: 'anemia',
  confidence: 0.92,
  hbEstimateGdl: 10.5,
  source: 'ml',
  imageName: 'kuku.jpg',
  createdAt: '2026-09-24T07:20:00.000Z',
  disclaimer:
      'Hasil ini adalah indikasi awal skrining non-invasif, '
      'BUKAN diagnosis medis.',
);

void main() {
  late Directory tempDir;
  late File tempFoto;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('skrining_test');
    tempFoto = File('${tempDir.path}/kuku_test.jpg')
      ..writeAsBytesSync([1, 2, 3, 4, 5]); // isi apa pun; preview punya errorBuilder
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<XFile?> pickFoto(ImageSource source) async =>
      XFile(tempFoto.path);

  Widget bungkus({
    SkriningService? service,
    InMemoryRiwayatStore? store,
  }) {
    return MaterialApp(
      home: SkriningPage(
        service: service,
        store: store ?? InMemoryRiwayatStore(),
        pickFoto: pickFoto,
        sessionStore: InMemorySessionStore(),
      ),
    );
  }

  testWidgets('state awal: placeholder foto + tombol analisis nonaktif', (
    tester,
  ) async {
    await tester.pumpWidget(bungkus(service: _FakeSkriningService(_hasilAnemia())));

    expect(find.text('Belum ada foto'), findsOneWidget);
    expect(find.text('Analisis Kuku'), findsOneWidget);

    final tombol = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(tombol.onPressed, isNull, reason: 'nonaktif sebelum foto dipilih');
  });

  testWidgets('alur sukses: pilih foto → analisis → hasil + disclaimer + riwayat', (
    tester,
  ) async {
    final store = InMemoryRiwayatStore();
    await tester.pumpWidget(
      bungkus(service: _FakeSkriningService(_hasilAnemia()), store: store),
    );

    await tester.tap(find.text('Kamera'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada foto'), findsNothing);

    await tester.tap(find.text('Analisis Kuku'));
    await tester.pumpAndSettle();

    // Kartu hasil
    expect(find.textContaining('Confidence 92%'), findsOneWidget);
    expect(find.textContaining('Estimasi Hb: 10.5 g/dL'), findsOneWidget);
    expect(find.textContaining('BUKAN diagnosis medis'), findsOneWidget);

    // Tersimpan ke riwayat lokal
    expect(store.items.length, 1);
    expect(find.text('Indikasi Anemia'), findsNWidgets(2)); // kartu + baris riwayat
  });

  testWidgets('gagal: error dari service ditampilkan di layar', (tester) async {
    await tester.pumpWidget(
      bungkus(
        service: _FakeSkriningService(
          null,
          Exception('Tidak dapat terhubung ke server skrining'),
        ),
      ),
    );

    await tester.tap(find.text('Kamera'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analisis Kuku'));
    await tester.pumpAndSettle();

    expect(
      find.text('Tidak dapat terhubung ke server skrining'),
      findsOneWidget,
    );
  });
}