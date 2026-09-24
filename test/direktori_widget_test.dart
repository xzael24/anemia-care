import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:anemia/screens/direktori_screen.dart';
import 'package:anemia/services/pasien_service.dart';

void main() {
  final mockService = PasienService(
    client: MockClient((request) async {
      if (request.method == 'POST') {
        return http.Response(
          jsonEncode({
            'id': 11,
            'name': 'Andi Pratama',
            'email': 'andi@example.com',
            'address': {'city': 'Surabaya'},
            'website': 'andi.dev',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode([
          {
            'id': 1,
            'name': 'Silvi Rahmawati',
            'email': 'silvi@example.com',
            'address': {'city': 'Bandung'},
            'website': 'silvi.dev',
          },
          {
            'id': 2,
            'name': 'Budi Santoso',
            'email': 'budi@example.com',
            'address': {'city': 'Jakarta'},
            'website': '',
          },
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );

  Future<void> pumpDirektori(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: DirektoriScreen(service: mockService)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Direktori: list API → detail → tambah (POST + SnackBar hijau)', (
    tester,
  ) async {
    await pumpDirektori(tester);

    // List dari API
    expect(find.text('Silvi Rahmawati'), findsOneWidget);
    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('silvi@example.com'), findsOneWidget);

    // Detail (tantangan no. 1)
    await tester.tap(find.text('Silvi Rahmawati'));
    await tester.pumpAndSettle();
    expect(find.text('Detail Pasien (API)'), findsOneWidget);
    expect(find.text('Bandung'), findsWidgets);
    expect(find.text('silvi.dev'), findsOneWidget);

    // Kembali → form tambah (tantangan no. 2)
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.person_add));
    await tester.pumpAndSettle();
    expect(find.text('Tambah Pasien (API)'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Andi Pratama');
    await tester.enterText(find.byType(TextField).last, 'andi@example.com');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    // POST sukses → SnackBar hijau + kembali ke list
    expect(find.textContaining('berhasil ditambahkan'), findsOneWidget);
    expect(find.text('Direktori Pasien'), findsOneWidget);

    // Flush timer SnackBar
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('Direktori: error state menampilkan tombol Coba lagi', (
    tester,
  ) async {
    final gagal = PasienService(
      client: MockClient((request) async => http.Response('down', 500)),
    );
    await tester.pumpWidget(MaterialApp(home: DirektoriScreen(service: gagal)));
    await tester.pumpAndSettle();

    expect(find.text('Gagal memuat data dari server'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
  });

  testWidgets('Tambah pasien: form kosong → SnackBar merah validasi', (
    tester,
  ) async {
    // Mirip materi dosen "Login menolak email kosong": submit tanpa isi.
    await pumpDirektori(tester);
    await tester.tap(find.byIcon(Icons.person_add));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simpan'));
    await tester.pump();

    expect(find.text('Nama & email wajib diisi'), findsOneWidget);

    // Flush timer SnackBar
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
