import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import '../models/hasil_skrining.dart';
import '../models/pasien.dart';

/// Client API akun pasien mobile (`/api/pasien`): daftar, login, profil,
/// dan riwayat skrining per akun.
///
/// Base URL sama dengan `SkriningService` (default emulator `10.0.2.2:3007`).
class AkunService {
  AkunService({http.Client? client, this.baseUrl = _defaultBaseUrl})
    : _client = client ?? http.Client();

  static const _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // Default emulator: `10.0.2.2` = host Windows dari dalam Android emulator.
    // Untuk HP fisik / server: flutter build apk --dart-define=API_BASE_URL=http://IP_LAN:3007/api
    defaultValue: 'http://10.0.2.2:3007/api',
  );

  final String baseUrl;
  final http.Client _client;

  /// Daftar akun baru → [PasienAuth]. Melempar [Exception] pesan ramah.
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
    final json = await _post('/pasien/daftar', {
      'username': username,
      'password': password,
      'nama': nama,
      'usia': usia,
      'gender': gender,
      'tipeKulit': ?tipeKulit,
      'hamil': hamil,
      'riwayatAnemia': riwayatAnemia,
    });
    return PasienAuth.fromJson(json);
  }

  /// Login → [PasienAuth].
  Future<PasienAuth> login({
    required String username,
    required String password,
  }) async {
    final json = await _post('/pasien/login', {
      'username': username,
      'password': password,
    });
    return PasienAuth.fromJson(json);
  }

  /// Profil akun (butuh token pasien).
  Future<Pasien> me(String token) async {
    final json = await _get('/pasien/me', token);
    return Pasien.fromJson(json);
  }

  /// Riwayat skrining milik akun (butuh token pasien).
  Future<List<HasilSkrining>> riwayat(String token) async {
    final list = await _getList('/pasien/me/skrining', token);
    return list
        .map((j) => HasilSkrining.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      final j = _decode(res);
      if (res.statusCode == 201) {
        return j as Map<String, dynamic>;
      }
      throw Exception(_pesan(j, res.statusCode));
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server ($baseUrl).');
    } on TimeoutException {
      throw Exception('Waktu habis menunggu respons server.');
    }
  }

  Future<Map<String, dynamic>> _get(String path, String token) async {
    final j = await _getRaw(path, token);
    return j as Map<String, dynamic>;
  }

  Future<List<dynamic>> _getList(String path, String token) async {
    final j = await _getRaw(path, token);
    return j as List<dynamic>;
  }

  Future<dynamic> _getRaw(String path, String token) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final res = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      final j = _decode(res);
      if (res.statusCode == 200) {
        return j;
      }
      throw Exception(_pesan(j, res.statusCode));
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server ($baseUrl).');
    } on TimeoutException {
      throw Exception('Waktu habis menunggu respons server.');
    }
  }

  static dynamic _decode(http.Response res) {
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      return null;
    }
  }

  static String _pesan(dynamic j, int status) {
    if (j is Map && j['message'] is String) {
      return j['message'] as String;
    }
    return 'Permintaan gagal (HTTP $status)';
  }
}