/// Modul 13 — logika anemia MURNI (tanpa Flutter), biar gampang di-unit-test.
/// Ini adaptasi "class Kalkulator" dari materi dosen: class yang diuji bukan
/// kelas matematika abstrak, tapi logika yang beneran dipakai app (dari M5/M7).
enum TingkatAnemia { normal, ringan, sedang, berat }

class AnemiaLogic {
  /// Ambang normal Hb (g/dL) — konsisten sama dashboard (M7): 12.0.
  /// (Standar WHO dewasa: normal >= 12 g/dL.)
  static const double batasHbNormal = 12.0;

  /// Hb < 12.0 → anemia. Edge case penting: tepat 12.0 = NORMAL.
  static bool statusAnemia(double hb) => hb < batasHbNormal;

  /// Klasifikasi keparahan (band WHO dewasa, disesuaikan app):
  /// normal >= 12 · ringan 11–11.9 · sedang 8–10.9 · berat < 8
  static TingkatAnemia tingkatKeparahan(double hb) {
    if (hb < 8) return TingkatAnemia.berat;
    if (hb < 11) return TingkatAnemia.sedang;
    if (hb < batasHbNormal) return TingkatAnemia.ringan;
    return TingkatAnemia.normal;
  }

  /// Persentase pasien anemia dari daftar nilai Hb (0–100).
  /// List kosong → 0 (jangan bagi nol).
  static double persentaseAnemia(List<double> hbs) {
    if (hbs.isEmpty) return 0;
    final jumlahAnemia = hbs.where(statusAnemia).length;
    return (jumlahAnemia / hbs.length) * 100;
  }

  /// Selisih Hb terhadap batas normal (±). Negatif = di bawah normal.
  static double deltaHb(double hb) => hb - batasHbNormal;
}
