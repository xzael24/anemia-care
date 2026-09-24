import 'package:flutter/material.dart';

/// Halaman detail pasien — tantangan Modul 8 versi anemia:
/// terima data dari halaman sebelumnya (passing data via constructor),
/// lalu kembalikan data lewat Navigator.pop (return data).
class DetailPasienPage extends StatelessWidget {
  final String nama;
  final int umur;
  final double hb;

  const DetailPasienPage({
    super.key,
    required this.nama,
    required this.umur,
    required this.hb,
  });

  @override
  Widget build(BuildContext context) {
    final anemia = hb < 12.0;
    final warna = anemia ? Colors.red : Colors.teal;

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pasien')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: warna.withAlpha(25),
                child: Icon(Icons.person, size: 40, color: warna),
              ),
              const SizedBox(height: 12),
              Text(
                nama,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                anemia ? 'Status: ANEMIA' : 'Status: Normal',
                style: TextStyle(color: warna, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              _infoKotak('Umur', '$umur tahun'),
              const SizedBox(height: 12),
              _infoKotak('Hemoglobin', '${hb.toStringAsFixed(1)} g/dL'),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                // Kembalikan nama pasien ke halaman sebelumnya
                onPressed: () => Navigator.pop(context, nama),
                icon: const Icon(Icons.event_available),
                label: const Text('Catat ke Jadwal'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoKotak(String label, String nilai) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text(
            nilai,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
