/// Hasil rekomendasi fuzzy (PSC1) dari `POST /api/rekomendasi`.
class RekomendasiHasil {
  const RekomendasiHasil({
    required this.rekomendasi,
    required this.tingkat,
    required this.emoji,
    required this.label,
    required this.pesan,
    required this.skorVisual,
    required this.skorGejala,
    required this.skorRisiko,
    required this.disclaimer,
  });

  final double rekomendasi;
  final String tingkat; // 'rendah' | 'sedang' | 'tinggi'
  final String emoji;
  final String label;
  final String pesan;
  final double skorVisual;
  final double skorGejala;
  final double skorRisiko;
  final String disclaimer;

  factory RekomendasiHasil.fromJson(Map<String, dynamic> json) {
    final skor = json['skor'] as Map<String, dynamic>? ?? const {};
    return RekomendasiHasil(
      rekomendasi: (json['rekomendasi'] as num?)?.toDouble() ?? 0,
      tingkat: json['tingkat'] as String? ?? 'rendah',
      emoji: json['emoji'] as String? ?? '🟢',
      label: json['label'] as String? ?? '',
      pesan: json['pesan'] as String? ?? '',
      skorVisual: (skor['visual'] as num?)?.toDouble() ?? 0,
      skorGejala: (skor['gejala'] as num?)?.toDouble() ?? 0,
      skorRisiko: (skor['risiko'] as num?)?.toDouble() ?? 0,
      disclaimer: json['disclaimer'] as String? ?? '',
    );
  }

  bool get adalahTinggi => tingkat == 'tinggi';
  bool get adalahSedang => tingkat == 'sedang';
}