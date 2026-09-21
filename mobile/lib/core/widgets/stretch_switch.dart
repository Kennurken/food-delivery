import 'package:flutter/material.dart';

import '../theme/motion.dart';

/// Toggle whose thumb stretches while pressed and slides with a spring
/// (animate-ui Switch `pressedWidth`, jitter "On / Off Toggle").
class StretchSwitch extends StatefulWidget {
  const StretchSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  State<StretchSwitch> createState() => _StretchSwitchState();
}

class _StretchSwitchState extends State<StretchSwitch> {
  bool _pressed = false;

  static const _w = 52.0, _h = 30.0, _pad = 3.0, _thumb = 24.0, _stretch = 32.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = widget.value;
    final enabled = widget.onChanged != null;
    final thumbW = _pressed ? _stretch : _thumb;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTap: enabled ? () => widget.onChanged!(!on) : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: AnimatedContainer(
          duration: Motion.normal,
          curve: Motion.emphasized,
          width: _w,
          height: _h,
          padding: const EdgeInsets.all(_pad),
          decoration: BoxDecoration(
            color: on ? scheme.primary : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(_h),
          ),
          child: AnimatedAlign(
            duration: Motion.normal,
            curve: Motion.emphasized,
            alignment: on ? Alignment.centerRight : Alignment.centerLeft,
            child: AnimatedContainer(
              duration: Motion.fast,
              curve: Curves.easeOut,
              width: thumbW,
              height: _thumb,
              decoration: BoxDecoration(
                color: on ? scheme.onPrimary : scheme.outline,
                borderRadius: BorderRadius.circular(_thumb),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
