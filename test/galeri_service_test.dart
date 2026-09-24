import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:anemia/services/galeri_service.dart';

void main() {
  late Directory tempDir;
  late GaleriLabService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('galeri_svc_');
    service = GaleriLabService(getDir: () async => tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test(
    'muatSemua: ambil .jpg saja, terbaru di depan, abaikan file lain',
    () async {
      await File(p.join(tempDir.path, 'foto_1000.jpg')).writeAsBytes([1]);
      await File(p.join(tempDir.path, 'foto_5000.jpg')).writeAsBytes([2]);
      await File(p.join(tempDir.path, 'catatan.txt'))
          .writeAsString('bukan foto');

      final fotos = await service.muatSemua();

      expect(fotos.length, 2);
      expect(p.basename(fotos.first.path), 'foto_5000.jpg');
      expect(p.basename(fotos.last.path), 'foto_1000.jpg');
    },
  );

  test(
    'simpanDari: salin ke direktori dokumen dengan nama foto_<ts>.jpg',
    () async {
      final sumber = File(p.join(tempDir.path, 'sumber_sementara.jpg'))
        ..writeAsBytesSync([9, 9, 9]);

      final tersimpan = await service.simpanDari(sumber.path);

      expect(p.basename(tersimpan.path), startsWith('foto_'));
      expect(p.basename(tersimpan.path), endsWith('.jpg'));
      expect(tersimpan.parent.path, tempDir.path);
      expect(await tersimpan.readAsBytes(), [9, 9, 9]);
    },
  );

  test('tanggalDariNamaFile: parse timestamp, null untuk nama aneh', () {
    expect(
      tanggalDariNamaFile('foto_1000.jpg'),
      DateTime.fromMillisecondsSinceEpoch(1000),
    );
    expect(tanggalDariNamaFile('beasiswa_1.jpg'), isNull);
    expect(tanggalDariNamaFile('foto_abc.jpg'), isNull);
    expect(tanggalDariNamaFile('foto_.jpg'), isNull);
  });
}
