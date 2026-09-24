import 'package:flutter_test/flutter_test.dart';

import 'package:anemia/models/jadwal_model.dart';

import 'fakes/in_memory_jadwal_store.dart';

void main() {
  test(
    'JadwalModel: tambah, tolak duplikat, toggle, persentase, hapus',
    () async {
      final model = JadwalModel(store: InMemoryJadwalStore());
      await model.init;

      // Kosong
      expect(model.total, 0);
      expect(model.persentaseSelesai, 0);

      // Tambah + tolak input kosong & duplikat
      await model.tambah('Silvi Rahmawati');
      await model.tambah('   ');
      await model.tambah('Silvi Rahmawati');
      expect(model.total, 1);
      expect(model.jumlahBelumSelesai, 1);
      expect(model.persentaseSelesai, 0);

      // Toggle (by id) → selesai
      await model.toggle(model.items.first.id!);
      expect(model.jumlahSelesai, 1);
      expect(model.jumlahBelumSelesai, 0);
      expect(model.persentaseSelesai, 100);

      // Tambah satu lagi, tandai selesai, lalu Hapus Semua Selesai
      await model.tambah('Budi Santoso');
      await model.toggle(model.items.first.id!); // Budi (insert di depan)
      await model.hapusSemuaSelesai();
      expect(model.items, isEmpty);
      expect(model.persentaseSelesai, 0);
    },
  );

  test(
    'JadwalModel: persisten — model baru (restart) memuat data lama',
    () async {
      final store = InMemoryJadwalStore();

      // Sesi pertama: tambah + toggle
      final model1 = JadwalModel(store: store);
      await model1.init;
      await model1.tambah('Silvi Rahmawati');
      await model1.toggle(model1.items.first.id!);

      // "Restart app" — store sama, model baru → data tetap ada
      final model2 = JadwalModel(store: store);
      await model2.init;
      expect(model2.total, 1);
      expect(model2.items.first.namaPasien, 'Silvi Rahmawati');
      expect(model2.items.first.selesai, true);

      // Hapus juga persist
      await model2.hapus(model2.items.first.id!);
      final model3 = JadwalModel(store: store);
      await model3.init;
      expect(model3.items, isEmpty);
    },
  );
}
