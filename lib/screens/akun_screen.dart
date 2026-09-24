import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/hasil_skrining.dart';
import '../models/pasien.dart';
import '../services/akun_service.dart';
import '../services/session_store.dart';

/// Akun pengguna mobile (Tahap 3): daftar/login → skrining otomatis
/// tersimpan per akun (cloud), plus riwayat akun + konteks fuzzy dari profil.
///
/// Dependensi (service & session) bisa di-inject dari test.
class AkunPage extends StatefulWidget {
  const AkunPage({super.key, this.service, this.session});

  final AkunService? service;
  final SessionStore? session;

  @override
  State<AkunPage> createState() => _AkunPageState();
}

class _AkunPageState extends State<AkunPage> {
  late final AkunService _service = widget.service ?? AkunService();
  late final SessionStore _session =
      widget.session ?? SessionPrefsStore.instance;

  ({String token, Pasien pasien})? _sesi;
  bool _siap = false;

  // Form masuk / daftar
  String _mode = 'masuk'; // 'masuk' | 'daftar'
  final _userMasuk = TextEditingController();
  final _passMasuk = TextEditingController();
  final _userDaftar = TextEditingController();
  final _passDaftar = TextEditingController();
  final _namaDaftar = TextEditingController();
  final _usiaDaftar = TextEditingController();
  String _gender = 'perempuan';
  String? _tipeKulit;
  bool _hamil = false;
  bool _riwayatAnemia = false;

  bool _memuat = false;
  String? _error;

  List<HasilSkrining> _riwayat = [];
  bool _riwayatDimuat = false;

  @override
  void initState() {
    super.initState();
    _muatSesi();
  }

  @override
  void dispose() {
    _userMasuk.dispose();
    _passMasuk.dispose();
    _userDaftar.dispose();
    _passDaftar.dispose();
    _namaDaftar.dispose();
    _usiaDaftar.dispose();
    super.dispose();
  }

  Future<void> _muatSesi() async {
    final s = await _session.muat();
    if (!mounted) return;
    setState(() {
      _sesi = s;
      _siap = true;
    });
  }

  Future<void> _masuk() async {
    setState(() {
      _memuat = true;
      _error = null;
    });
    try {
      final auth = await _service.login(
        username: _userMasuk.text.trim(),
        password: _passMasuk.text,
      );
      await _session.simpan(auth.accessToken, auth.pasien);
      if (!mounted) return;
      setState(() => _sesi = (token: auth.accessToken, pasien: auth.pasien));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _pesanRamah(e));
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Future<void> _daftar() async {
    setState(() {
      _memuat = true;
      _error = null;
    });
    try {
      final usia = int.tryParse(_usiaDaftar.text.trim());
      if (usia == null || usia < 1 || usia > 120) {
        throw Exception('Usia harus angka 1–120');
      }
      final auth = await _service.daftar(
        username: _userDaftar.text.trim(),
        password: _passDaftar.text,
        nama: _namaDaftar.text.trim(),
        usia: usia,
        gender: _gender,
        tipeKulit: _tipeKulit,
        hamil: _hamil,
        riwayatAnemia: _riwayatAnemia,
      );
      await _session.simpan(auth.accessToken, auth.pasien);
      if (!mounted) return;
      setState(() => _sesi = (token: auth.accessToken, pasien: auth.pasien));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _pesanRamah(e));
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Future<void> _muatRiwayat() async {
    final s = _sesi;
    if (s == null) return;
    setState(() {
      _memuat = true;
      _error = null;
    });
    try {
      final list = await _service.riwayat(s.token);
      if (!mounted) return;
      setState(() {
        _riwayat = list;
        _riwayatDimuat = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _pesanRamah(e));
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Future<void> _keluar() async {
    await _session.hapus();
    if (!mounted) return;
    setState(() {
      _sesi = null;
      _riwayat = [];
      _riwayatDimuat = false;
      _error = null;
    });
  }

  String _pesanRamah(Object e) =>
      e.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Akun Saya')),
      body: !_siap
          ? const Center(child: CircularProgressIndicator())
          : _sesi == null
          ? _formMasukDaftar(context)
          : _bodyProfil(_sesi!),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _formMasukDaftar(BuildContext context) {
    final masuk = _mode == 'masuk';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'masuk', label: Text('Masuk')),
            ButtonSegment(value: 'daftar', label: Text('Daftar')),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() {
            _mode = s.first;
            _error = null;
          }),
        ),
        const SizedBox(height: 20),
        if (masuk) ...[
          TextField(
            controller: _userMasuk,
            decoration: const InputDecoration(
              labelText: 'Username',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passMasuk,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _memuat ? null : _masuk,
            child: Text(_memuat ? 'Memproses…' : 'Masuk Akun'),
          ),
        ] else ...[
          TextField(
            controller: _userDaftar,
            decoration: const InputDecoration(
              labelText: 'Username (min. 3 karakter)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passDaftar,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password (min. 6 karakter)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _namaDaftar,
            decoration: const InputDecoration(
              labelText: 'Nama lengkap',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usiaDaftar,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Usia (tahun)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _gender,
            decoration: const InputDecoration(
              labelText: 'Jenis kelamin',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'perempuan', child: Text('Perempuan')),
              DropdownMenuItem(value: 'laki', child: Text('Laki-laki')),
            ],
            onChanged: (v) => setState(() => _gender = v ?? 'perempuan'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _tipeKulit,
            decoration: const InputDecoration(
              labelText: 'Tipe kulit (opsional)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: PasienServiceTipeKulit.items,
            onChanged: (v) => setState(() => _tipeKulit = v),
          ),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Sedang hamil', style: TextStyle(fontSize: 13)),
            value: _hamil,
            onChanged: (v) => setState(() => _hamil = v ?? false),
          ),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Riwayat anemia', style: TextStyle(fontSize: 13)),
            value: _riwayatAnemia,
            onChanged: (v) => setState(() => _riwayatAnemia = v ?? false),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _memuat ? null : _daftar,
            child: Text(_memuat ? 'Memproses…' : 'Daftar Akun'),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          _KotakError(pesan: _error!),
        ],
        const SizedBox(height: 12),
        Text(
          'Setelah masuk, hasil skrining otomatis tersimpan ke akun ini '
          '(terlihat petugas di web) dan konteks profil dipakai untuk '
          'rekomendasi fuzzy.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }

  Widget _bodyProfil(({String token, Pasien pasien}) sesi) {
    final p = sesi.pasien;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  child: Text(
                    p.nama.isEmpty ? '?' : p.nama[0].toUpperCase(),
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.nama,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      Text('@${p.username}'),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _Tag('${p.usia} th · ${p.labelGender}'),
                          if (p.tipeKulit != null)
                            _Tag('Kulit ${_labelKulit(p.tipeKulit!)}'),
                          if (p.hamil) _Tag('Hamil'),
                          if (p.riwayatAnemia) _Tag('Riwayat anemia'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Riwayat skrining (cloud)',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _memuat ? null : _muatRiwayat,
          icon: const Icon(Icons.cloud_download_outlined),
          label: Text(_riwayatDimuat ? 'Muat ulang riwayat' : 'Muat riwayat saya'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          _KotakError(pesan: _error!),
        ],
        if (_riwayatDimuat) ...[
          const SizedBox(height: 8),
          if (_riwayat.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Belum ada riwayat skrining untuk akun ini.'),
            )
          else
            for (final h in _riwayat)
              Card(
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    h.anemia ? Icons.warning_amber : Icons.check_circle_outline,
                    color: h.anemia ? Colors.red.shade700 : Colors.teal.shade700,
                  ),
                  title: Text(h.imageName),
                  subtitle: Text(
                    '${h.anemia ? 'Indikasi anemia' : 'Normal'} · '
                    'conf ${(h.confidence * 100).round()}% · ${h.createdAt}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
        ],
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _memuat ? null : _keluar,
          icon: const Icon(Icons.logout),
          label: const Text('Keluar akun'),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
        ),
      ],
    );
  }

  static String _labelKulit(String k) => switch (k) {
    'terang' => 'terang',
    'gelap' => 'gelap',
    _ => 'sedang',
  };
}

/// Opsi tipe kulit untuk DropdownButtonFormField (sama dgn RekomendasiService).
class PasienServiceTipeKulit {
  static const items = [
    DropdownMenuItem(value: 'terang', child: Text('Terang')),
    DropdownMenuItem(value: 'sedang', child: Text('Sedang')),
    DropdownMenuItem(value: 'gelap', child: Text('Gelap')),
  ];
}

class _Tag extends StatelessWidget {
  const _Tag(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(teks, style: const TextStyle(fontSize: 11)),
    );
  }
}

class _KotakError extends StatelessWidget {
  const _KotakError({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Text(pesan, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
    );
  }
}