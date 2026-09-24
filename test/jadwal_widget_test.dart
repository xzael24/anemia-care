import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anemia/main.dart';
import 'package:anemia/models/jadwal_item.dart';

import 'fakes/in_memory_jadwal_store.dart';

/// Modul 13 — tantangan no. 3 dosen (bonus): widget test untuk fitur
/// tambah/toggle/hapus jadwal. Di level MODEL sudah diuji (jadwal_model_test);
/// ini melengkapi di level UI: centang CheckboxListTile, hapus item,
/// Hapus Semua Selesai — dengan tester.pump() setelah tiap aksi.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpApp(WidgetTester tester, InMemoryJadwalStore store) async {
    await tester.pumpWidget(AnemiaApp(jadwalStore: store));
    await tester.pumpAndSettle();
  }

  Future<void> keTabJadwal(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Jadwal'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Jadwal UI: toggle centang, hapus item, Hapus Semua Selesai', (
    tester,
  ) async {
    final store = InMemoryJadwalStore(
      seed: [
        JadwalItem(
          id: 1,
          namaPasien: 'Silvi Rahmawati',
          selesai: false,
          dibuatAt: '2026-01-01T08:00:00',
        ),
        JadwalItem(
          id: 2,
          namaPasien: 'Budi Santoso',
          selesai: false,
          dibuatAt: '2026-01-02T08:00:00',
        ),
      ],
    );

    await pumpApp(tester, store);
    await keTabJadwal(tester);

    // Seed awal: 2 item, semua belum selesai
    expect(find.text('2 belum selesai'), findsOneWidget);
    expect(find.text('Silvi Rahmawati'), findsOneWidget);
    expect(find.text('Budi Santoso'), findsOneWidget);

    // Toggle Silvi → selesai (tap baris CheckboxListTile)
    await tester.tap(find.text('Silvi Rahmawati'));
    await tester.pumpAndSettle();
    expect(find.text('1 belum selesai'), findsOneWidget);
    expect(find.text('Hapus Semua Selesai'), findsOneWidget);

    // Hapus item Budi via ikon delete_outline (ada 2 item = 2 ikon delete,
    // jadi target descendant di baris Budi spesifik)
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(CheckboxListTile, 'Budi Santoso'),
        matching: find.byIcon(Icons.delete_outline),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Budi Santoso'), findsNothing);
    expect(find.text('Silvi Rahmawati'), findsOneWidget);

    // Hapus Semua Selesai → Silvi hilang → empty state
    await tester.tap(find.text('Hapus Semua Selesai'));
    await tester.pumpAndSettle();
    expect(find.text('Silvi Rahmawati'), findsNothing);
    expect(find.text('Belum ada jadwal.'), findsOneWidget);
  });
}
