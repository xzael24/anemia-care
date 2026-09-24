import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/jadwal_item.dart';

/// Seam penyimpanan jadwal — Modul 11.
/// Alasan: sqflite nggak bisa jalan di widget test (tanpa plugin),
/// jadi model cukup kenal interface ini & test inject store in-memory.
abstract class JadwalStore {
  Future<List<JadwalItem>> muatSemua();
  Future<int> tambah(JadwalItem item);
  Future<void> update(JadwalItem item);
  Future<void> hapus(int id);
}

/// Implementasi SQLite — pola DatabaseHelper singleton dari dosen.
class JadwalDbStore implements JadwalStore {
  JadwalDbStore._();

  static final JadwalDbStore instance = JadwalDbStore._();

  static Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'anemia_jadwal.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE jadwal (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nama TEXT NOT NULL,
          selesai INTEGER NOT NULL DEFAULT 0,
          dibuatAt TEXT NOT NULL
        )
      '''),
    );
    return _db!;
  }

  @override
  Future<List<JadwalItem>> muatSemua() async {
    final db = await _database;
    final maps = await db.query('jadwal', orderBy: 'id DESC');
    return maps.map(JadwalItem.fromMap).toList();
  }

  @override
  Future<int> tambah(JadwalItem item) async {
    final db = await _database;
    return db.insert('jadwal', item.toMap());
  }

  @override
  Future<void> update(JadwalItem item) async {
    final db = await _database;
    await db.update(
      'jadwal',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  @override
  Future<void> hapus(int id) async {
    final db = await _database;
    await db.delete('jadwal', where: 'id = ?', whereArgs: [id]);
  }
}
