import 'package:flutter/material.dart';

/// Segmented pill tabs; indicator slides between segments (animate-ui Tabs).
class PillTabBar extends StatelessWidget implements PreferredSizeWidget {
  const PillTabBar({super.key, required this.tabs, this.controller});

  final List<String> tabs;

  /// Null uses the surrounding DefaultTabController.
  final TabController? controller;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Container(
        height: 42,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: TabBar(
          controller: controller,
          tabs: [for (final t in tabs) Tab(text: t)],
        ),
      ),
    );
  }
}
