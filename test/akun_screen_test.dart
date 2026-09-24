import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anemia/models/hasil_skrining.dart';
import 'package:anemia/models/pasien.dart';
import 'package:anemia/screens/akun_screen.dart';
import 'package:anemia/services/akun_service.dart';

import 'fakes/in_memory_session_store.dart';

/// Api akun palsu — tanpa HTTP. Bisa diprogram gagal login/daftar.
class _FakeAkunService extends AkunService {
  _FakeAkunService({this.gagal = false, this.riwayatItems = const []});

  final bool gagal;
  final List<HasilSkrining> riwayatItems;

  @override
  Future<PasienAuth> login({
    required String username,
    required String password,
  }) async {
    if (gagal) throw Exception('Username atau password salah');
    return _auth(username);
  }

  @override
  Future<PasienAuth> daftar({
    required String username,
    required String password,
    required String nama,
    required int usia,
    required String gender,
    String? tipeKulit,
    bool hamil = false,
    bool riwayatAnemia = false,
  }) async {
    if (gagal) throw Exception('Username sudah terpakai');
    return _auth(username, nama: nama, usia: usia, tipeKulit: tipeKulit);
  }

  @override
  Future<List<HasilSkrining>> riwayat(String token) async => riwayatItems;

  static PasienAuth _auth(
    String username, {
    String nama = 'Sari Amalia',
    int usia = 24,
    String? tipeKulit,
  }) {
    return PasienAuth(
      accessToken: 'jwt.test',
      pasien: Pasien(
        id: 'p1',
        username: username,
        nama: nama,
        usia: usia,
        gender: 'perempuan',
        tipeKulit: tipeKulit,
        hamil: true,
      ),
    );
  }
}

HasilSkrining hasilContoh() => const HasilSkrining(
  id: 's1',
  indication: 'anemia',
  confidence: 0.91,
  source: 'ml',
  imageName: 'kuku.jpg',
  createdAt: '2026-09-24T07:10:00.000Z',
  disclaimer: 'BUKAN diagnosis',
);

Widget bungkus(AkunPage page) => MaterialApp(home: page);

void main() {
  testWidgets('belum login → form Masuk tampil', (tester) async {
    await tester.pumpWidget(
      bungkus(
        AkunPage(
          service: _FakeAkunService(),
          session: InMemorySessionStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Masuk Akun'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('login sukses → profil akun tampil', (tester) async {
    await tester.pumpWidget(
      bungkus(
        AkunPage(
          service: _FakeAkunService(),
          session: InMemorySessionStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'sari');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'rahasia123');
    await tester.tap(find.text('Masuk Akun'));
    await tester.pumpAndSettle();

    expect(find.text('Sari Amalia'), findsOneWidget);
    expect(find.text('@sari'), findsOneWidget);
    expect(find.textContaining('24 th'), findsOneWidget);
    expect(find.textContaining('Hamil'), findsWidgets);
    expect(find.text('Keluar akun'), findsOneWidget);
  });

  testWidgets('login gagal → pesan error dari backend', (tester) async {
    await tester.pumpWidget(
      bungkus(
        AkunPage(
          service: _FakeAkunService(gagal: true),
          session: InMemorySessionStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'sari');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'salah');
    await tester.tap(find.text('Masuk Akun'));
    await tester.pumpAndSettle();

    expect(find.text('Username atau password salah'), findsOneWidget);
    expect(find.text('Sari Amalia'), findsNothing);
  });

  testWidgets('daftar sukses → profil + skrining terhubung akun', (tester) async {
    // Form daftar panjang → viewport besar agar semua field & tombol
    // ke-build (ListView anak di bawah fold belum dibuat kalau kependekan).
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      bungkus(
        AkunPage(
          service: _FakeAkunService(),
          session: InMemorySessionStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Daftar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Username (min. 3 karakter)'),
      'sari',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password (min. 6 karakter)'),
      'rahasia123',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Nama lengkap'), 'Sari Amalia');
    await tester.enterText(find.widgetWithText(TextField, 'Usia (tahun)'), '24');
    await tester.ensureVisible(find.text('Daftar Akun'));
    await tester.tap(find.text('Daftar Akun'));
    await tester.pumpAndSettle();

    expect(find.text('Sari Amalia'), findsOneWidget);
    expect(find.text('Keluar akun'), findsOneWidget);
  });

  testWidgets('sudah login → muat riwayat cloud → keluar kembali ke form', (tester) async {
    final session = InMemorySessionStore();
    await session.simpan(
      'jwt.test',
      const Pasien(
        id: 'p1',
        username: 'sari',
        nama: 'Sari Amalia',
        usia: 24,
        gender: 'perempuan',
        hamil: true,
      ),
    );

    await tester.pumpWidget(
      bungkus(
        AkunPage(
          service: _FakeAkunService(
            riwayatItems: [hasilContoh()],
          ),
          session: session,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sari Amalia'), findsOneWidget);
    expect(find.text('Muat riwayat saya'), findsOneWidget);

    await tester.tap(find.text('Muat riwayat saya'));
    await tester.pumpAndSettle();

    expect(find.text('kuku.jpg'), findsOneWidget);
    expect(find.textContaining('Indikasi anemia'), findsOneWidget);

    await tester.tap(find.text('Keluar akun'));
    await tester.pumpAndSettle();

    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Sari Amalia'), findsNothing);
  });
}