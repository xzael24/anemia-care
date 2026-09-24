import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/jadwal_model.dart';
import 'screens/dashboard_screen.dart';
import 'screens/direktori_screen.dart';
import 'screens/statistik_screen.dart';
import 'screens/tentang_screen.dart';
import 'services/jadwal_store.dart';

void main() => runApp(const AnemiaApp());

class AnemiaApp extends StatelessWidget {
  /// Store bisa di-inject dari test (fake in-memory) — default SQLite.
  final JadwalStore? jadwalStore;

  const AnemiaApp({super.key, this.jadwalStore});

  @override
  Widget build(BuildContext context) {
    // Modul 9 — Provider: inject state global JadwalModel ke seluruh tree.
    // Ditaruh di sini (bukan di main()) biar gampang di-test.
    return ChangeNotifierProvider(
      create: (_) => JadwalModel(store: jadwalStore ?? JadwalDbStore.instance),
      child: MaterialApp(
        title: 'Anemia App',
        theme: ThemeData(colorSchemeSeed: Colors.red, useMaterial3: true),
        initialRoute: '/',
        routes: {
          '/': (_) => const HomeShell(),
          '/tentang': (_) => const TentangPage(),
          '/statistik': (_) => const StatistikPage(),
        },
      ),
    );
  }
}

/// Kerangka dengan BottomNavigationBar (Modul 8): Beranda / Jadwal / Info.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  static const _kTabTerakhir = 'tab_terakhir';
  static const _jumlahTab = 4;

  @override
  void initState() {
    super.initState();
    _muatTabTerakhir();
  }

  /// Modul 11 — SharedPreferences (bonus dosen "login persist" diadaptasi):
  /// simpan tab terakhir dibuka, pulihkan saat app di-start ulang.
  Future<void> _muatTabTerakhir() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_kTabTerakhir);
    if (saved != null && saved >= 0 && saved < _jumlahTab && mounted) {
      setState(() => _index = saved);
    }
  }

  Future<void> _pilihTab(int i) async {
    setState(() => _index = i);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTabTerakhir, i);
  }

  @override
  Widget build(BuildContext context) {
    const halaman = [
      DashboardAnemia(),
      JadwalPage(),
      InfoPage(),
      DirektoriScreen(), // Modul 10: tab data dari API
    ];
    return Scaffold(
      body: halaman[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _pilihTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Beranda'),
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: 'Jadwal',
          ),
          NavigationDestination(icon: Icon(Icons.info_outline), label: 'Info'),
          NavigationDestination(icon: Icon(Icons.groups), label: 'Direktori'),
        ],
      ),
    );
  }
}

/// Tab Jadwal — TodoList Modul 9 versi anemia: baca state dari
/// JadwalModel via context.watch (rebuild otomatis tiap berubah).
class JadwalPage extends StatelessWidget {
  const JadwalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<JadwalModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Pemantauan'),
        actions: [
          // Tantangan dosen no. 1: counter belum selesai di AppBar
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Center(
              child: Text(
                '${model.jumlahBelumSelesai} belum selesai',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Statistik',
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.pushNamed(context, '/statistik'),
          ),
        ],
      ),
      body: !model.siap
          ? const Center(child: CircularProgressIndicator())
          : model.items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_note,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Belum ada jadwal.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Buka Beranda → pilih pasien → Catat ke Jadwal.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: model.items.length,
                    itemBuilder: (_, i) {
                      final item = model.items[i];
                      return CheckboxListTile(
                        value: item.selesai,
                        onChanged: (_) =>
                            context.read<JadwalModel>().toggle(item.id!),
                        title: Text(
                          item.namaPasien,
                          style: TextStyle(
                            decoration: item.selesai
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        secondary: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              context.read<JadwalModel>().hapus(item.id!),
                        ),
                      );
                    },
                  ),
                ),
                // Tantangan dosen no. 2 — Hapus Semua Selesai.
                // Deviasi: dosen taruh di bottom bar; kita taruh di bawah
                // daftar karena shell sudah punya tab bar (NavigationBar).
                if (model.jumlahSelesai > 0)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            context.read<JadwalModel>().hapusSemuaSelesai(),
                        icon: const Icon(Icons.delete_sweep),
                        label: const Text('Hapus Semua Selesai'),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Info Anemia')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoTile(
            Icons.bloodtype,
            'Apa itu anemia?',
            'Kondisi kadar hemoglobin (Hb) darah di bawah normal: <12 g/dL pada wanita, <13 g/dL pada pria.',
          ),
          _infoTile(
            Icons.bolt,
            'Gejala umum',
            'Mudah lelah, pucat, pusing, sesak napas saat aktivitas ringan.',
          ),
          _infoTile(
            Icons.restaurant,
            'Cegah dengan',
            'Makanan kaya zat besi (hati, daging merah, bayam) + vitamin C untuk penyerapan.',
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Tentang Aplikasi'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/tentang'),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData ikon, String judul, String isi) {
    return Card(
      child: ListTile(
        leading: Icon(ikon, color: Colors.red),
        title: Text(judul, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(isi),
      ),
    );
  }
}
