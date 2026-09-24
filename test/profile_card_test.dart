import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anemia/widgets/profile_card.dart';

/// Modul 13 — tantangan no. 2 dosen: widget ProfileCard(nama, email)
/// harus menampilkan kedua data pas di layar.
void main() {
  testWidgets('ProfileCard menampilkan nama & email + inisial avatar', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfileCard(
            nama: 'Silvi Rahmawati',
            email: 'silvi@example.com',
          ),
        ),
      ),
    );

    expect(find.text('Silvi Rahmawati'), findsOneWidget);
    expect(find.text('silvi@example.com'), findsOneWidget);
    expect(find.text('S'), findsOneWidget); // inisial avatar
  });

  testWidgets('ProfileCard: subtitle opsional ditampilkan', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfileCard(
            nama: 'Budi Santoso',
            email: 'budi@example.com',
            subtitle: 'UID 2',
          ),
        ),
      ),
    );

    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('budi@example.com'), findsOneWidget);
    expect(find.text('UID 2'), findsOneWidget);
  });

  testWidgets('ProfileCard: nama kosong fallback ke "?"', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfileCard(nama: '', email: 'anon@example.com'),
        ),
      ),
    );

    expect(find.text('?'), findsOneWidget);
    expect(find.text('anon@example.com'), findsOneWidget);
  });
}
