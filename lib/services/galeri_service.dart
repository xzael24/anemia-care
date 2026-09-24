import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Parser nama file `foto_<timestampMs>.jpg` → DateTime (tantangan 2 Modul 12).
/// Return null kalau namanya bukan pola foto kita.
DateTime? tanggalDariNamaFile(String path) {
  final base = p.basenameWithoutExtension(path);
  if (!base.startsWith('foto_')) return null;
  final ms = int.tryParse(base.substring(5));
  return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
}

/// Modul 12 — service galeri hasil lab.
///
/// Semua operasi file lewat class ini. `getDir` bisa di-inject dari test
/// (diarahkan ke folder temp) karena `getApplicationDocumentsDirectory`
/// butuh plugin native yang nggak ada di widget test.
class GaleriLabService {
  GaleriLabService({Future<Directory> Function()? getDir})
    : _getDir = getDir ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _getDir;

  /// Ambil semua foto (.jpg) di direktori dokumen, terbaru di depan.
  Future<List<File>> muatSemua() async {
    final dir = await _getDir();
    final files = <File>[];
    await for (final entri in dir.list()) {
      if (entri is File && entri.path.endsWith('.jpg')) {
        files.add(entri);
      }
    }
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  /// Salin file hasil picker ke direktori dokumen (persisten).
  Future<File> simpanDari(String sumberPath) async {
    final dir = await _getDir();
    final nama = 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final tujuan = File(p.join(dir.path, nama));
    return File(sumberPath).copy(tujuan.path);
  }
}
