import 'package:flutter/material.dart';

import '../models/user_pasien.dart';
import '../services/pasien_service.dart';
import 'detail_direktori_screen.dart';

/// Direktori Pasien (API) — praktik utama Modul 10.
/// Bonus dosen (/users) kita angkat jadi tantangan utama misi.
/// FutureBuilder handle 3 keadaan: loading / error / sukses.
class DirektoriScreen extends StatefulWidget {
  final PasienService? service;

  const DirektoriScreen({super.key, this.service});

  @override
  State<DirektoriScreen> createState() => _DirektoriScreenState();
}

class _DirektoriScreenState extends State<DirektoriScreen> {
  late final PasienService _service;
  // JANGAN panggil API di build() — simpan Future di state (Modul 10)
  late Future<List<UserPasien>> _future;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? PasienService();
    _future = _service.getUsers();
  }

  Future<void> _refresh() async {
    // Pake block body — arrow `() => _future = ...` bakal nge-return Future
    // dan setState nge-assert itu (dilarang async di dalam setState).
    setState(() {
      _future = _service.getUsers();
    });
  }

  Future<void> _bukaTambah() async {
    final ditambah = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TambahUserPage(service: _service)),
    );
    if (ditambah == true && mounted) {
      _refresh(); // data baru → muat ulang list
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Direktori Pasien'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
          IconButton(
            tooltip: 'Tambah pasien',
            icon: const Icon(Icons.person_add),
            onPressed: _bukaTambah,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<UserPasien>>(
          future: _future,
          builder: (context, snap) {
            // 1. Loading
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            // 2. Error
            if (snap.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 100),
                  Icon(Icons.cloud_off, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'Gagal memuat data dari server',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        '${snap.error}',
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba lagi'),
                    ),
                  ),
                ],
              );
            }
            // 3. Sukses
            final users = snap.data!;
            if (users.isEmpty) {
              return const Center(child: Text('Belum ada data pasien.'));
            }
            return ListView.separated(
              itemCount: users.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final u = users[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.shade100,
                    child: Text(
                      u.nama.isNotEmpty ? u.nama[0] : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(u.nama),
                  subtitle: Text(u.email),
                  trailing: Text(
                    u.kota,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  // Modul 8 + 10: passing data ke halaman detail
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailDirektoriPage(pasien: u),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
