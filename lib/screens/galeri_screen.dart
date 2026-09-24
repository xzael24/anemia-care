import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/galeri_service.dart';

/// Galeri Hasil Lab — praktik utama Modul 12.
/// Mini-project dosen ("Galeri Foto Pribadi") diadaptasi ke misi:
/// simpan foto hasil cek lab / bukti periksa, persisten di direktori
/// dokumen (nggak ilang setelah restart — bedanya dari M11 SQLite,
/// ini file beneran).
class GaleriLabPage extends StatefulWidget {
  final GaleriLabService? service;

  const GaleriLabPage({super.key, this.service});

  @override
  State<GaleriLabPage> createState() => _GaleriLabPageState();
}

class _GaleriLabPageState extends State<GaleriLabPage> {
  static const _bulan = [
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

  late final GaleriLabService _service;
  final _picker = ImagePicker();
  List<File> _fotos = [];
  bool _siap = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? GaleriLabService();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final fotos = await _service.muatSemua();
      if (!mounted) return;
      setState(() {
        _fotos = fotos;
        _siap = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _siap = true);
      _snack('Gagal memuat galeri: $e', merah: true);
    }
  }

  Future<void> _tambahFoto(ImageSource sumber) async {
    try {
      final picked = await _picker.pickImage(
        source: sumber,
        imageQuality: 80, // kompres 80% — hemat storage (dosen)
        maxWidth: 1280,
      );
      if (picked == null) return; // user batal
      await _service.simpanDari(picked.path);
      await _muat();
    } catch (e) {
      _snack('Gagal ambil foto: $e', merah: true);
    }
  }

  /// Tantangan dosen no. 1 — long-press → konfirmasi → hapus
  Future<void> _konfirmasiHapus(File foto) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus foto ini?'),
        content: const Text('Tindakan ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yakin != true || !mounted) return;
    try {
      await foto.delete();
      await _muat();
      _snack('Foto dihapus');
    } catch (e) {
      _snack('Gagal hapus foto: $e', merah: true);
    }
  }

  /// Tantangan dosen no. 2 — overlay tanggal dari nama file timestamp
  String _formatTanggal(DateTime d) {
    String dua(int n) => n.toString().padLeft(2, '0');
    return '${d.day} ${_bulan[d.month - 1]} ${d.year}, ${dua(d.hour)}:${dua(d.minute)}';
  }

  void _snack(String pesan, {bool merah = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: merah ? Colors.red.shade400 : Colors.green.shade600,
        content: Text(pesan),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _siap ? 'Galeri Hasil Lab (${_fotos.length})' : 'Galeri Hasil Lab',
        ),
      ),
      body: !_siap
          ? const Center(child: CircularProgressIndicator())
          : _fotos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Belum ada foto hasil lab.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tekan ikon kamera/galeri untuk menambah.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _fotos.length,
              itemBuilder: (_, i) {
                final foto = _fotos[i];
                final tanggal = tanggalDariNamaFile(foto.path);
                return GestureDetector(
                  key: ValueKey(foto.path),
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      child: Image.file(
                        foto,
                        errorBuilder: (_, _, _) => Container(
                          height: 200,
                          color: Colors.grey.shade300,
                          child: const Center(
                            child: Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ),
                  onLongPress: () => _konfirmasiHapus(foto),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          foto,
                          fit: BoxFit.cover,
                          // Foto korup/error decode → placeholder (biar
                          // nggak nyembur exception ke console).
                          errorBuilder: (_, _, _) => Container(
                            color: Colors.grey.shade300,
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        if (tanggal != null)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 3,
                                horizontal: 6,
                              ),
                              color: Colors.black.withValues(alpha: 0.55),
                              child: Text(
                                _formatTanggal(tanggal),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'kamera',
            tooltip: 'Ambil dari kamera',
            onPressed: () => _tambahFoto(ImageSource.camera),
            child: const Icon(Icons.camera_alt),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            heroTag: 'galeri',
            tooltip: 'Pilih dari galeri',
            onPressed: () => _tambahFoto(ImageSource.gallery),
            child: const Icon(Icons.photo_library),
          ),
        ],
      ),
    );
  }
}
