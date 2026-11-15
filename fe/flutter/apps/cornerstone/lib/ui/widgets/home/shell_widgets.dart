part of '../../../main.dart';

class _LearnerCard extends StatelessWidget {
  const _LearnerCard({
    required this.learner,
    required this.selected,
    required this.onTap,
  });
  final LearnerDashboard learner;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      key: ValueKey('view-learner-${learner.learnerId}'),
      selected: selected,
      selectedTileColor: scheme.primaryContainer,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: Text(learner.displayName.substring(0, 1)),
      ),
      title: Text(
        learner.displayName,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      subtitle: Text('Age ${learner.currentAge} · ${learner.attentionLabel}'),
      trailing: const Icon(Icons.chevron_right_rounded, size: 18),
      onTap: onTap,
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(padding: const EdgeInsets.all(24), child: child),
  );
}

class _PillBadge extends StatelessWidget {
  const _PillBadge({
    required this.text,
    required this.color,
    required this.textColor,
  });

  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: textColor.withValues(alpha: 0.12)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 10.5,
          letterSpacing: 0.0,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 40,
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text('Something went wrong', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup({
    this.compact = false,
    this.toolbarVariant = false,
    this.onTap,
  });
  final bool compact;
  final bool toolbarVariant;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BrandSymbol(size: toolbarVariant ? 32 : 44),
          const SizedBox(width: 10),
          _BrandWordmark(height: compact ? 18 : 21),
        ],
      ),
    ),
  );
}

/// Four cut stones leave a quiet cross in the negative space.
class _BrandSymbol extends StatelessWidget {
  const _BrandSymbol({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Cornerstone symbol',
    image: true,
    child: CustomPaint(
      size: Size.square(size),
      painter: _CornerstonePainter(Theme.of(context).colorScheme.primary),
    ),
  );
}

class _CornerstonePainter extends CustomPainter {
  const _CornerstonePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 40, size.height / 40);
    final stones = [
      [
        const Offset(5, 8),
        const Offset(17, 4),
        const Offset(17, 17),
        const Offset(5, 17),
      ],
      [
        const Offset(22, 4),
        const Offset(35, 8),
        const Offset(35, 17),
        const Offset(22, 17),
      ],
      [
        const Offset(5, 22),
        const Offset(17, 22),
        const Offset(17, 36),
        const Offset(5, 31),
      ],
      [
        const Offset(22, 22),
        const Offset(35, 22),
        const Offset(35, 31),
        const Offset(22, 36),
      ],
    ];
    for (var i = 0; i < stones.length; i++) {
      final path = Path()..addPolygon(stones[i], true);
      canvas.drawPath(
        path,
        Paint()..color = color.withValues(alpha: [1.0, .78, .78, 1.0][i]),
      );
    }
  }

  @override
  bool shouldRepaint(_CornerstonePainter oldDelegate) =>
      color != oldDelegate.color;
}

class _BrandWordmark extends StatelessWidget {
  const _BrandWordmark({required this.height});
  final double height;
  @override
  Widget build(BuildContext context) => Text(
    'Cornerstone',
    maxLines: 1,
    style: GoogleFonts.manrope(
      color: Theme.of(context).colorScheme.onSurface,
      fontSize: height,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.9,
    ),
  );
}

class _AppearancePanel extends StatelessWidget {
  const _AppearancePanel({required this.controller, this.compact = false});

  final CornerstoneThemeController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final stacked = compact || MediaQuery.sizeOf(context).width < 720;
        final selector = SizedBox(
          width: stacked ? double.infinity : 176,
          child: SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const <ButtonSegment<ThemeMode>>[
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                tooltip: 'Light mode',
                icon: Icon(
                  Icons.light_mode_rounded,
                  size: 15,
                  semanticLabel: 'Light mode',
                ),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                tooltip: 'Follow system theme',
                icon: Icon(
                  Icons.brightness_auto_rounded,
                  size: 15,
                  semanticLabel: 'Follow system theme',
                ),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                tooltip: 'Dark mode',
                icon: Icon(
                  Icons.dark_mode_rounded,
                  size: 15,
                  semanticLabel: 'Dark mode',
                ),
              ),
            ],
            selected: <ThemeMode>{controller.themeMode},
            onSelectionChanged: (selection) =>
                controller.setThemeMode(selection.first),
          ),
        );

        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: theme.brightness == Brightness.dark
                  ? [_BrandPalette.slateRaised, _BrandPalette.slateCard]
                  : [Colors.white, _BrandPalette.warmPaper],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.44),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Appearance',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(switch (controller.themeMode) {
                        ThemeMode.light => 'Light mode active',
                        ThemeMode.dark => 'Dark mode active',
                        ThemeMode.system => 'Following system theme',
                      }, style: theme.textTheme.bodySmall),
                      const SizedBox(height: 14),
                      selector,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Appearance',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(switch (controller.themeMode) {
                              ThemeMode.light => 'Light mode active',
                              ThemeMode.dark => 'Dark mode active',
                              ThemeMode.system => 'Following system theme',
                            }, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      selector,
                    ],
                  ),
          ),
        );
      },
    );
  }
}

/// Hover on desktop, tap or keyboard on touch and accessible clients.
class _HoverProfileMenu extends StatefulWidget {
  const _HoverProfileMenu({
    required this.child,
    required this.items,
    required this.onOpenChanged,
  });
  final Widget child;
  final List<Widget> items;
  final ValueChanged<bool> onOpenChanged;
  @override
  State<_HoverProfileMenu> createState() => _HoverProfileMenuState();
}

class _HoverProfileMenuState extends State<_HoverProfileMenu> {
  final _controller = MenuController();
  Timer? _closeTimer;
  void _keepOpen() => _closeTimer?.cancel();
  void _open() {
    _keepOpen();
    if (!_controller.isOpen) _controller.open();
  }

  void _scheduleClose() {
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 240), () {
      if (mounted) _controller.close();
    });
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MenuAnchor(
    controller: _controller,
    onOpen: () => widget.onOpenChanged(true),
    onClose: () => widget.onOpenChanged(false),
    menuChildren: [
      for (final item in widget.items)
        MouseRegion(
          onEnter: (_) => _keepOpen(),
          onExit: (_) => _scheduleClose(),
          child: item,
        ),
    ],
    builder: (context, controller, _) => MouseRegion(
      onEnter: (_) => _open(),
      onExit: (_) => _scheduleClose(),
      child: Semantics(
        label: 'Profile menu',
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () =>
              controller.isOpen ? controller.close() : controller.open(),
          child: Padding(padding: const EdgeInsets.all(6), child: widget.child),
        ),
      ),
    ),
  );
}
