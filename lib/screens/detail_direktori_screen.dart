import 'package:flutter/material.dart';

import '../models/user_pasien.dart';
import '../services/pasien_service.dart';
import '../widgets/profile_card.dart';

/// Detail pasien dari direktori API — tantangan no. 1 Modul 10
/// (detail page, bukan dialog). Header-nya pakai ProfileCard (Modul 13).
class DetailDirektoriPage extends StatelessWidget {
  final UserPasien pasien;

  const DetailDirektoriPage({super.key, required this.pasien});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pasien (API)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            ProfileCard(
              nama: pasien.nama,
              email: pasien.email,
              subtitle: 'UID ${pasien.id}',
            ),
            const SizedBox(height: 16),
            _baris(Icons.location_city, 'Kota', pasien.kota),
            const SizedBox(height: 12),
            _baris(Icons.language, 'Website', pasien.website),
            const SizedBox(height: 24),
            Card(
              color: Colors.red.shade50,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Data demo dari JSONPlaceholder (Modul 10) — di app akhir nanti diganti API/server asli.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _baris(IconData ikon, String label, String nilai) {
    return Row(
      children: [
        Icon(ikon, color: Colors.red, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              Text(nilai, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Form tambah pasien — tantangan no. 2 & 3 Modul 10:
/// POST + SnackBar hijau (berhasil) / merah (gagal).
class TambahUserPage extends StatefulWidget {
  final PasienService service;

  const TambahUserPage({super.key, required this.service});

  @override
  State<TambahUserPage> createState() => _TambahUserPageState();
}

class _TambahUserPageState extends State<TambahUserPage> {
  final _namaCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _memuat = false;

  @override
  void dispose() {
    _namaCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final nama = _namaCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (nama.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade400,
          content: const Text('Nama & email wajib diisi'),
        ),
      );
      return;
    }

    setState(() => _memuat = true);
    try {
      final user = await widget.service.tambahUser(nama, email);
      if (!mounted) return;
      // Hijau = sukses
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade600,
          content: Text(
            '${user.nama} berhasil ditambahkan (id ${user.id} — demo API)',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _memuat = false);
      // Merah = gagal
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade400,
          content: Text('Gagal menambah pasien: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Pasien (API)')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _namaCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama',
                hintText: 'contoh: Silvi Rahmawati',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'silvi@example.com',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _memuat ? null : _simpan,
              icon: _memuat
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_memuat ? 'Mengirim...' : 'Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
