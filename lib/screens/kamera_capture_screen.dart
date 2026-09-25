import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Layar kamera live dengan panduan bingkai kuku (tengah) supaya pengguna
/// bisa menyejajarkan kuku tepat sebelum jepret — permintaan produk:
/// "ada frame kuku untuk dipasin pas mau capture".
///
/// [mode]:
///  - `kuku`   : bingkai persegi-terpilin di tengah (close-up 1 kuku,
///               kontrak model ML /predict).
///  - `tangan` : panduan tangan penuh — sistem mendeteksi kuku otomatis
///               (PCD di sidecar ML, endpoint /predict-hand).
///
/// Hasil jepret dikembalikan sebagai [File] lewat Navigator.pop; `null`
/// berarti batal. Bila kamera tidak tersedia / izin ditolak / plugin tidak
/// ada (widget test), layar jatuh ke UI fallback dengan tombol buka galeri.
class KameraCaptureScreen extends StatefulWidget {
  const KameraCaptureScreen({
    super.key,
    this.mode = 'kuku',
    this.pickGallery,
    this.initOverride,
  });

  final String mode;

  /// Buka galeri (fallback & tombol galeri di layar kamera) — injectable
  /// untuk widget test (plugin native tidak berjalan di test).
  final Future<XFile?> Function()? pickGallery;

  /// Test seam: bila diisi, inisialisasi kamera (availableCameras + Camera-
  /// Controller) DIGANTI fungsi ini. Plugin kamera tidak tersedia di widget
  /// test — override yang melempar dipakai untuk menguji UI fallback.
  final Future<void> Function()? initOverride;

  @override
  State<KameraCaptureScreen> createState() => _KameraCaptureScreenState();
}

class _KameraCaptureScreenState extends State<KameraCaptureScreen> {
  CameraController? _controller;
  List<CameraDescription>? _kameraList;
  bool _siap = false;
  bool _mengambil = false;
  String? _galat;

  String get _mode => widget.mode;

  Future<XFile?> Function() get _pickGallery =>
      widget.pickGallery ??
      () => ImagePicker().pickImage(
            source: ImageSource.gallery,
            maxWidth: 1600,
            imageQuality: 85,
          );

  @override
  void initState() {
    super.initState();
    _initKamera();
  }

  Future<void> _initKamera() async {
    final override = widget.initOverride;
    if (override != null) {
      // Jalur test: inisialisasi real tidak mungkin di widget test.
      try {
        await override();
        if (!mounted) return;
        setState(() => _siap = true);
      } catch (e) {
        if (!mounted) return;
        setState(() => _galat = e.toString());
      }
      return;
    }
    try {
      final kamera = await availableCameras();
      if (kamera.isEmpty) {
        throw StateError('Tidak ada kamera yang tersedia');
      }
      _kameraList = kamera;
      final back = kamera.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => kamera.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _controller = controller;
      await controller.initialize();
      if (!mounted) return;
      setState(() => _siap = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _galat = e.toString());
    }
  }

  Future<void> _ambilkan(XFile foto) async {
    if (!mounted) return;
    Navigator.pop(context, File(foto.path));
  }

  Future<void> _ambil() async {
    final controller = _controller;
    if (controller == null || _mengambil) return;
    setState(() => _mengambil = true);
    try {
      final foto = await controller.takePicture();
      await _ambilkan(foto);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengambil foto, coba lagi')),
      );
      setState(() => _mengambil = false);
    }
  }

  Future<void> _gantiKamera() async {
    final kamera = _kameraList;
    final controller = _controller;
    if (kamera == null || controller == null || kamera.length < 2) return;
    final idx = kamera.indexWhere(
      (c) => c.lensDirection == controller.description.lensDirection,
    );
    final next = kamera[(idx + 1) % kamera.length];
    final baru = CameraController(
      next,
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await baru.initialize();
      await controller.dispose();
      if (!mounted) return;
      setState(() => _controller = baru);
    } catch (_) {
      await baru.dispose();
    }
  }

  Future<void> _bukaGaleri() async {
    final xfile = await _pickGallery();
    if (xfile == null) return;
    await _ambilkan(xfile);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _galat != null
          ? _FallbackKamera(pesan: _galat!, bukaGaleri: _bukaGaleri)
          : !_siap
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : _bodyKamera(),
    );
  }

  Widget _bodyKamera() {
    final controller = _controller!;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Preview dengan aspek rasio kamera — overlay bingkai selalu sejajar
        // dengan gambar yang benar-benar diambil (BoxFit.cover di preview
        // tidak dipakai supaya tidak ada crop tak terduga saat capture).
        Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: CameraPreview(controller),
          ),
        ),
        // Panduan bingkai (tidak menghalangi sentuhan — IgnorePointer).
        if (_mode == 'kuku')
          const _OverlayBingkaiKuku()
        else
          const _OverlayTanganPenuh(),
        // Tombol tutup.
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton(
                tooltip: 'Tutup kamera',
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
        // Kontrol bawah.
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: _barKontrol(),
          ),
        ),
      ],
    );
  }

  Widget _barKontrol() {
    final bisaGanti =
        _kameraList != null && _kameraList!.length > 1 && !_mengambil;
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            tooltip: 'Buka galeri',
            icon: const Icon(Icons.photo_library, color: Colors.white, size: 30),
            onPressed: _mengambil ? null : _bukaGaleri,
          ),
          GestureDetector(
            onTap: _mengambil ? null : _ambil,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.white70, width: 4),
              ),
              child: _mengambil
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: Colors.black54),
                    )
                  : null,
            ),
          ),
          IconButton(
            tooltip: 'Ganti kamera',
            icon: const Icon(
              Icons.cameraswitch_outlined,
              color: Colors.white,
              size: 30,
            ),
            onPressed: bisaGanti ? _gantiKamera : null,
          ),
        ],
      ),
    );
  }
}

/// Bingkai panduan kuku (mode close-up): frame putih membulat di tengah +
/// chip instruksi + petunjuk bawah.
class _OverlayBingkaiKuku extends StatelessWidget {
  const _OverlayBingkaiKuku();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Redupkan tepi agar mata fokus ke bingkai.
          const ColoredBox(color: Colors.black26),
          Center(
            child: FractionallySizedBox(
              widthFactor: 0.56,
              heightFactor: 0.68,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(42),
                  color: Colors.white.withAlpha(12),
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
              ),
            ),
          ),
          // Instruksi atas.
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 64),
              child: _ChipPanduan(
                text: 'Posisikan kuku di dalam bingkai',
                icon: Icons.back_hand_outlined,
              ),
            ),
          ),
          // Petunjuk bawah.
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 120),
              child: const Text(
                'Jaga fokus & pencahayaan cukup',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Panduan tangan penuh (mode tangan): bingkai besar + instruksi jari ke atas.
class _OverlayTanganPenuh extends StatelessWidget {
  const _OverlayTanganPenuh();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black26),
          Center(
            child: FractionallySizedBox(
              widthFactor: 0.92,
              heightFactor: 0.9,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white70, width: 1.5),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 64),
              child: _ChipPanduan(
                text: 'Masukkan SELURUH tangan, jari menghadap ke atas',
                icon: Icons.back_hand_outlined,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip instruksi semi-transparan di atas preview kamera.
class _ChipPanduan extends StatelessWidget {
  const _ChipPanduan({required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// UI fallback saat kamera tidak bisa dibuka (izin ditolak / tidak ada
/// kamera / plugin tidak tersedia di lingkungan test).
class _FallbackKamera extends StatelessWidget {
  const _FallbackKamera({required this.pesan, required this.bukaGaleri});

  final String pesan;
  final Future<void> Function() bukaGaleri;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white70,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Kamera tidak tersedia',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Alasan: $pesan',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: bukaGaleri,
              icon: const Icon(Icons.photo_library),
              label: const Text('Buka Galeri'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Kembali',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}