import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:anemia/services/skrining_service.dart';

void main() {
  late Directory tempDir;
  late File fotoJpg;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('skrining_svc');
    fotoJpg = File('${tempDir.path}/kuku_test.jpg')..writeAsBytesSync([1, 2, 3]);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  const hasilJson = {
    'id': 'c8f7-1234',
    'indication': 'anemia',
    'confidence': 0.92,
    'hbEstimateGdl': 10.5,
    'source': 'ml',
    'imageName': 'kuku.jpg',
    'createdAt': '2026-09-24T07:20:00.000Z',
    'disclaimer': 'Hasil ini indikasi awal skrining non-invasif, BUKAN diagnosis medis.',
  };

  SkriningService serviceDengan(MockClient client) =>
      SkriningService(client: client, baseUrl: 'http://localhost:3000/api');

  test('kirim multipart field "photo" + parse hasil 201', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/screening');
      final body = utf8.decode(request.bodyBytes, allowMalformed: true);
      expect(body, contains('name="photo"'));
      expect(body, contains('filename="kuku_test.jpg"'));
      expect(body, contains('content-type: image/jpeg'));
      // Default mode close-up ikut dikirim.
      expect(body, contains('name="mode"'));
      expect(body, contains('name="mode"\r\n\r\ncloseup'));
      return http.Response(
        jsonEncode(hasilJson),
        201,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = serviceDengan(client);
    final hasil = await service.skriningFoto(fotoJpg);

    expect(hasil.id, 'c8f7-1234');
    expect(hasil.anemia, isTrue);
    expect(hasil.confidence, 0.92);
    expect(hasil.hbEstimateGdl, 10.5);
    expect(hasil.source, 'ml');
    expect(hasil.disclaimer, contains('BUKAN diagnosis medis'));
  });

  test('hbEstimateGdl null direspons tanpa error', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({...hasilJson, 'hbEstimateGdl': null}),
        201,
        headers: {'content-type': 'application/json'},
      ),
    );

    final hasil = await serviceDengan(client).skriningFoto(fotoJpg);
    expect(hasil.hbEstimateGdl, isNull);
  });

  test('status 400 → pesan dari body JSON backend', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({'message': 'File harus berupa gambar'}),
        400,
        headers: {'content-type': 'application/json'},
      ),
    );

    final service = serviceDengan(client);
    expect(
      () => service.skriningFoto(fotoJpg),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'pesan',
          contains('File harus berupa gambar'),
        ),
      ),
    );
  });

  test('status 500 → fallback HTTP code', () async {
    final client = MockClient((request) async => http.Response('oops', 500));

    final service = serviceDengan(client);
    expect(
      () => service.skriningFoto(fotoJpg),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'pesan',
          contains('HTTP 500'),
        ),
      ),
    );
  });

  test('token pasien → header Authorization=Bearer dikirim', () async {
    final client = MockClient((request) async {
      expect(
        request.headers['Authorization'],
        'Bearer jwt.pasien.123',
      );
      return http.Response(
        jsonEncode(hasilJson),
        201,
        headers: {'content-type': 'application/json'},
      );
    });

    final hasil = await serviceDengan(client).skriningFoto(
      fotoJpg,
      token: 'jwt.pasien.123',
    );
    expect(hasil.id, 'c8f7-1234');
  });

  test('tanpa token → header Authorization tidak dikirim', () async {
    final client = MockClient((request) async {
      expect(request.headers.containsKey('Authorization'), isFalse);
      return http.Response(
        jsonEncode(hasilJson),
        201,
        headers: {'content-type': 'application/json'},
      );
    });
    await serviceDengan(client).skriningFoto(fotoJpg);
  });

  test('mode tangan penuh → field multipart mode=hand', () async {
    final client = MockClient((request) async {
      final body = utf8.decode(request.bodyBytes, allowMalformed: true);
      expect(body, contains('name="mode"\r\n\r\nhand'));
      return http.Response(
        jsonEncode(hasilJson),
        201,
        headers: {'content-type': 'application/json'},
      );
    });

    final hasil =
        await serviceDengan(client).skriningFoto(fotoJpg, mode: 'tangan');
    expect(hasil.id, 'c8f7-1234');
  });

  test('SocketException → pesan ramah "tidak dapat terhubung"', () async {
    final client = MockClient(
      (request) async => throw const SocketException('connection refused'),
    );

    final service = serviceDengan(client);
    expect(
      () => service.skriningFoto(fotoJpg),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'pesan',
          contains('Tidak dapat terhubung'),
        ),
      ),
    );
  });
}