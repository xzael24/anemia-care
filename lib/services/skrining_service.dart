import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

import '../models/hasil_skrining.dart';

/// Client `POST /api/screening` — kirim foto kuku (multipart) ke backend
/// NestJS, terima indikasi awal + confidence + disclaimer.
///
/// Client HTTP bisa di-inject (MockClient di test). Base URL default
/// `10.0.2.2` = host Windows dari dalam Android emulator; di perangkat fisik
/// pakai `adb reverse tcp:3000 tcp:3000` lalu `http://localhost:3000/api`,
/// atau IP LAN.
class SkriningService {
  SkriningService({http.Client? client, this.baseUrl = _defaultBaseUrl})
    : _client = client ?? http.Client();

  static const _defaultBaseUrl = 'http://10.0.2.2:3007/api';

  final String baseUrl;
  final http.Client _client;

  /// Kirim foto → [HasilSkrining]. Melempar [Exception] dengan pesan ramah
  /// kalau server menolak (400) / gagal (5xx) / tidak terjangkau.
  ///
  /// [token] opsional: token pasien (dari sesi akun) membuat skrining
  /// tersimpan per akun di backend.
  Future<HasilSkrining> skriningFoto(File foto, {String? token}) async {
    final uri = Uri.parse('$baseUrl/screening');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(
        token == null ? const {} : {'Authorization': 'Bearer $token'},
      )
      ..files.add(
        await http.MultipartFile.fromPath(
          'photo',
          foto.path,
          filename: p.basename(foto.path),
          contentType: MediaType('image', _ekstensiGambar(foto.path)),
        ),
      );

    try {
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode == 201) {
        return HasilSkrining.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>,
        );
      }
      throw Exception(_pesanDariBody(res.body, res.statusCode));
    } on SocketException {
      throw Exception(
        'Tidak dapat terhubung ke server skrining ($baseUrl). '
        'Pastikan backend aktif: emulator otomatis pakai 10.0.2.2, '
        'perangkat fisik butuh "adb reverse tcp:3000 tcp:3000".',
      );
    } on TimeoutException {
      throw Exception('Waktu habis menunggu respons server skrining.');
    }
  }

  /// Menebak ekstensi MIME dari path file (picker kamera = jpeg, galeri = png).
  static String _ekstensiGambar(String path) {
    final e = p.extension(path).toLowerCase();
    return e == '.png' ? 'png' : 'jpeg';
  }

  /// Ambil pesan error dari body JSON backend (`{ "message": "..." }`),
  /// fallback ke kode HTTP.
  static String _pesanDariBody(String body, int status) {
    try {
      final j = jsonDecode(body);
      if (j is Map && j['message'] is String) {
        return j['message'] as String;
      }
    } on FormatException {
      // body bukan JSON — abaikan, pakai fallback
    }
    return 'Skrining gagal (HTTP $status)';
  }
}