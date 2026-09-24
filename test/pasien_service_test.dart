import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:anemia/services/pasien_service.dart';

void main() {
  test('getUsers mem-parse JSON /users ke List<UserPasien>', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/users');
      return http.Response(
        jsonEncode([
          {
            'id': 1,
            'name': 'Silvi Rahmawati',
            'email': 'silvi@example.com',
            'address': {'city': 'Bandung'},
            'website': 'silvi.dev',
          },
          {
            'id': 2,
            'name': 'Budi Santoso',
            'email': 'budi@example.com',
            'address': {'city': 'Jakarta'},
            'website': '',
          },
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = PasienService(client: client);
    final users = await service.getUsers();

    expect(users.length, 2);
    expect(users.first.nama, 'Silvi Rahmawati');
    expect(users.first.kota, 'Bandung');
    expect(users.first.website, 'silvi.dev');
    expect(users.last.kota, 'Jakarta');
    expect(users.last.website, '');
  });

  test('getUsers melempar Exception saat status bukan 200', () async {
    final client = MockClient((request) async => http.Response('oops', 500));

    final service = PasienService(client: client);
    expect(service.getUsers(), throwsException);
  });

  test('tambahUser mengirim POST dan mem-parse respons 201', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/users');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['name'], 'Andi Pratama');
      expect(body['email'], 'andi@example.com');
      return http.Response(
        jsonEncode({
          'id': 11,
          'name': 'Andi Pratama',
          'email': 'andi@example.com',
          'address': {'city': 'Surabaya'},
          'website': 'andi.dev',
        }),
        201,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = PasienService(client: client);
    final user = await service.tambahUser('Andi Pratama', 'andi@example.com');

    expect(user.id, 11);
    expect(user.nama, 'Andi Pratama');
    expect(user.kota, 'Surabaya');
  });
}
