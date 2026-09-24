import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anemia/models/pasien.dart';
import 'package:anemia/services/session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Pasien contoh() => const Pasien(
    id: 'p1',
    username: 'sari',
    nama: 'Sari Amalia',
    usia: 24,
    gender: 'perempuan',
    tipeKulit: 'sedang',
    hamil: true,
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('simpan → muat mengembalikan token + pasien utuh', () async {
    final store = SessionPrefsStore.instance;
    await store.simpan('jwt.abc', contoh());

    final s = await store.muat();
    expect(s, isNotNull);
    expect(s!.token, 'jwt.abc');
    expect(s.pasien.username, 'sari');
    expect(s.pasien.nama, 'Sari Amalia');
    expect(s.pasien.usia, 24);
    expect(s.pasien.hamil, isTrue);
    expect(s.pasien.tipeKulit, 'sedang');
  });

  test('muat saat kosong → null', () async {
    final store = SessionPrefsStore.instance;
    expect(await store.muat(), isNull);
  });

  test('hapus → sesi hilang', () async {
    final store = SessionPrefsStore.instance;
    await store.simpan('jwt.abc', contoh());
    await store.hapus();
    expect(await store.muat(), isNull);
  });

  test('data JSON rusak → null (bukan crash)', () async {
    SharedPreferences.setMockInitialValues({
      'session_token': 'jwt.abc',
      'session_pasien': '{rusak',
    });
    expect(await SessionPrefsStore.instance.muat(), isNull);
  });
}