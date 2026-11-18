// Erzeugt alle App-Icons aus tool/icon/source.webp:
//   flutter test tool/icon/make_icons_test.dart
//
// 1. Das Weiße außerhalb der abgerundeten Fläche wird durchsichtig (von den Ecken her gefüllt,
//    die Kante bleibt weich).
// 2. Daraus entstehen: tool/icon/app_icon.png (1024 px), die Android-Icons (alt + adaptiv),
//    und windows/runner/resources/app_icon.ico. (Linux hat noch kein Fenster-Icon.)
// Läuft als Test, weil dart:ui (Bilder lesen/skalieren) nur in der Flutter-Umgebung da ist –
// so braucht es kein zusätzliches Paket.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// Ab dieser Helligkeit (kleinster Farbkanal) gilt ein Pixel als „weißer Rand“.
const _white = 150;

/// Macht das mit den Ecken verbundene Weiß durchsichtig. [px] ist RGBA ohne Vormultiplikation.
void cutWhiteCorners(Uint8List px, int w, int h) {
  int minC(int i) {
    final r = px[i], g = px[i + 1], b = px[i + 2];
    return r < g ? (r < b ? r : b) : (g < b ? g : b);
  }

  final out = Uint8List(w * h); // 1 = Hintergrund
  final stack = <int>[0, w - 1, (h - 1) * w, h * w - 1];
  while (stack.isNotEmpty) {
    final p = stack.removeLast();
    if (out[p] == 1 || minC(p * 4) < _white) continue;
    out[p] = 1;
    final x = p % w, y = p ~/ w;
    if (x > 0) stack.add(p - 1);
    if (x < w - 1) stack.add(p + 1);
    if (y > 0) stack.add(p - w);
    if (y < h - 1) stack.add(p + w);
  }
  // Weiche Kante: Pixel direkt am Hintergrund sind eine Mischung aus Farbe und Weiß.
  // Anteil Weiß herausrechnen, damit kein heller Saum bleibt.
  final edge = <int>[];
  for (var p = 0; p < w * h; p++) {
    if (out[p] == 1) continue;
    final x = p % w, y = p ~/ w;
    var near = false;
    for (var dy = -2; dy <= 2 && !near; dy++) {
      for (var dx = -2; dx <= 2 && !near; dx++) {
        final nx = x + dx, ny = y + dy;
        if (nx >= 0 && ny >= 0 && nx < w && ny < h && out[ny * w + nx] == 1) near = true;
      }
    }
    if (near) edge.add(p);
  }
  for (final p in edge) {
    final i = p * 4;
    final a = (255 - minC(i)) / 255; // 0 = reines Weiß
    if (a <= 0.02) {
      px[i + 3] = 0;
      continue;
    }
    for (var c = 0; c < 3; c++) {
      px[i + c] = ((px[i + c] - 255 * (1 - a)) / a).round().clamp(0, 255);
    }
    px[i + 3] = (a * 255).round();
  }
  for (var p = 0; p < w * h; p++) {
    if (out[p] == 1) px[p * 4 + 3] = 0;
  }
}

Future<ui.Image> _fromStraight(Uint8List px, int w, int h) async {
  final pre = Uint8List.fromList(px);
  for (var i = 0; i < pre.length; i += 4) {
    final a = pre[i + 3];
    pre[i] = pre[i] * a ~/ 255;
    pre[i + 1] = pre[i + 1] * a ~/ 255;
    pre[i + 2] = pre[i + 2] * a ~/ 255;
  }
  final buf = await ui.ImmutableBuffer.fromUint8List(pre);
  final desc = ui.ImageDescriptor.raw(buf, width: w, height: h, pixelFormat: ui.PixelFormat.rgba8888);
  return (await (await desc.instantiateCodec()).getNextFrame()).image;
}

/// Zeichnet [src] mit [scale] (1 = füllt die Fläche) mittig auf ein Quadrat der Größe [size].
Future<ui.Image> _resize(ui.Image src, int size, {double scale = 1}) {
  final rec = ui.PictureRecorder();
  final s = size * scale, o = (size - s) / 2;
  ui.Canvas(rec).drawImageRect(
    src,
    ui.Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
    ui.Rect.fromLTWH(o, o, s, s),
    ui.Paint()..filterQuality = ui.FilterQuality.medium,
  );
  return rec.endRecording().toImage(size, size);
}

Future<Uint8List> _png(ui.Image img) async =>
    (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();

Future<void> _write(String path, List<int> bytes) async {
  final f = File(path);
  await f.parent.create(recursive: true);
  await f.writeAsBytes(bytes);
}

/// Ein ICO-Eintrag als 32-Bit-Bitmap (BGRA, von unten nach oben, plus leere Maske).
Future<Uint8List> _icoBitmap(ui.Image img) async {
  final n = img.width;
  final rgba = (await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!.buffer.asUint8List();
  final maskRow = ((n + 31) ~/ 32) * 4;
  final b = ByteData(40 + n * n * 4 + maskRow * n);
  b.setUint32(0, 40, Endian.little);
  b.setInt32(4, n, Endian.little);
  b.setInt32(8, n * 2, Endian.little);
  b.setUint16(12, 1, Endian.little);
  b.setUint16(14, 32, Endian.little);
  b.setUint32(20, n * n * 4, Endian.little);
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      final s = ((n - 1 - y) * n + x) * 4, d = 40 + (y * n + x) * 4;
      b.setUint8(d, rgba[s + 2]);
      b.setUint8(d + 1, rgba[s + 1]);
      b.setUint8(d + 2, rgba[s]);
      b.setUint8(d + 3, rgba[s + 3]);
    }
  }
  return b.buffer.asUint8List();
}

Uint8List _ico(List<(int size, Uint8List data)> entries) {
  final head = ByteData(6 + 16 * entries.length);
  head.setUint16(2, 1, Endian.little);
  head.setUint16(4, entries.length, Endian.little);
  var offset = head.lengthInBytes;
  final out = BytesBuilder();
  for (var i = 0; i < entries.length; i++) {
    final (size, data) = entries[i];
    final o = 6 + 16 * i;
    head.setUint8(o, size >= 256 ? 0 : size);
    head.setUint8(o + 1, size >= 256 ? 0 : size);
    head.setUint16(o + 4, 1, Endian.little);
    head.setUint16(o + 6, 32, Endian.little);
    head.setUint32(o + 8, data.length, Endian.little);
    head.setUint32(o + 12, offset, Endian.little);
    offset += data.length;
  }
  out.add(head.buffer.asUint8List());
  for (final (_, data) in entries) {
    out.add(data);
  }
  return out.toBytes();
}

void main() {
  testWidgets('App-Icons erzeugen', (tester) async {
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(File('tool/icon/source.webp').readAsBytesSync());
      final src = (await codec.getNextFrame()).image;
      final w = src.width, h = src.height;
      final px = (await src.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!.buffer.asUint8List();
      cutWhiteCorners(px, w, h);
      final cut = await _fromStraight(px, w, h);

      // Ecken sind durchsichtig, die Mitte bleibt deckend
      expect(px[3], 0);
      expect(px[(h * w - 1) * 4 + 3], 0);
      expect(px[((h ~/ 2) * w + w ~/ 2) * 4 + 3], 255);

      await _write('tool/icon/app_icon.png', await _png(await _resize(cut, 1024)));

      const res = 'android/app/src/main/res';
      for (final (name, dp) in [('mdpi', 1.0), ('hdpi', 1.5), ('xhdpi', 2.0), ('xxhdpi', 3.0), ('xxxhdpi', 4.0)]) {
        await _write('$res/mipmap-$name/ic_launcher.png', await _png(await _resize(cut, (48 * dp).round())));
        // Adaptives Icon: 108 dp, sichtbar sind die mittleren 72 dp. Auf 80 % verkleinert bleibt
        // das Klemmbrett bei jeder Maske (Kreis, Squircle) ganz im Bild.
        await _write(
          '$res/mipmap-$name/ic_launcher_foreground.png',
          await _png(await _resize(cut, (108 * dp).round(), scale: 0.8)),
        );
      }

      await _write(
        'windows/runner/resources/app_icon.ico',
        _ico([
          for (final s in [16, 24, 32, 48, 64]) (s, await _icoBitmap(await _resize(cut, s))),
          (256, await _png(await _resize(cut, 256))),
        ]),
      );
    });
  });
}
