import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/anemia_logic.dart';
import '../models/jadwal_model.dart';
import 'detail_pasien_screen.dart';
import 'galeri_screen.dart';
import 'skrining_screen.dart';

/// Dashboard anemia (tab Beranda) — layout responsif dari Modul 7
/// + navigasi antar halaman dari Modul 8.
class DashboardAnemia extends StatelessWidget {
  const DashboardAnemia({super.key});

  // Modul 13: ambang normal dipindah ke AnemiaLogic (class yang di-unit-test),
  // supaya dashboard & test pakai satu sumber kebenaran yang sama.
  static const double _batasHbNormal = AnemiaLogic.batasHbNormal;

  // Data sementara (nanti dari API/database di Modul 10-11)
  final List<Map<String, dynamic>> _pasien = const [
    {'nama': 'Silvi Rahmawati', 'hb': 10.2, 'umur': 22},
    {'nama': 'Budi Santoso', 'hb': 13.5, 'umur': 25},
    {'nama': 'Dono Wibowo', 'hb': 11.0, 'umur': 30},
    {'nama': 'Rina Marlina', 'hb': 9.8, 'umur': 27},
    {'nama': 'Eka Prasetya', 'hb': 14.2, 'umur': 19},
    {'nama': 'Fajar Nugroho', 'hb': 12.6, 'umur': 23},
  ];

  // Menu cepat — record (Dart 3) + collection for (Modul 5).
// Empat tile (2 baris di layar sempit) — jangan tambah jumlahnya supaya
// layout "Daftar Pasien" di bawah tidak terdorong keluar layar di test.
  static const List<({IconData icon, String label})> _menu = [
    (icon: Icons.health_and_safety, label: 'Skrining'),
    (icon: Icons.vaccines, label: 'Input Lab'),
    (icon: Icons.calendar_month, label: 'Jadwal'),
    (icon: Icons.help, label: 'Info Anemia'),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final jumlahAnemia = _pasien
        .where((p) => (p['hb'] as num) < _batasHbNormal)
        .length;
    final jumlahAman = _pasien.length - jumlahAnemia;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Anemia'),
        actions: [
          IconButton(
            tooltip: 'Ukuran layar',
            icon: const Icon(Icons.aspect_ratio),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Layar: ${size.width.toInt()} × ${size.height.toInt()} px',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      drawer: _bikinDrawer(context),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Responsif: menu 2 kolom di layar sempit, 4 kolom di layar lebar
            final kolomMenu = constraints.maxWidth >= 600 ? 4 : 2;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _judulBagian('Ringkasan Pasien'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          'Total',
                          _pasien.length,
                          Icons.people,
                          Colors.indigo,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                          'Anemia',
                          jumlahAnemia,
                          Icons.warning_amber,
                          Colors.red,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                          'Normal',
                          jumlahAman,
                          Icons.verified_user,
                          Colors.teal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _judulBagian('Menu Cepat'),
                  const SizedBox(height: 8),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: kolomMenu,
                    mainAxisExtent: 96,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      for (final m in _menu)
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            // Fitur inti capstone: skrining foto kuku →
                            // backend NestJS (foto → indikasi awal + disclaimer).
                            if (m.label == 'Skrining') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SkriningPage(),
                                ),
                              );
                              return;
                            }
                            // Modul 12: tile "Input Lab" sekarang beneran —
                            // buka Galeri Hasil Lab (kamera/galeri + simpan permanen).
                            if (m.label == 'Input Lab') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const GaleriLabPage(),
                                ),
                              );
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${m.label} — menyusul di modul berikutnya',
                                ),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(m.icon, size: 28),
                                const SizedBox(height: 6),
                                Text(
                                  m.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _judulBagian('Daftar Pasien'),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _pasien.length,
                    itemBuilder: (context, index) {
                      final p = _pasien[index];
                      final anemia = (p['hb'] as num) < _batasHbNormal;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              backgroundColor: anemia
                                  ? Colors.red.shade100
                                  : Colors.teal.shade100,
                              child: Icon(
                                Icons.person,
                                color: anemia ? Colors.red : Colors.teal,
                              ),
                            ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: anemia ? Colors.red : Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        title: Text(p['nama'] as String),
                        subtitle: Text(
                          'Umur ${p['umur']} · Hb ${p['hb']} g/dL',
                        ),
                        trailing: Text(
                          anemia ? 'ANEMIA' : 'normal',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: anemia ? Colors.red : Colors.teal,
                          ),
                        ),
                        // Modul 8: push + passing data, lalu await hasil pop
                        onTap: () async {
                          final hasil = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetailPasienPage(
                                nama: p['nama'] as String,
                                umur: p['umur'] as int,
                                hb: (p['hb'] as num).toDouble(),
                              ),
                            ),
                          );
                          if (hasil != null && context.mounted) {
                            // Modul 9: simpan ke state global, bukan cuma snackbar
                            context.read<JadwalModel>().tambah(hasil);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '$hasil ditambahkan ke jadwal pemantauan',
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Drawer (Modul 8) — menu samping: tentang, pengaturan, keluar.
  Widget _bikinDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.red),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Halo, Silvi! 👋',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Pasien anemia — pemantauan Hb',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Tentang Aplikasi'),
            onTap: () {
              Navigator.pop(context); // tutup drawer dulu
              Navigator.pushNamed(context, '/tentang'); // named route
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Pengaturan'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pengaturan menyusul (Modul 9+)')),
              );
            },
          ),
          const ListTile(
            leading: Icon(Icons.logout),
            title: Text('Keluar'),
            onTap: null, // nanti: login & autentikasi
          ),
        ],
      ),
    );
  }

  Widget _judulBagian(String teks) => Text(
    teks,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  );

  Widget _statCard(String judul, int nilai, IconData ikon, Color warna) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warna.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(ikon, color: warna),
          const SizedBox(height: 6),
          Text(
            '$nilai',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: warna,
            ),
          ),
          Text(judul, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
