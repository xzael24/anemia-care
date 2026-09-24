import 'package:anemia/models/jadwal_item.dart';
import 'package:anemia/services/jadwal_store.dart';

/// Fake store untuk test — implementasi [JadwalStore] di memori,
/// menggantikan SQLite (yang butuh plugin, tidak tersedia di widget test).
///
/// Karena model cuma kenal interface-nya, test bisa jalan offline
/// sekaligus tetap menguji logika persist (maunya datanya beneran
/// tersimpan ke "database" — lihat test "persisten" di jadwal_model_test).
class InMemoryJadwalStore implements JadwalStore {
  InMemoryJadwalStore({List<JadwalItem>? seed}) : _items = seed ?? [];

  final List<JadwalItem> _items;
  int _nextId = 1;

  @override
  Future<List<JadwalItem>> muatSemua() async => List.of(_items);

  @override
  Future<int> tambah(JadwalItem item) async {
    final id = _nextId++;
    _items.insert(
      0,
      JadwalItem(
        id: id,
        namaPasien: item.namaPasien,
        selesai: item.selesai,
        dibuatAt: item.dibuatAt,
      ),
    );
    return id;
  }

  @override
  Future<void> update(JadwalItem item) async {
    final i = _items.indexWhere((x) => x.id == item.id);
    if (i != -1) _items[i] = item;
  }

  @override
  Future<void> hapus(int id) async {
    _items.removeWhere((x) => x.id == id);
  }
}
