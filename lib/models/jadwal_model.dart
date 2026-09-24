import 'package:flutter/foundation.dart';

import '../services/jadwal_store.dart';
import 'jadwal_item.dart';

/// State global jadwal pemantauan (Modul 9 — Provider) + persist SQLite (Modul 11).
///
/// Modul 11: model tidak nyentuh SQLite langsung — dia kenal interface
/// [JadwalStore]. Kenapa? sqflite butuh plugin yang nggak ada di widget test,
/// jadi test inject store in-memory. Pola ini juga bikin logika bisnis
/// berdiri sendiri dari database.
class JadwalModel extends ChangeNotifier {
  JadwalModel({JadwalStore? store}) : _store = store ?? JadwalDbStore.instance {
    _init = _muat(); // load data lama dari database pas app start
  }

  final JadwalStore _store;
  late final Future<void> _init;
  List<JadwalItem> _items = [];
  bool _siap = false;

  /// Tunggu load awal selesai (dipakai di test biar nggak balapan sama _muat).
  Future<void> get init => _init;

  List<JadwalItem> get items => List.unmodifiable(_items);
  bool get siap => _siap;

  // Getter komputasi — tantangan dosen no. 1
  int get total => _items.length;
  int get jumlahBelumSelesai => _items.where((i) => !i.selesai).length;
  int get jumlahSelesai => _items.where((i) => i.selesai).length;
  double get persentaseSelesai =>
      _items.isEmpty ? 0 : (jumlahSelesai / _items.length) * 100;

  Future<void> _muat() async {
    final data = await _store.muatSemua();
    _items = data;
    _siap = true;
    notifyListeners();
  }

  Future<void> tambah(String namaPasien) async {
    if (namaPasien.trim().isEmpty) return;
    // Tolak duplikat biar satu pasien cuma satu jadwal
    if (_items.any((i) => i.namaPasien == namaPasien)) return;
    final item = JadwalItem(namaPasien: namaPasien);
    final id = await _store.tambah(item);
    // Insert di depan biar konsisten sama ORDER BY id DESC di DB
    _items.insert(
      0,
      JadwalItem(id: id, namaPasien: namaPasien, dibuatAt: item.dibuatAt),
    );
    notifyListeners();
  }

  Future<void> toggle(int id) async {
    final i = _items.indexWhere((x) => x.id == id);
    if (i == -1) return;
    _items[i].selesai = !_items[i].selesai;
    await _store.update(_items[i]);
    notifyListeners();
  }

  Future<void> hapus(int id) async {
    await _store.hapus(id);
    _items.removeWhere((x) => x.id == id);
    notifyListeners();
  }

  /// Tantangan dosen no. 2 — Hapus Semua Selesai
  Future<void> hapusSemuaSelesai() async {
    for (final item in _items.where((i) => i.selesai).toList()) {
      if (item.id != null) await _store.hapus(item.id!);
    }
    _items.removeWhere((i) => i.selesai);
    notifyListeners();
  }
}
