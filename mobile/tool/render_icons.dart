// Renders every AnimShape to a PNG grid so the drawing can be reviewed by eye.
//
// Lives outside test/ on purpose: `flutter test` only discovers that directory,
// and this is a tool, not a check — it encodes an image, which takes long
// enough to time out a normal suite run. Run it directly:
//
//     flutter test tool/render_icons.dart && open /tmp/anim_icons.png

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/widgets/anim_icon.dart';

void main() {
  testWidgets('render icon sheet', (tester) async {
    const frames = [0.25, 0.5, 0.75, 1.0];
    const cell = 72.0;
    final shapes = AnimShape.values;
    final width = cell * frames.length;
    final height = cell * shapes.length;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = const Color(0xFF14100E),
    );

    for (var row = 0; row < shapes.length; row++) {
      for (var col = 0; col < frames.length; col++) {
        canvas.save();
        canvas.translate(col * cell + 12, row * cell + 12);
        paintShape(
          canvas,
          shapes[row],
          frames[col],
          48,
          const Color(0xFFE8562A),
        );
        canvas.restore();
      }
    }

    final picture = recorder.endRecording();
    // Encoding an image has to happen on the real async loop: inside the fake
    // async zone flutter_test installs, toImage() never completes.
    final out = File(
      Platform.environment['ICON_SHEET'] ?? '/tmp/anim_icons.png',
    );
    await tester.runAsync(() async {
      final image = await picture.toImage(width.toInt(), height.toInt());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await out.writeAsBytes(bytes!.buffer.asUint8List());
    });
    expect(await out.length(), greaterThan(0));
  });
}
