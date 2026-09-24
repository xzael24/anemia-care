/// Hasil skrining foto kuku dari backend NestJS (`POST /api/screening`).
///
/// Dibaca dari respons API (camelCase) dan disimpan ke sqflite (snake_case)
/// lewat [RiwayatSkriningStore].
class HasilSkrining {
  const HasilSkrining({
    required this.id,
    required this.indication,
    required this.confidence,
    required this.source,
    required this.imageName,
    required this.createdAt,
    required this.disclaimer,
    this.hbEstimateGdl,
  });

  final String id;

  /// 'anemia' | 'normal' — indikasi awal dari model ML.
  final String indication;
  final double confidence;

  /// Estimasi hemoglobin (g/dL) — pendukung skrining, bukan pengganti lab.
  final double? hbEstimateGdl;

  /// 'ml' = model RandomForest sidecar; 'mock' = fallback (backend tanpa ML).
  final String source;
  final String imageName;
  final String createdAt;
  final String disclaimer;

  bool get anemia => indication == 'anemia';

  /// Parse respons `POST /api/screening` (backend selalu sertakan disclaimer).
  factory HasilSkrining.fromJson(Map<String, dynamic> j) {
    return HasilSkrining(
      id: j['id'] as String? ?? '',
      indication: j['indication'] as String? ?? 'normal',
      confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
      hbEstimateGdl: (j['hbEstimateGdl'] as num?)?.toDouble(),
      source: j['source'] as String? ?? 'mock',
      imageName: j['imageName'] as String? ?? 'foto.jpg',
      createdAt: j['createdAt'] as String? ?? '',
      disclaimer: j['disclaimer'] as String? ?? '',
    );
  }

  /// Bentuk untuk tabel sqflite `riwayat_skrining`.
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'indication': indication,
      'confidence': confidence,
      'hb_estimate': hbEstimateGdl,
      'source': source,
      'image_name': imageName,
      'created_at': createdAt,
    };
  }

  factory HasilSkrining.fromMap(Map<String, Object?> m) {
    return HasilSkrining(
      id: m['id'] as String? ?? '',
      indication: m['indication'] as String? ?? 'normal',
      confidence: (m['confidence'] as num?)?.toDouble() ?? 0,
      hbEstimateGdl: (m['hb_estimate'] as num?)?.toDouble(),
      source: m['source'] as String? ?? 'mock',
      imageName: m['image_name'] as String? ?? '',
      createdAt: m['created_at'] as String? ?? '',
      disclaimer: '',
    );
  }
}