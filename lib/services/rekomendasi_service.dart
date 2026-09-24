import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import '../models/rekomendasi_hasil.dart';

/// Client `POST /api/rekomendasi` — kirim hasil visual ML + konteks singkat
/// (gejala/risiko/tipe kulit) → rekomendasi tindak lanjut fuzzy (PSC1).
///
/// Client HTTP bisa di-inject (MockClient di test). Base URL sama dengan
/// [SkriningService] (default emulator `10.0.2.2:3007`).
class RekomendasiService {
  RekomendasiService({http.Client? client, this.baseUrl = _defaultBaseUrl})
    : _client = client ?? http.Client();

  static const _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3007/api',
  );

  static const gejalaOptions = <String, String>{
    'pusing': 'Pusing / sakit kepala',
    'lemas': 'Lemas, cepat lelah',
    'berkunang': 'Berkunang-kunang',
    'pucat': 'Wajah / kuku tampak pucat',
    'sesak': 'Sesak napas ringan',
  };
  static const risikoOptions = <String, String>{
    'menstruasi': 'Menstruasi berat',
    'hamil': 'Sedang hamil',
    'riwayat_anemia': 'Riwayat anemia',
    'kurang_zat_besi': 'Asupan zat besi kurang',
  };
  static const kulitOptions = <String, String>{
    'terang': 'Terang',
    'sedang': 'Sedang',
    'gelap': 'Gelap',
  };

  final String baseUrl;
  final http.Client _client;

  /// Hitung rekomendasi. Melempar [Exception] dengan pesan ramah saat
  /// server menolak (400) / gagal (5xx) / tidak terjangkau.
  Future<RekomendasiHasil> rekomendasi({
    required String indication,
    required double confidence,
    double? hbEstimateGdl,
    List<String> gejala = const [],
    List<String> risiko = const [],
    String? tipeKulit,
  }) async {
    final uri = Uri.parse('$baseUrl/rekomendasi');
    final body = jsonEncode({
      'indication': indication,
      'confidence': confidence,
      'gejala': gejala,
      'risiko': risiko,
      'hbEstimateGdl': ?hbEstimateGdl,
      'tipeKulit': ?tipeKulit,
    });

    try {
      final res = await _client
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 201) {
        return RekomendasiHasil.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>,
        );
      }
      throw Exception(_pesanDariBody(res.body, res.statusCode));
    } on SocketException {
      throw Exception(
        'Tidak dapat terhubung ke server rekomendasi ($baseUrl). '
        'Pastikan backend aktif.',
      );
    } on TimeoutException {
      throw Exception('Waktu habis menunggu respons rekomendasi.');
    }
  }

  /// Ambil pesan error dari body JSON backend (`{ "message": ... }`),
  /// fallback ke kode HTTP.
  static String _pesanDariBody(String body, int status) {
    try {
      final j = jsonDecode(body);
      if (j is Map && j['message'] is String) {
        return j['message'] as String;
      }
    } on FormatException {
      // body bukan JSON — pakai fallback
    }
    return 'Rekomendasi gagal (HTTP $status)';
  }
}