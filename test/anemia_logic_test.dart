import 'package:flutter_test/flutter_test.dart';

import 'package:anemia/models/anemia_logic.dart';

/// Modul 13 — adaptasi tantangan no. 1 dosen ("5 test Kalkulator").
/// Kalkulator → AnemiaLogic: class murni Dart yang beneran dipakai app.
/// Struktur test mengikuti materi dosen: group + setUp + pola AAA.
void main() {
  group('AnemiaLogic.statusAnemia', () {
    test('Hb di bawah 12.0 → anemia', () {
      // Arrange + Act + Assert (pola AAA)
      expect(AnemiaLogic.statusAnemia(10.2), isTrue);
    });

    test('Hb normal (>= 12.0) → bukan anemia', () {
      expect(AnemiaLogic.statusAnemia(13.5), isFalse);
    });

    test('EDGE: Hb tepat 12.0 = normal, bukan anemia', () {
      expect(AnemiaLogic.statusAnemia(12.0), isFalse);
    });

    test('EDGE: Hb ekstrem rendah (0.0) tetap anemia', () {
      expect(AnemiaLogic.statusAnemia(0.0), isTrue);
    });
  });

  group('AnemiaLogic.tingkatKeparahan', () {
    test('klasifikasi lengkap lima nilai', () {
      expect(AnemiaLogic.tingkatKeparahan(15.0), TingkatAnemia.normal);
      expect(AnemiaLogic.tingkatKeparahan(11.5), TingkatAnemia.ringan);
      expect(AnemiaLogic.tingkatKeparahan(9.8), TingkatAnemia.sedang);
      expect(AnemiaLogic.tingkatKeparahan(6.9), TingkatAnemia.berat);
    });

    test('EDGE: batas band 11.0 = ringan, 8.0 = sedang, 7.9 = berat', () {
      expect(AnemiaLogic.tingkatKeparahan(11.0), TingkatAnemia.ringan);
      expect(AnemiaLogic.tingkatKeparahan(8.0), TingkatAnemia.sedang);
      expect(AnemiaLogic.tingkatKeparahan(7.9), TingkatAnemia.berat);
    });

    test('EDGE: tepat 12.0 = normal', () {
      expect(AnemiaLogic.tingkatKeparahan(12.0), TingkatAnemia.normal);
    });
  });

  group('AnemiaLogic.persentaseAnemia', () {
    setUp(() {
      // (contoh materi dosen — setUp dipakai kalau butuh state; di sini
      // cukup dokumentatif, semua method statis)
    });

    test('2 dari 3 pasien anemia → 66.67% (closeTo untuk double)', () {
      final persen = AnemiaLogic.persentaseAnemia([12.5, 10.2, 9.8]);
      expect(persen, closeTo(66.67, 0.01));
    });

    test('list kosong → 0 (jangan bagi nol)', () {
      expect(AnemiaLogic.persentaseAnemia([]), 0);
    });

    test('semua normal → 0; semua anemia → 100', () {
      expect(AnemiaLogic.persentaseAnemia([12.1, 13.0, 15.0]), 0);
      expect(AnemiaLogic.persentaseAnemia([5.0, 8.0, 11.0]), 100);
    });
  });

  group('AnemiaLogic.deltaHb', () {
    test('di bawah batas → negatif', () {
      expect(AnemiaLogic.deltaHb(10.2), closeTo(-1.8, 0.001));
    });

    test('di atas batas → positif; pas batas → 0', () {
      expect(AnemiaLogic.deltaHb(14.5), 2.5);
      expect(AnemiaLogic.deltaHb(12.0), 0);
    });
  });
}
