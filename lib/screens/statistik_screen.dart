import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/jadwal_model.dart';

/// Halaman statistik — tantangan dosen no. 3 Modul 9:
/// state diakses dari Provider yang SAMA (tidak passing constructor).
class StatistikPage extends StatelessWidget {
  const StatistikPage({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<JadwalModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Statistik Jadwal')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ringkasan jadwal pemantauan pasien',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            _baris('Total jadwal', '${m.total}'),
            const SizedBox(height: 8),
            _baris('Selesai diperiksa', '${m.jumlahSelesai}'),
            const SizedBox(height: 8),
            _baris('Belum selesai', '${m.jumlahBelumSelesai}'),
            const SizedBox(height: 24),
            const Text(
              'Persentase selesai',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: m.total == 0 ? 0 : m.jumlahSelesai / m.total,
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${m.persentaseSelesai.toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _baris(String label, String nilai) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        Text(
          nilai,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
