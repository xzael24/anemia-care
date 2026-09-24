import 'package:flutter/material.dart';

/// Modul 13 — ProfileCard: avatar inisial + nama + email (+ subtitle opsional).
///
/// Adaptasi tantangan dosen: "widget ProfileCard yang menerima `nama` dan
/// `email`". Dipakai di header detail Direktori (data pasien dari API M10).
class ProfileCard extends StatelessWidget {
  final String nama;
  final String email;
  final String? subtitle;
  final MaterialColor warna;

  const ProfileCard({
    super.key,
    required this.nama,
    required this.email,
    this.subtitle,
    this.warna = Colors.red,
  });

  @override
  Widget build(BuildContext context) {
    final inisial = nama.isNotEmpty ? nama[0].toUpperCase() : '?';
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: warna.shade100,
              child: Text(
                inisial,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: warna.shade700,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nama,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
