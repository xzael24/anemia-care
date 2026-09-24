import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/hasil_skrining.dart';
import '../services/riwayat_skrining_store.dart';
import '../services/skrining_service.dart';

/// Layar skrining anemia dari foto kuku (fitur inti capstone):
/// pilih foto (kamera/galeri) → POST `/api/screening` → indikasi awal +
/// confidence + disclaimer → simpan ke riwayat lokal (sqflite).
///
/// Semua dependensi (service, store, picker) bisa di-inject dari test.
class SkriningPage extends StatefulWidget {
  const SkriningPage({super.key, this.service, this.store, this.pickFoto});

  final SkriningService? service;
  final RiwayatSkriningStore? store;

  /// Fungsi pemilih foto — default [ImagePicker] (plugin native, tidak bisa
  /// dipakai di widget test).
  final Future<XFile?> Function(ImageSource source)? pickFoto;

  @override
  State<SkriningPage> createState() => _SkriningPageState();
}

class _SkriningPageState extends State<SkriningPage> {
  late final SkriningService _service = widget.service ?? SkriningService();
  late final RiwayatSkriningStore _store =
      widget.store ?? RiwayatSkriningDbStore.instance;
  late final Future<XFile?> Function(ImageSource) _pickFoto =
      widget.pickFoto ??
      (source) => ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 80,
      );

  XFile? _foto;
  HasilSkrining? _hasil;
  String? _error;
  bool _memuat = false;
  List<HasilSkrining> _riwayat = [];

  @override
  void initState() {
    super.initState();
    _muatRiwayat();
  }

  Future<void> _muatRiwayat() async {
    final list = await _store.muatTerbaru();
    if (!mounted) return;
    setState(() => _riwayat = list);
  }

  Future<void> _pilihFoto(ImageSource sumber) async {
    final picked = await _pickFoto(sumber);
    if (picked == null || !mounted) return;
    setState(() {
      _foto = picked;
      _hasil = null;
      _error = null;
    });
  }

  Future<void> _analisis() async {
    final foto = _foto;
    if (foto == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pilih foto kuku dulu')));
      return;
    }

    setState(() {
      _memuat = true;
      _error = null;
    });
    try {
      final hasil = await _service.skriningFoto(File(foto.path));
      await _store.tambah(hasil);
      await _muatRiwayat();
      if (!mounted) return;
      setState(() => _hasil = hasil);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Skrining Anemia')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _PetunjukCard(),
            const SizedBox(height: 16),
            _pratinjauFoto(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pilihFoto(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Kamera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pilihFoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galeri'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _foto == null || _memuat ? null : _analisis,
              icon: _memuat
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bloodtype),
              label: Text(_memuat ? 'Menganalisis…' : 'Analisis Kuku'),
            ),
            const SizedBox(height: 20),
            if (_error != null) _ErrorBox(pesan: _error!),
            if (_hasil != null) _HasilCard(hasil: _hasil!),
            const SizedBox(height: 24),
            _judulBagian('Riwayat Terakhir (perangkat)'),
            const SizedBox(height: 8),
            if (_riwayat.isEmpty)
              const _Kosong(
                teks:
                    'Belum ada riwayat skrining di perangkat ini.\n'
                    'Hasil analisis akan tersimpan otomatis di sini.',
              )
            else
              ..._riwayat.map(
                (r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: r.anemia
                        ? Colors.red.shade100
                        : Colors.teal.shade100,
                    child: Icon(
                      r.anemia ? Icons.warning_amber : Icons.check_circle,
                      color: r.anemia ? Colors.red : Colors.teal,
                    ),
                  ),
                  title: Text(
                    r.anemia ? 'Indikasi Anemia' : 'Indikasi Normal',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${_formatWaktu(r.createdAt)} · '
                    '${(r.confidence * 100).toStringAsFixed(0)}% · '
                    '${r.source == 'ml' ? 'ML model' : 'Mock'}',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pratinjauFoto() {
    final foto = _foto;
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: foto == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.health_and_safety_outlined,
                    size: 56,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Belum ada foto',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : Image.file(
              File(foto.path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Center(
                child: Text('Gagal menampilkan foto'),
              ),
            ),
    );
  }

  Widget _judulBagian(String teks) =>
      Text(teks, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));

  /// Format ISO → '24 Sep 2026, 18.07' tanpa dependency intl.
  static String _formatWaktu(String iso) {
    final t = DateTime.tryParse(iso)?.toLocal();
    if (t == null) return iso;
    String dua(int n) => n.toString().padLeft(2, '0');
    const bulan = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${dua(t.day)} ${bulan[t.month - 1]} ${t.year}, '
        '${dua(t.hour)}:${dua(t.minute)}';
  }
}

class _PetunjukCard extends StatelessWidget {
  const _PetunjukCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withAlpha(90),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Petunjuk Foto Kuku',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text('• Pencahayaan cukup & fokus pada kuku'),
            Text('• Foto 1 jari (biasanya telunjuk), latar netral'),
            Text('• Tanpa kutek / inai / riasan kuku'),
            Text('• Hindari bayangan & kilau berlebihan'),
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pesan,
              style: TextStyle(color: Colors.red.shade800),
            ),
          ),
        ],
      ),
    );
  }
}

class _HasilCard extends StatelessWidget {
  const _HasilCard({required this.hasil});

  final HasilSkrining hasil;

  @override
  Widget build(BuildContext context) {
    final warna = hasil.anemia ? Colors.red : Colors.teal;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: warna.withAlpha(30),
                  child: Icon(
                    hasil.anemia ? Icons.warning_amber : Icons.check_circle,
                    color: warna,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasil.anemia ? 'Indikasi Anemia' : 'Indikasi Normal',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: warna,
                        ),
                      ),
                      Text(
                        'Confidence ${(hasil.confidence * 100).toStringAsFixed(0)}%'
                        ' · ${hasil.source == 'ml' ? 'ML model' : 'Mock'}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasil.hbEstimateGdl != null) ...[
              const SizedBox(height: 12),
              Text(
                'Estimasi Hb: ${hasil.hbEstimateGdl!.toStringAsFixed(1)} g/dL '
                '(pendukung, bukan pengganti lab)',
                style: const TextStyle(fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasil.disclaimer.isNotEmpty
                          ? hasil.disclaimer
                          : 'Hasil ini indikasi awal skrining non-invasif, '
                                'BUKAN diagnosis medis. Konsultasikan ke tenaga '
                                'kesehatan untuk pemeriksaan darah (Hb) resmi.',
                      style: const TextStyle(fontSize: 12),
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

class _Kosong extends StatelessWidget {
  const _Kosong({required this.teks});

  final String teks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        teks,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade600),
      ),
    );
  }
}