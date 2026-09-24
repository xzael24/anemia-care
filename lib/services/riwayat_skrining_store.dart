import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/hasil_skrining.dart';

/// Seam penyimpanan riwayat skrining lokal (pola sama seperti JadwalStore).
/// sqflite tidak bisa jalan di widget test, jadi test inject store in-memory
/// (lihat test/fakes/in_memory_riwayat_store.dart).
abstract class RiwayatSkriningStore {
  Future<List<HasilSkrining>> muatTerbaru({int limit = 20});
  Future<void> tambah(HasilSkrining hasil);
}

/// Implementasi SQLite — pola DatabaseHelper singleton (sama dengan JadwalDbStore).
class RiwayatSkriningDbStore implements RiwayatSkriningStore {
  RiwayatSkriningDbStore._();

  static final RiwayatSkriningDbStore instance = RiwayatSkriningDbStore._();

  static Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'anemia_riwayat.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE riwayat_skrining (
          id TEXT PRIMARY KEY,
          indication TEXT NOT NULL,
          confidence REAL NOT NULL,
          hb_estimate REAL,
          source TEXT NOT NULL,
          image_name TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      '''),
    );
    return _db!;
  }

  @override
  Future<List<HasilSkrining>> muatTerbaru({int limit = 20}) async {
    final db = await _database;
    final maps = await db.query(
      'riwayat_skrining',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return maps.map(HasilSkrining.fromMap).toList();
  }

  @override
  Future<void> tambah(HasilSkrining hasil) async {
    final db = await _database;
    await db.insert(
      'riwayat_skrining',
      hasil.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}