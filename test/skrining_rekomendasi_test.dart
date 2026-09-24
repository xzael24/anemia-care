import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:anemia/models/hasil_skrining.dart';
import 'package:anemia/models/pasien.dart';
import 'package:anemia/models/rekomendasi_hasil.dart';
import 'package:anemia/screens/skrining_screen.dart';
import 'package:anemia/services/rekomendasi_service.dart';
import 'package:anemia/services/session_store.dart';
import 'package:anemia/services/skrining_service.dart';

import 'fakes/in_memory_riwayat_store.dart';
import 'fakes/in_memory_session_store.dart';

class _FakeSkriningService extends SkriningService {
  @override
  Future<HasilSkrining> skriningFoto(File foto, {String? token}) async =>
      _hasilAnemia();
}

class _FakeRekomendasiService extends RekomendasiService {
  _FakeRekomendasiService({this.error});

  final Exception? error;
  String? lastGejala;
  String? lastRisiko;
  String? lastTipeKulit;

  @override
  Future<RekomendasiHasil> rekomendasi({
    required String indication,
    required double confidence,
    double? hbEstimateGdl,
    List<String> gejala = const [],
    List<String> risiko = const [],
    String? tipeKulit,
  }) async {
    final err = error;
    if (err != null) throw err;
    lastGejala = gejala.join(',');
    lastRisiko = risiko.join(',');
    lastTipeKulit = tipeKulit;
    return RekomendasiHasil(
      rekomendasi: 0.837,
      tingkat: 'tinggi',
      emoji: '🔴',
      label: 'Segera periksa ke puskesmas/dokter — pemeriksaan darah (Hb)',
      pesan: 'Indikasi visual cukup kuat. Pemeriksaan darah (Hb) segera disarankan.',
      skorVisual: 1.0,
      skorGejala: 0.2,
      skorRisiko: 0.0,
      disclaimer: 'Rekomendasi ini BUKAN pengganti tenaga kesehatan.',
    );
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
  disclaimer: 'Hasil ini adalah indikasi awal skrining non-invasif, BUKAN diagnosis medis.',
);

void main() {
  late Directory tempDir;
  late File tempFoto;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('skrining_rekom_test');
    tempFoto = File('${tempDir.path}/kuku_test.jpg')
      ..writeAsBytesSync([1, 2, 3, 4, 5]);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<XFile?> pickFoto(ImageSource source) async =>
      XFile(tempFoto.path);

  /// Viewport tinggi agar kartu rekomendasi (di bawah hasil) ikut hittable.
  void besarLayar(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget bungkus(RekomendasiService rekomendasi, {SessionStore? session}) {
    return MaterialApp(
      home: SkriningPage(
        service: _FakeSkriningService(),
        store: InMemoryRiwayatStore(),
        pickFoto: pickFoto,
        rekomendasiService: rekomendasi,
        sessionStore: session ?? InMemorySessionStore(),
      ),
    );
  }

  Future<void> keHasil(WidgetTester tester) async {
    await tester.tap(find.text('Kamera'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analisis Kuku'));
    await tester.pumpAndSettle();
  }

  testWidgets('kartu rekomendasi tertutup default, muncul setelah hasil', (
    tester,
  ) async {
    besarLayar(tester);
    final fake = _FakeRekomendasiService();
    await tester.pumpWidget(bungkus(fake));
    await keHasil(tester);

    // Tertutup: hanya tombol pembuka, belum ada form.
    expect(find.text('Rekomendasi tindak lanjut (fuzzy)'), findsOneWidget);
    expect(find.text('Hitung Rekomendasi'), findsNothing);
  });

  testWidgets('form → pilih gejala → hitung → badge rekomendasi tampil', (
    tester,
  ) async {
    besarLayar(tester);
    final fake = _FakeRekomendasiService();
    await tester.pumpWidget(bungkus(fake));
    await keHasil(tester);

    await tester.tap(find.text('Rekomendasi tindak lanjut (fuzzy)'));
    await tester.pumpAndSettle();
    expect(find.text('Gejala yang dirasakan'), findsOneWidget);
    expect(find.text('Faktor risiko'), findsOneWidget);
    expect(find.text('Tipe kulit (opsional)'), findsOneWidget);

    // Pilih satu gejala + satu risiko.
    await tester.tap(find.text('Pusing / sakit kepala'));
    await tester.pump();
    await tester.tap(find.text('Menstruasi berat'));
    await tester.pump();

    await tester.tap(find.text('Hitung Rekomendasi'));
    await tester.pumpAndSettle();

    expect(fake.lastGejala, 'pusing');
    expect(find.text('Segera periksa ke puskesmas/dokter — pemeriksaan darah (Hb)'), findsOneWidget);
    expect(find.textContaining('Visual 100%'), findsOneWidget);
    expect(find.text('Ubah jawaban'), findsOneWidget);
    expect(find.textContaining('BUKAN pengganti tenaga kesehatan'), findsOneWidget);
  });

  testWidgets('gagal: error service di form rekomendasi ditampilkan', (
    tester,
  ) async {
    besarLayar(tester);
    final fake = _FakeRekomendasiService(
      error: Exception('Tidak dapat terhubung ke server rekomendasi'),
    );
    await tester.pumpWidget(bungkus(fake));
    await keHasil(tester);

    await tester.tap(find.text('Rekomendasi tindak lanjut (fuzzy)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hitung Rekomendasi'));
    await tester.pumpAndSettle();

    expect(
      find.text('Tidak dapat terhubung ke server rekomendasi'),
      findsOneWidget,
    );
  });

  testWidgets('profil akun (hamil, riwayat anemia, kulit gelap) mengisi form '
      'rekomendasi otomatis', (tester) async {
    besarLayar(tester);
    final fake = _FakeRekomendasiService();
    final session = InMemorySessionStore();
    await session.simpan(
      'jwt.test',
      const Pasien(
        id: 'p1',
        username: 'sari',
        nama: 'Sari Amalia',
        usia: 24,
        gender: 'perempuan',
        tipeKulit: 'gelap',
        hamil: true,
        riwayatAnemia: true,
      ),
    );
    await tester.pumpWidget(bungkus(fake, session: session));
    await keHasil(tester);

    await tester.tap(find.text('Rekomendasi tindak lanjut (fuzzy)'));
    await tester.pumpAndSettle();

    // Pre-fill dari profil: jenis kulit 'Gelap' terpilih di dropdown.
    expect(find.text('Gelap'), findsOneWidget);

    // Checkbox risiko sudah tercentang dari profil.
    final hamil = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Sedang hamil'),
    );
    final riwayat = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Riwayat anemia'),
    );
    expect(hamil.value, isTrue);
    expect(riwayat.value, isTrue);

    // Hitung → backend menerima risiko & tipe kulit dari profil.
    await tester.tap(find.text('Hitung Rekomendasi'));
    await tester.pumpAndSettle();
    expect(fake.lastRisiko, 'hamil,riwayat_anemia');
    expect(fake.lastTipeKulit, 'gelap');
  });
}