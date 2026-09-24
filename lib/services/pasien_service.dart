import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/user_pasien.dart';

/// Service class — Modul 10: semua logika HTTP dipisah dari widget
/// biar rapi dan mudah di-test. Client bisa di-inject (MockClient di test).
class PasienService {
  PasienService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _baseUrl = 'https://jsonplaceholder.typicode.com';

  /// GET — ambil daftar pasien (endpoint /users JSONPlaceholder).
  Future<List<UserPasien>> getUsers() async {
    final response = await _client.get(Uri.parse('$_baseUrl/users'));

    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list
          .map((j) => UserPasien.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Gagal memuat data (HTTP ${response.statusCode})');
  }

  /// POST — tambah pasien baru.
  Future<UserPasien> tambahUser(String nama, String email) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/users'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': nama, 'email': email}),
    );

    if (response.statusCode == 201) {
      return UserPasien.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw Exception('Gagal menambah data (HTTP ${response.statusCode})');
  }
}
