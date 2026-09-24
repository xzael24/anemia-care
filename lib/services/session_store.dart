import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/pasien.dart';

/// Sesi login pasien: token JWT + profil, disimpan di perangkat.
/// Implementasi: SessionPrefsStore (SharedPreferences) — bisa di-inject
/// fake in-memory di widget test.
abstract class SessionStore {
  Future<void> simpan(String token, Pasien pasien);
  Future<({String token, Pasien pasien})?> muat();
  Future<void> hapus();
}

class SessionPrefsStore implements SessionStore {
  SessionPrefsStore._();

  static final SessionPrefsStore instance = SessionPrefsStore._();

  static const _kToken = 'session_token';
  static const _kPasien = 'session_pasien';

  @override
  Future<void> simpan(String token, Pasien pasien) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
    await prefs.setString(_kPasien, jsonEncode(pasien.toJson()));
  }

  @override
  Future<({String token, Pasien pasien})?> muat() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken);
    final raw = prefs.getString(_kPasien);
    if (token == null || token.isEmpty || raw == null) {
      return null;
    }
    try {
      final pasien = Pasien.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return (token: token, pasien: pasien);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> hapus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kPasien);
  }
}