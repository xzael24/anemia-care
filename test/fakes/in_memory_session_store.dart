import 'package:anemia/models/pasien.dart';
import 'package:anemia/services/session_store.dart';

/// Sesi in-memory untuk widget test — tanpa SharedPreferences.
class InMemorySessionStore implements SessionStore {
  String? _token;
  Pasien? _pasien;

  @override
  Future<void> simpan(String token, Pasien pasien) async {
    _token = token;
    _pasien = pasien;
  }

  @override
  Future<({String token, Pasien pasien})?> muat() async {
    final t = _token;
    final p = _pasien;
    if (t == null || p == null) return null;
    return (token: t, pasien: p);
  }

  @override
  Future<void> hapus() async {
    _token = null;
    _pasien = null;
  }
}