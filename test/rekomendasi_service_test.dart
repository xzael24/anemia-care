import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:anemia/services/rekomendasi_service.dart';

const _jsonUtf8 = {'content-type': 'application/json; charset=utf-8'};

void main() {
  test('sukses: 201 → RekomendasiHasil ter-parse (termasuk skor)', () async {
    late http.Request captured;
    final mock = MockClient((req) async {
      captured = req;
      return http.Response(
        jsonEncode({
          'rekomendasi': 0.837,
          'tingkat': 'tinggi',
          'emoji': '🔴',
          'label': 'Segera periksa ke puskesmas/dokter — pemeriksaan darah (Hb)',
          'pesan': 'Indikasi visual cukup kuat...',
          'skor': {'visual': 1.0, 'gejala': 0.4, 'risiko': 0.5},
          'disclaimer': 'Rekomendasi ini hasil gabungan... BUKAN pengganti tenaga kesehatan.',
        }),
        201,
        headers: _jsonUtf8,
      );
    });

    final svc = RekomendasiService(client: mock, baseUrl: 'http://x/api');
    final hasil = await svc.rekomendasi(
      indication: 'anemia',
      confidence: 0.92,
      hbEstimateGdl: 10.5,
      gejala: ['pusing', 'lemas'],
      risiko: ['hamil'],
      tipeKulit: 'gelap',
    );

    expect(hasil.tingkat, 'tinggi');
    expect(hasil.adalahTinggi, true);
    expect(hasil.emoji, '🔴');
    expect(hasil.skorVisual, 1.0);
    expect(hasil.skorGejala, 0.4);
    expect(hasil.skorRisiko, 0.5);

    // Request benar: path, method, dan body JSON.
    expect(captured.url.path, '/api/rekomendasi');
    expect(captured.method, 'POST');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['indication'], 'anemia');
    expect(body['confidence'], 0.92);
    expect(body['hbEstimateGdl'], 10.5);
    expect(body['gejala'], ['pusing', 'lemas']);
    expect(body['risiko'], ['hamil']);
    expect(body['tipeKulit'], 'gelap');
  });

  test('400: pesan message dari backend ditampilkan', () async {
    final mock = MockClient(
      (_) async => http.Response(
        jsonEncode({'message': 'confidence harus 0..1'}),
        400,
        headers: _jsonUtf8,
      ),
    );
    final svc = RekomendasiService(client: mock, baseUrl: 'http://x/api');

    expect(
      () => svc.rekomendasi(indication: 'anemia', confidence: 5),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'pesan',
          contains('confidence harus 0..1'),
        ),
      ),
    );
  });

  test('5xx dengan body non-JSON → pesan fallback HTTP', () async {
    final mock = MockClient((_) async => http.Response('boom', 500));
    final svc = RekomendasiService(client: mock, baseUrl: 'http://x/api');

    expect(
      () => svc.rekomendasi(indication: 'anemia', confidence: 0.5),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'pesan',
          contains('HTTP 500'),
        ),
      ),
    );
  });

  test('body tanpa gejala/risiko/tipeKulit → field opsional kosong/tak dikirim', () async {
    late http.Request captured;
    final mock = MockClient((req) async {
      captured = req;
      return http.Response(
        jsonEncode({
          'rekomendasi': 0.129,
          'tingkat': 'rendah',
          'emoji': '🟢',
          'label': 'Tetap pola makan sehat & skrining berkala',
          'pesan': 'Tidak ada tanda mengkhawatirkan.',
          'skor': {'visual': 0.1, 'gejala': 0, 'risiko': 0},
          'disclaimer': 'x',
        }),
        201,
        headers: _jsonUtf8,
      );
    });
    final svc = RekomendasiService(client: mock, baseUrl: 'http://x/api');

    final hasil = await svc.rekomendasi(indication: 'normal', confidence: 0.9);
    expect(hasil.tingkat, 'rendah');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['gejala'], isEmpty);
    expect(body['risiko'], isEmpty);
    expect(body.containsKey('tipeKulit'), false);
    expect(body.containsKey('hbEstimateGdl'), false);
  });
}