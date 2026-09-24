import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:anemia/services/skrining_service.dart';

/// Smoke test end-to-end lintasan app → backend NESTJS lokal. Lewati
/// (skip diam-diam) kalau API belum aktif, supaya `flutter test` tetap hijau
/// di lingkungan tanpa compose.
///
/// Port 3007 = publikasi kedua docker-compose (khusus Docker, bebas konflik
/// loopback dengan tool lain yang ikut menguasai 3000 di host — lihat
/// docker-compose.yml).
void main() {
  test('POST /api/screening → indikasi valid + disclaimer (API lokal aktif)', () async {
    if (!await _apiAktif()) {
      debugPrint('[skrining_api_e2e] SKIP: API lokal tidak aktif (jalankan compose)');
      return;
    }

    // Foto asli dari dataset capstone (mirror di repo).
    final foto = File(
      'capstone/data/processed/test/images/ghana_anemic_Fin-007_0.jpg',
    );
    if (!foto.existsSync()) {
      debugPrint('[skrining_api_e2e] SKIP: gambar dataset tidak ditemukan');
      return;
    }

    final service = SkriningService(baseUrl: 'http://127.0.0.1:3007/api');
    final hasil = await service.skriningFoto(foto);

    expect(hasil.indication, anyOf('anemia', 'normal'));
    expect(hasil.confidence, greaterThanOrEqualTo(0.0));
    expect(hasil.confidence, lessThanOrEqualTo(1.0));
    expect(hasil.source, anyOf('ml', 'mock'));
    expect(hasil.disclaimer, contains('BUKAN diagnosis medis'));
  });
}

Future<bool> _apiAktif() async {
  try {
    final res = await http
        .get(Uri.parse('http://127.0.0.1:3007/api/health'))
        .timeout(const Duration(seconds: 3));
    // Pastikan yang menjawab benar-benar backend kita (bukan server lain).
    return res.statusCode == 200 && res.body.contains('"status":"ok"');
  } catch (_) {
    return false;
  }
}