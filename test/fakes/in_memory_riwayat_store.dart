import 'package:anemia/models/hasil_skrining.dart';
import 'package:anemia/services/riwayat_skrining_store.dart';

/// Store in-memory untuk widget test (sqflite tidak bisa dijalankan di test).
class InMemoryRiwayatStore implements RiwayatSkriningStore {
  final List<HasilSkrining> items = [];

  @override
  Future<List<HasilSkrining>> muatTerbaru({int limit = 20}) async {
    final snapshot = [...items]..sort(
      (a, b) => b.createdAt.compareTo(a.createdAt),
    );
    return snapshot.take(limit).toList();
  }

  @override
  Future<void> tambah(HasilSkrining hasil) async {
    items.add(hasil);
  }
}