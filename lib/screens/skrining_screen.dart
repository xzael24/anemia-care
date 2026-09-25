import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/hasil_skrining.dart';
import '../models/pasien.dart';
import '../models/rekomendasi_hasil.dart';
import '../services/rekomendasi_service.dart';
import '../services/riwayat_skrining_store.dart';
import '../services/session_store.dart';
import '../services/skrining_service.dart';
import 'akun_screen.dart';
import 'kamera_capture_screen.dart';

/// Layar skrining anemia dari foto kuku (fitur inti capstone):
/// pilih foto (kamera/galeri) → POST `/api/screening` → indikasi awal +
/// confidence + disclaimer → simpan ke riwayat lokal (sqflite) + rekomendasi
/// tindak lanjut fuzzy (PSC1). Bila pengguna sudah login akun, skrining ikut
/// tersimpan per akun di backend dan konteks profil mengisi form rekomendasi.
///
/// Mode foto: `kuku` (close-up, kamera dengan bingkai panduan kuku) atau
/// `tangan` (foto tangan penuh — sidecar ML mendeteksi kuku otomatis via PCD,
/// endpoint /predict-hand). Mode dikirim sebagai field multipart `mode`.
///
/// Semua dependensi (service, store, picker, session, kamera) bisa di-inject
/// dari test.
class SkriningPage extends StatefulWidget {
  const SkriningPage({
    super.key,
    this.service,
    this.store,
    this.pickFoto,
    this.rekomendasiService,
    this.sessionStore,
    this.openKamera,
  });

  final SkriningService? service;
  final RiwayatSkriningStore? store;
  final RekomendasiService? rekomendasiService;
  final SessionStore? sessionStore;

  /// Fungsi pemilih foto dari galeri — default [ImagePicker] (plugin native,
  /// tidak bisa dipakai di widget test).
  final Future<XFile?> Function(ImageSource source)? pickFoto;

  /// Buka layar kamera (overlay bingkai kuku) — default [KameraCaptureScreen].
  /// Dikembalikan [File] foto hasil jepret; `null` = batal.
  final Future<File?> Function(String mode)? openKamera;

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
  late final RekomendasiService _rekomendasiService =
      widget.rekomendasiService ?? RekomendasiService();
  late final SessionStore _sessionStore =
      widget.sessionStore ?? SessionPrefsStore.instance;

  XFile? _foto;
  HasilSkrining? _hasil;
  Pasien? _pasien;
  String? _error;
  bool _memuat = false;
  List<HasilSkrining> _riwayat = [];

  /// Mode foto: 'kuku' (close-up) atau 'tangan' (tangan penuh, PCD otomatis).
  String _mode = 'kuku';

  @override
  void initState() {
    super.initState();
    _muatRiwayat();
    _muatSesi();
  }

  /// Buka kamera (dengan bingkai panduan sesuai mode) — injectable untuk test.
  Future<void> _bukaKamera() async {
    final file = widget.openKamera != null
        ? await widget.openKamera!(_mode)
        : await Navigator.push<File>(
            context,
            MaterialPageRoute(
              builder: (_) => KameraCaptureScreen(mode: _mode),
            ),
          );
    if (file == null || !mounted) return;
    setState(() {
      _foto = XFile(file.path);
      _hasil = null;
      _error = null;
    });
  }

  /// Token & profil akun (opsional) — skrining & konteks rekomendasi.
  Future<void> _muatSesi() async {
    final sesi = await _sessionStore.muat();
    if (!mounted) return;
    setState(() => _pasien = sesi?.pasien);
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
      final sesi = await _sessionStore.muat();
      final hasil = await _service.skriningFoto(
        File(foto.path),
        token: sesi?.token,
        mode: _mode,
      );
      await _store.tambah(hasil);
      await _muatRiwayat();
      if (!mounted) return;
      setState(() {
        _hasil = hasil;
        _pasien = sesi?.pasien;
      });
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
      appBar: AppBar(
        title: const Text('Skrining Anemia'),
        actions: [
          // Akun pasien (Tahap 3): daftar/login → skrining & riwayat
          // tersimpan per akun; profil mengisi konteks rekomendasi fuzzy.
          IconButton(
            tooltip: 'Akun Saya',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AkunPage()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PetunjukCard(mode: _mode),
            const SizedBox(height: 12),
            // Mode foto: close-up 1 kuku vs tangan penuh (deteksi otomatis).
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'kuku',
                  label: Text('Close-up'),
                  icon: Icon(Icons.pan_tool_outlined),
                ),
                ButtonSegment<String>(
                  value: 'tangan',
                  label: Text('Tangan penuh'),
                  icon: Icon(Icons.back_hand_outlined),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() {
                _mode = s.first;
                _foto = null;
                _hasil = null;
                _error = null;
              }),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 16),
            _pratinjauFoto(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _bukaKamera,
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
            if (_hasil != null) ...[
              _HasilCard(hasil: _hasil!),
              const SizedBox(height: 12),
              _RekomendasiCard(
                hasil: _hasil!,
                service: _rekomendasiService,
                pasien: _pasien,
              ),
            ],
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
  const _PetunjukCard({required this.mode});

  final String mode;

  @override
  Widget build(BuildContext context) {
    final baris = mode == 'tangan'
        ? const <String>[
            '• Foto seluruh tangan, jari terpisah & menghadap ke atas',
            '• Pencahayaan cukup & latar bersih',
            '• Kuku terdeteksi & dianalisis otomatis (PCD)',
            '• Tanpa kutek / inai / riasan kuku',
          ]
        : const <String>[
            '• Kuku mengisi frame — ikuti bingkai panduan kamera',
            '• Pencahayaan cukup & fokus pada kuku',
            '• Foto 1 jari (biasanya telunjuk), latar netral',
            '• Tanpa kutek / inai / riasan kuku',
            '• Hindari bayangan & kilau berlebihan',
          ];
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withAlpha(90),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mode == 'tangan' ? 'Petunjuk Foto Tangan Penuh' : 'Petunjuk Foto Kuku',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            ...baris.map((t) => Text(t)),
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

/// Rekomendasi tindak lanjut (fuzzy, PSC1) — tertutup default (tombol),
/// membuka form konteks singkat → POST /api/rekomendasi → badge tingkat +
/// label + pesan + skor. Tidak menyimpan ke riwayat (menyusul saat fitur
/// akun pengguna: konteks & rekomendasi ikut tersimpan per skrining).
///
/// [pasien] opsional: profil akun → pre-fill tipe kulit & risiko (hamil,
/// riwayat anemia) sebagai konteks default.
class _RekomendasiCard extends StatefulWidget {
  const _RekomendasiCard({required this.hasil, required this.service, this.pasien});

  final HasilSkrining hasil;
  final RekomendasiService service;
  final Pasien? pasien;

  @override
  State<_RekomendasiCard> createState() => _RekomendasiCardState();
}

class _RekomendasiCardState extends State<_RekomendasiCard> {
  bool _terbuka = false;
  late final Set<String> _gejala = {};
  late final Set<String> _risiko = <String>{
    if (widget.pasien?.hamil ?? false) 'hamil',
    if (widget.pasien?.riwayatAnemia ?? false) 'riwayat_anemia',
  };
  late String? _tipeKulit = widget.pasien?.tipeKulit;
  RekomendasiHasil? _rekomendasi;
  String? _error;
  bool _memuat = false;

  Future<void> _hitung() async {
    setState(() {
      _memuat = true;
      _error = null;
    });
    try {
      final r = await widget.service.rekomendasi(
        indication: widget.hasil.indication,
        confidence: widget.hasil.confidence,
        hbEstimateGdl: widget.hasil.hbEstimateGdl,
        gejala: _gejala.toList(),
        risiko: _risiko.toList(),
        tipeKulit: _tipeKulit,
      );
      if (!mounted) return;
      setState(() => _rekomendasi = r);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Color _warnaTingkat(String tingkat) {
    switch (tingkat) {
      case 'tinggi':
        return Colors.red.shade700;
      case 'sedang':
        return Colors.amber.shade800;
      default:
        return Colors.teal.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_terbuka) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.psychology_outlined, color: Colors.indigo),
          title: const Text(
            'Rekomendasi tindak lanjut (fuzzy)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Gabung hasil visual + gejala & risiko → tindak lanjut personal (PSC1)',
            style: TextStyle(fontSize: 12),
          ),
          trailing: const Icon(Icons.expand_more),
          onTap: () => setState(() => _terbuka = true),
        ),
      );
    }

    if (_rekomendasi != null) {
      final r = _rekomendasi!;
      final warna = _warnaTingkat(r.tingkat);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(r.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: warna,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(r.pesan, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _SkorChip(label: 'Visual ${(r.skorVisual * 100).round()}%'),
                  _SkorChip(label: 'Gejala ${(r.skorGejala * 100).round()}%'),
                  _SkorChip(label: 'Risiko ${(r.skorRisiko * 100).round()}%'),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Text(
                  '⚠️ ${r.disclaimer}',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _rekomendasi = null),
                  child: const Text('Ubah jawaban'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Form konteks
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rekomendasi tindak lanjut (fuzzy)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'Jawab singkat — hasil visual ${widget.hasil.anemia ? 'mengarah anemia' : 'normal'} '
              'digabung konteks untuk menentukan tindak lanjut.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 12),
            const Text(
              'Gejala yang dirasakan',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            ...RekomendasiService.gejalaOptions.entries.map((e) {
              final kode = e.key;
              final label = e.value;
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(label, style: const TextStyle(fontSize: 13)),
                value: _gejala.contains(kode),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _gejala.add(kode);
                  } else {
                    _gejala.remove(kode);
                  }
                }),
              );
            }),
            const SizedBox(height: 8),
            const Text(
              'Faktor risiko',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            ...RekomendasiService.risikoOptions.entries.map((e) {
              final kode = e.key;
              final label = e.value;
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(label, style: const TextStyle(fontSize: 13)),
                value: _risiko.contains(kode),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _risiko.add(kode);
                  } else {
                    _risiko.remove(kode);
                  }
                }),
              );
            }),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _tipeKulit,
              decoration: const InputDecoration(
                labelText: 'Tipe kulit (opsional)',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: RekomendasiService.kulitOptions.entries
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _tipeKulit = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              _ErrorBox(pesan: _error!),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _memuat ? null : _hitung,
              icon: _memuat
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.psychology),
              label: Text(_memuat ? 'Menghitung…' : 'Hitung Rekomendasi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkorChip extends StatelessWidget {
  const _SkorChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}