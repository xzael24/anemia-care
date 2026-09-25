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

  /// Mode terakhir yang diteruskan layar ke service (default 'kuku').
  String? lastMode;

  @override
  Future<HasilSkrining> skriningFoto(
    File foto, {
    String? token,
    String mode = 'kuku',
  }) async {
    lastMode = mode;
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

  /// Viewport tinggi agar tombol Analisis (di bawah SegmentedButton mode)
  /// tetap hittable seperti viewport ponsel nyata.
  void besarLayar(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget bungkus({
    SkriningService? service,
    InMemoryRiwayatStore? store,
  }) {
    return MaterialApp(
      home: SkriningPage(
        service: service,
        store: store ?? InMemoryRiwayatStore(),
        pickFoto: pickFoto,
        // Kamera live (plugin native) tidak berjalan di widget test — ganti
        // dengan kembalian langsung file temp.
        openKamera: (_) async => File(tempFoto.path),
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
    besarLayar(tester);
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
    besarLayar(tester);
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

  testWidgets('mode tangan penuh: petunjuk berganti + service terima mode '
      '"tangan"', (tester) async {
    besarLayar(tester);
    final service = _FakeSkriningService(_hasilAnemia());
    await tester.pumpWidget(bungkus(service: service));

    // Default: mode close-up.
    expect(find.text('Petunjuk Foto Kuku'), findsOneWidget);

    await tester.tap(find.text('Tangan penuh'));
    await tester.pumpAndSettle();
    expect(find.text('Petunjuk Foto Tangan Penuh'), findsOneWidget);

    await tester.tap(find.text('Kamera'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analisis Kuku'));
    await tester.pumpAndSettle();

    expect(service.lastMode, 'tangan');
  });
}