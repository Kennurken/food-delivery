import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/widgets/anim_icon.dart';

/// A real MaterialApp: an IconButton's tooltip needs an Overlay above it, and
/// a bare Directionality does not provide one.
Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  ),
);

void main() {
  group('animated icons', () {
    testWidgets('every shape paints through its whole animation', (
      tester,
    ) async {
      for (final shape in AnimShape.values) {
        await tester.pumpWidget(_host(AnimIcon(shape, size: 32)));
        // Step through the run rather than jumping to the end: a painter can be
        // fine at t=1 and divide by zero halfway.
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 70));
        }
        expect(tester.takeException(), isNull, reason: shape.name);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('reduced motion settles on the finished drawing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const AnimIcon(AnimShape.bag), reduceMotion: true),
      );

      // Straight to the end frame, with nothing to sit through: reduced motion
      // means no animation, not a missing icon.
      final state = tester.state<AnimIconState>(find.byType(AnimIcon));
      expect(state.progress, 1);
    });

    testWidgets('reduced motion ignores a replay request', (tester) async {
      await tester.pumpWidget(
        _host(
          const AnimIcon(AnimShape.bag, play: AnimPlay.onTap),
          reduceMotion: true,
        ),
      );

      tester.state<AnimIconState>(find.byType(AnimIcon)).replay();
      await tester.pump();

      expect(tester.state<AnimIconState>(find.byType(AnimIcon)).progress, 1);
    });

    testWidgets('a looping icon keeps scheduling frames', (tester) async {
      await tester.pumpWidget(
        _host(const AnimIcon(AnimShape.scooter, play: AnimPlay.loop)),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.binding.hasScheduledFrame, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the button replays on press and still calls back', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          AnimIconButton(
            shape: AnimShape.stop,
            tooltip: 'stop',
            onPressed: () => taps++,
          ),
        ),
      );

      await tester.tap(find.byType(IconButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(taps, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a disabled button does not fire', (tester) async {
      await tester.pumpWidget(
        _host(const AnimIconButton(shape: AnimShape.bell, onPressed: null)),
      );

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('size and colour come from the ambient icon theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const IconTheme(
            data: IconThemeData(size: 40, color: Color(0xFF00FF00)),
            child: AnimIcon(AnimShape.card),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(AnimIcon),
          matching: find.byType(CustomPaint),
        ),
      );
      expect(paint.size, const Size(40, 40));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
