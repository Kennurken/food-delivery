import 'package:flutter/material.dart';

import '../theme/motion.dart';

/// Odometer-style number: each digit rolls vertically when it changes
/// (jitter "Counter", animate-ui sliding number). Non-digit chars fade.
class SlidingNumber extends StatelessWidget {
  const SlidingNumber(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? DefaultTextStyle.of(context).style;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < text.length; i++)
          _Glyph(
            key: ValueKey('${text.length}-$i'),
            char: text[i],
            style: style,
          ),
      ],
    );
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph({super.key, required this.char, required this.style});

  final String char;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final isDigit = int.tryParse(char) != null;
    return AnimatedSwitcher(
      duration: Motion.normal,
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      transitionBuilder: (child, anim) {
        if (!isDigit) return FadeTransition(opacity: anim, child: child);
        // Incoming slides up from below, outgoing slides up and away.
        final slide = Tween(
          begin: const Offset(0, 0.6),
          end: Offset.zero,
        ).animate(anim);
        return ClipRect(
          child: FadeTransition(
            opacity: anim,
            child: SlideTransition(position: slide, child: child),
          ),
        );
      },
      layoutBuilder: (current, previous) =>
          Stack(alignment: Alignment.center, children: [...previous, ?current]),
      child: Text(char, key: ValueKey(char), style: style),
    );
  }
}
