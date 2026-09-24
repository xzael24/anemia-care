// Modul 14 — generator ikon & logo splash (tanpa designer & tanpa dependency).
//
// Bikin PNG secara programmatic: droplet merah (darah/anemia) di background
// gradient pink muda → icon launcher 1024x1024, dan versi transparan 512x512
// buat splash screen. PNG di-encode manual (zlib dari dart:io + CRC32),
// dengan supersampling 2x2 buat anti-aliasing tepi.
//
// Jalan: dart run tool/gen_icon.dart
import 'dart:io';
import 'dart:typed_data';

void main() {
  _generateIcon(1024, 'assets/icon/icon.png', transparentBg: false);
  _generateIcon(512, 'assets/icon/splash_logo.png', transparentBg: true);
  stdout.writeln(
    'ikon digenerate: assets/icon/icon.png (1024) & assets/icon/splash_logo.png (512)',
  );
}

void _generateIcon(int s, String path, {required bool transparentBg}) {
  final rgba = Uint8List(s * s * 4);
  const ss = 2; // supersample 2x2 → AA halus di tepi droplet

  for (var y = 0; y < s; y++) {
    for (var x = 0; x < s; x++) {
      var r = 0, g = 0, b = 0, a = 0;
      for (var sy = 0; sy < ss; sy++) {
        for (var sx = 0; sx < ss; sx++) {
          final c = _pixelColor(x + (sx + 0.5) / ss, y + (sy + 0.5) / ss, s.toDouble(), transparentBg);
          r += c[0];
          g += c[1];
          b += c[2];
          a += c[3];
        }
      }
      final n = ss * ss;
      final i = (y * s + x) * 4;
      rgba[i] = (r / n).round();
      rgba[i + 1] = (g / n).round();
      rgba[i + 2] = (b / n).round();
      rgba[i + 3] = (a / n).round();
    }
  }

  File(path)..createSync(recursive: true)..writeAsBytesSync(_encodePng(s, s, rgba));
}

List<int> _pixelColor(double x, double y, double s, bool transparentBg) {
  // Geometri droplet (proporsional ke ukuran canvas):
  // - lingkaran bawah: pusat (0.5, 0.62), radius 0.28
  // - segitiga leher: apeks (0.5, 0.18) → titik singgung lingkaran
  final cx = 0.5 * s, cy = 0.62 * s, r = 0.28 * s;
  final ax = 0.5 * s, ay = 0.18 * s;

  final dx = x - cx, dy = y - cy;
  final inCircle = dx * dx + dy * dy <= r * r;

  final cosPhi = r / (cy - ay); // 0.28 / 0.44
  final sinPhi = (1 - cosPhi * cosPhi).clamp(0.0, 1.0);
  final sin = _sqrtApprox(sinPhi);
  final t1x = cx + r * sin, t1y = cy - r * cosPhi;
  final t2x = cx - r * sin, t2y = t1y;

  final pAx = x - ax, pAy = y - ay;
  final e1x = t1x - ax, e1y = t1y - ay;
  final e2x = t2x - ax, e2y = t2y - ay;
  final inTri = (e1x * pAy - e1y * pAx) >= 0 && (e2x * pAy - e2y * pAx) <= 0 && y <= t1y;

  final inDrop = inCircle || inTri;
  if (inDrop) {
    // Highlight putih kecil (gloss) di kanan-atas droplet
    final hdx = x - 0.58 * s, hdy = y - 0.52 * s;
    if (hdx * hdx + hdy * hdy <= (0.085 * s) * (0.085 * s)) {
      return [255, 255, 255, 230];
    }
    return [211, 47, 47, 255]; // merah droplet (#D32F2F)
  }

  if (transparentBg) return [0, 0, 0, 0];
  // Gradient pink muda (#FCE4EC) → putih
  final t = y / s;
  return [
    (252 + (255 - 252) * t).round(),
    (228 + (255 - 228) * t).round(),
    (236 + (255 - 236) * t).round(),
    255,
  ];
}

double _sqrtApprox(num v) {
  // dart:math.sqrt nggak dipakai biar script tetap sekecil mungkin;
  // di sini cukup iterasi Newton 5x dari 0.5.
  var x = v * 0.5 + 0.5;
  for (var i = 0; i < 5; i++) {
    x = (x + v / x) * 0.5;
  }
  return x;
}

// ---------- PNG encoder (murni) ----------

Uint8List _encodePng(int w, int h, Uint8List rgba) {
  final out = BytesBuilder();

  void chunk(String type, List<int> data) {
    final t = Uint8List.fromList(type.codeUnits);
    final len = ByteData(4)..setUint32(0, data.length);
    out.add(len.buffer.asUint8List());
    out.add(t);
    out.add(data);
    final crcInput = Uint8List(t.length + data.length)
      ..setRange(0, t.length, t)
      ..setRange(t.length, t.length + data.length, data);
    final crc = ByteData(4)..setUint32(0, _crc32(crcInput));
    out.add(crc.buffer.asUint8List());
  }

  out.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

  final ihdr = ByteData(13)
    ..setUint32(0, w)
    ..setUint32(4, h)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 6) // color type 6 = RGBA
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  chunk('IHDR', ihdr.buffer.asUint8List());

  final raw = BytesBuilder();
  for (var y = 0; y < h; y++) {
    raw.addByte(0); // filter None
    raw.add(rgba.sublist(y * w * 4, (y + 1) * w * 4));
  }
  final comp = ZLibCodec(level: 9).encode(raw.toBytes());
  chunk('IDAT', comp);
  chunk('IEND', const <int>[]);

  return out.toBytes();
}

int _crc32(Uint8List data) {
  var crc = 0xFFFFFFFF;
  for (var i = 0; i < data.length; i++) {
    crc ^= data[i];
    for (var j = 0; j < 8; j++) {
      crc = (crc >> 1) ^ (0xEDB88320 & (-(crc & 1)));
    }
  }
  return (~crc) & 0xFFFFFFFF;
}