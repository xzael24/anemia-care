import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:anemia/services/akun_service.dart';

void main() {
  AkunService serviceDengan(MockClient client) =>
      AkunService(client: client, baseUrl: 'http://localhost:3000/api');

  const authJson = {
    'accessToken': 'jwt.token.pasien',
    'expiresIn': '8h',
    'pasien': {
      'id': 'p1',
      'username': 'sari',
      'nama': 'Sari Amalia',
      'usia': 24,
      'gender': 'perempuan',
      'tipeKulit': 'sedang',
      'hamil': true,
      'riwayatAnemia': false,
      'createdAt': '2026-09-24T07:00:00.000Z',
    },
  };

  test('daftar → POST body benar + parse PasienAuth', () async {
    late Map<String, dynamic> body;
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/pasien/daftar');
      body = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode(authJson),
        201,
        headers: {'content-type': 'application/json'},
      );
    });

    final auth = await serviceDengan(client).daftar(
      username: 'sari',
      password: 'rahasia123',
      nama: 'Sari Amalia',
      usia: 24,
      gender: 'perempuan',
      tipeKulit: 'sedang',
      hamil: true,
    );

    expect(auth.accessToken, 'jwt.token.pasien');
    expect(auth.pasien.username, 'sari');
    expect(auth.pasien.hamil, isTrue);
    expect(body['username'], 'sari');
    expect(body['usia'], 24);
    expect(body['tipeKulit'], 'sedang');
  });

  test('daftar tanpa tipeKulit → key tidak dikirim', () async {
    late Map<String, dynamic> body;
    final client = MockClient((request) async {
      body = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode(authJson),
        201,
        headers: {'content-type': 'application/json'},
      );
    });
    await serviceDengan(client).daftar(
      username: 'sari',
      password: 'rahasia123',
      nama: 'Sari',
      usia: 30,
      gender: 'laki',
    );
    expect(body.containsKey('tipeKulit'), isFalse);
  });

  test('daftar 409 → pesan duplikat dari backend', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({'message': 'Username sudah terpakai', 'statusCode': 409}),
        409,
        headers: {'content-type': 'application/json'},
      ),
    );
    expect(
      () => serviceDengan(client).daftar(
        username: 'sari',
        password: 'rahasia123',
        nama: 'Sari',
        usia: 24,
        gender: 'perempuan',
      ),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'pesan',
          contains('Username sudah terpakai'),
        ),
      ),
    );
  });

  test('login → POST + parse; login 401 → pesan salah kredensial', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/pasien/login');
      return http.Response(
        jsonEncode(authJson),
        201,
        headers: {'content-type': 'application/json'},
      );
    });
    final auth = await serviceDengan(client).login(
      username: 'sari',
      password: 'rahasia123',
    );
    expect(auth.pasien.nama, 'Sari Amalia');

    final gagal = MockClient(
      (request) async => http.Response(
        jsonEncode({'message': 'Username atau password salah'}),
        401,
        headers: {'content-type': 'application/json'},
      ),
    );
    expect(
      () => serviceDengan(gagal).login(username: 'sari', password: 'salah'),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'pesan',
          contains('Username atau password salah'),
        ),
      ),
    );
  });

  test('me → kirim Authorization Bearer + parse profil', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/pasien/me');
      expect(request.headers['Authorization'], 'Bearer jwt.token.pasien');
      return http.Response(
        jsonEncode(authJson['pasien']),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final me = await serviceDengan(client).me('jwt.token.pasien');
    expect(me.username, 'sari');
    expect(me.tipeKulit, 'sedang');
  });

  test('riwayat → parse list HasilSkrining', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/pasien/me/skrining');
      return http.Response(
        jsonEncode([
          {
            'id': 's1',
            'indication': 'anemia',
            'confidence': 0.91,
            'source': 'ml',
            'imageName': 'kuku.jpg',
            'createdAt': '2026-09-24T07:10:00.000Z',
            'pasienId': 'p1',
          },
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final list = await serviceDengan(client).riwayat('jwt.token.pasien');
    expect(list, hasLength(1));
    expect(list.first.anemia, isTrue);
    expect(list.first.imageName, 'kuku.jpg');
  });

  test('SocketException → pesan ramah "Tidak dapat terhubung"', () async {
    final client = MockClient(
      (request) async => throw const SocketException('connection refused'),
    );
    expect(
      () => serviceDengan(client).login(username: 'x', password: 'y'),
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