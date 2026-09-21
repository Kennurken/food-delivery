import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/motion.dart';

/// iOS-style banner sliding in from the top (jitter "Simple Notification").
/// Call [LiveToast.show] from anywhere with an Overlay.
class LiveToast {
  LiveToast._();

  /// Host overlay; mounted by [LiveEventsListener] above the router so
  /// banners survive route changes.
  static final overlayKey = GlobalKey<OverlayState>();

  static OverlayEntry? _current;

  static void show({
    required String title,
    required String body,
    IconData icon = Icons.notifications_active_outlined,
    VoidCallback? onTap,
  }) {
    _current?.remove();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _Banner(
        title: title,
        body: body,
        icon: icon,
        onTap: () {
          entry.remove();
          if (_current == entry) _current = null;
          onTap?.call();
        },
        onDismissed: () {
          if (entry.mounted) entry.remove();
          if (_current == entry) _current = null;
        },
      ),
    );
    _current = entry;
    overlayKey.currentState?.insert(entry);
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.title,
    required this.body,
    required this.icon,
    required this.onTap,
    required this.onDismissed,
  });

  final String title;
  final String body;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 8,
      left: 12,
      right: 12,
      child:
          Dismissible(
                key: UniqueKey(),
                direction: DismissDirection.up,
                onDismissed: (_) => onDismissed(),
                child: Material(
                  color: Colors.transparent,
                  child: GestureDetector(
                    onTap: onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.inverseSurface,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 24,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              icon,
                              color: scheme.onPrimary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: scheme.onInverseSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  body,
                                  style: TextStyle(
                                    color: scheme.onInverseSurface.withValues(
                                      alpha: 0.8,
                                    ),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .animate(
                onComplete: (c) =>
                    Future.delayed(const Duration(seconds: 4), onDismissed),
              )
              .slideY(
                begin: -1.2,
                end: 0,
                duration: Motion.slow,
                curve: Motion.pop,
              )
              .fadeIn(duration: Motion.normal),
    );
  }
}
