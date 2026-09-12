import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/hint_preferences_provider.dart';

/// A dismissible information banner shown at the top of a page.
/// It uses [hintPreferencesProvider] to remember if the user has dismissed it.
class HintBanner extends ConsumerStatefulWidget {
  const HintBanner({
    super.key,
    required this.pageKey,
    required this.hints,
    this.icon = Icons.lightbulb_outline,
  });

  /// Unique key for the page (e.g., 'people', 'sites', 'schemes')
  final String pageKey;

  /// Each string in [hints] is rendered as a separate bullet point.
  final List<String> hints;

  /// Icon shown on the left of the banner.
  final IconData icon;

  @override
  ConsumerState<HintBanner> createState() => _HintBannerState();
}

class _HintBannerState extends ConsumerState<HintBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
      value: 1.0,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    ref
        .read(hintPreferencesProvider.notifier)
        .setVisible(widget.pageKey, false);
  }

  @override
  Widget build(BuildContext context) {
    final isVisible = ref.watch(
      hintPreferencesProvider.select((map) => map[widget.pageKey] ?? false),
    );

    if (!isVisible) return const SizedBox.shrink();

    if (_controller.status == AnimationStatus.dismissed) {
      _controller.forward();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return SizeTransition(
      sizeFactor: _animation,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(widget.icon, size: 20, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How to use this page',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...widget.hints.map(
                    (hint) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• ',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          Expanded(
                            child: Text(
                              hint,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colorScheme.onSurface),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              tooltip: 'Dismiss help',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: _dismiss,
            ),
          ],
        ),
      ),
    );
  }
}

/// AppBar Action button to toggle the page hint on/off anytime.
/// Resets to default (green, hint hidden) when the page is navigated away from.
class PageHelpIconButton extends ConsumerStatefulWidget {
  const PageHelpIconButton({super.key, required this.pageKey});

  final String pageKey;

  @override
  ConsumerState<PageHelpIconButton> createState() => _PageHelpIconButtonState();
}

class _PageHelpIconButtonState extends ConsumerState<PageHelpIconButton> {
  @override
  void dispose() {
    // Reset to hidden when the page is navigated away from.
    ref.read(hintPreferencesProvider.notifier).setVisible(widget.pageKey, false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVisible = ref.watch(
      hintPreferencesProvider.select((map) => map[widget.pageKey] ?? false),
    );

    // Default (hint hidden): solid green circle, black outline, black ? icon
    // Active (hint showing): plain icon button, no background
    return isVisible
        ? IconButton(
            icon: const Icon(Icons.help, size: 22),
            tooltip: 'Hide Help',
            onPressed: () =>
                ref.read(hintPreferencesProvider.notifier).toggleHint(widget.pageKey),
          )
        : Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 1.5),
            ),
            child: IconButton(
              icon: const Icon(Icons.help_outline, size: 22, color: Colors.black),
              tooltip: 'Show Help',
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () =>
                  ref.read(hintPreferencesProvider.notifier).toggleHint(widget.pageKey),
            ),
          );
  }
}
