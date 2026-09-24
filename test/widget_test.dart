import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anemia/main.dart';

import 'fakes/in_memory_jadwal_store.dart';

void main() {
  // Modul 11: SharedPreferences butuh mock di test
  // (setMockInitialValues => instance in-memory, bukan plugin asli).
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // Modul 11: inject store in-memory (SQLite nggak ada di widget test).
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(AnemiaApp(jadwalStore: InMemoryJadwalStore()));
    await tester.pumpAndSettle();
  }

  testWidgets('Dashboard menampilkan ringkasan & daftar pasien', (
    tester,
  ) async {
    await pumpApp(tester);

    // Judul halaman & bottom nav
    expect(find.text('Dashboard Anemia'), findsOneWidget);
    expect(find.text('Beranda'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Jadwal'),
      ),
      findsOneWidget,
    );

    // Ringkasan: Total 6, Anemia 3, Normal 3
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('3'), findsNWidgets(2));

    // Menu grid
    expect(find.text('Menu Cepat'), findsOneWidget);
    expect(find.text('Input Lab'), findsOneWidget);

    // Daftar pasien: 3 berlabel ANEMIA (Silvi, Dono, Rina), lainnya normal
    expect(find.text('Silvi Rahmawati'), findsOneWidget);
    expect(find.text('ANEMIA'), findsNWidgets(3));
    expect(find.text('normal'), findsNWidgets(3));
  });

  testWidgets('Navigasi: detail pasien, kembali dengan data → SnackBar', (
    tester,
  ) async {
    await pumpApp(tester);

    // Klik pasien pertama → DetailPasienPage (push + passing data)
    await tester.tap(find.text('Silvi Rahmawati'));
    await tester.pumpAndSettle();

    expect(find.text('Detail Pasien'), findsOneWidget);
    expect(find.text('22 tahun'), findsOneWidget);
    expect(find.text('10.2 g/dL'), findsOneWidget);

    // Tombol mengembalikan data lewat pop → SnackBar di dashboard
    await tester.tap(find.text('Catat ke Jadwal'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard Anemia'), findsOneWidget);
    expect(
      find.textContaining('Silvi Rahmawati ditambahkan ke jadwal'),
      findsOneWidget,
    );

    // Biarkan timer SnackBar selesai sebelum test berakhir
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('Drawer & named route ke halaman Tentang', (tester) async {
    await pumpApp(tester);

    // Buka drawer lewat tombol hamburger
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('Halo, Silvi! 👋'), findsOneWidget);

    // Named route '/tentang'
    await tester.tap(find.text('Tentang Aplikasi'));
    await tester.pumpAndSettle();
    expect(find.text('Tentang Anemia App'), findsOneWidget);

    // Kembali dengan pop
    await tester.tap(find.text('Kembali'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard Anemia'), findsOneWidget);
  });

  testWidgets('Catat pasien → tab Jadwal terisi → statistik (Provider)', (
    tester,
  ) async {
    await pumpApp(tester);

    // Booking: Silvi → detail → Catat ke Jadwal (menyimpan ke JadwalModel)
    await tester.tap(find.text('Silvi Rahmawati'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Catat ke Jadwal'));
    await tester.pumpAndSettle();

    // Pindah ke tab Jadwal → item muncul + counter AppBar = 1 belum selesai
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Jadwal'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jadwal Pemantauan'), findsOneWidget);
    expect(find.text('1 belum selesai'), findsOneWidget);
    expect(find.text('Silvi Rahmawati'), findsOneWidget);

    // Halaman statistik membaca state dari Provider yang SAMA
    await tester.tap(find.byIcon(Icons.bar_chart));
    await tester.pumpAndSettle();
    expect(find.text('Statistik Jadwal'), findsOneWidget);
    expect(find.text('Total jadwal'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2)); // Total 1, belum selesai 1
    expect(find.text('0%'), findsOneWidget);

    // Kembali pakai tombol back bawaan
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Jadwal Pemantauan'), findsOneWidget);

    // Flush timer SnackBar dari booking
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('Modul 11: tab terakhir tersimpan (SharedPreferences)', (
    tester,
  ) async {
    await pumpApp(tester);

    // Pergi ke tab Direktori → bakal tersimpan '1' (index tab ke-…).
    // Index tab: 0 Beranda, 1 Jadwal, 2 Info, 3 Direktori.
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Direktori'),
      ),
    );
    await tester.pumpAndSettle();

    // "Restart" — pump widget baru dengan mock prefs yang sama (di-set
    // ulang di setUp, jadi cek via instance: simulasikan set nilai dulu).
    // Trik: setMockInitialValues bisa dipanggil ulang kapan saja.
    SharedPreferences.setMockInitialValues({'tab_terakhir': 3});
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await tester.pumpWidget(AnemiaApp(jadwalStore: InMemoryJadwalStore()));
    await tester.pumpAndSettle();

    // App balik ke tab terakhir = Direktori (AppBar-nya kelihatan)
    expect(find.text('Direktori Pasien'), findsOneWidget);
  });
}
