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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final attentionColor = switch (learner.attentionState) {
      'needs_assignment' => theme.colorScheme.errorContainer,
      'review' => theme.colorScheme.tertiaryContainer,
      'ready_now' => theme.colorScheme.secondaryContainer,
      _ => theme.colorScheme.primary.withValues(alpha: 0.12),
    };
    final attentionTextColor = switch (learner.attentionState) {
      'needs_assignment' => theme.colorScheme.onErrorContainer,
      'review' => theme.colorScheme.onTertiaryContainer,
      'ready_now' => theme.colorScheme.onSecondaryContainer,
      _ => theme.colorScheme.primary,
    };
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? isDark
                      ? [
                          Color.alphaBlend(
                            _BrandPalette.goldBright.withValues(alpha: 0.10),
                            _BrandPalette.slateRaised,
                          ),
                          _BrandPalette.slateCard,
                        ]
                      : [
                          Color.alphaBlend(
                            theme.colorScheme.primary.withValues(alpha: 0.14),
                            Colors.white,
                          ),
                          _BrandPalette.warmWhite,
                        ]
                : isDark
                ? [theme.colorScheme.surface, _BrandPalette.slateRaised]
                : [theme.colorScheme.surface, _BrandPalette.warmPaper],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.34)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.64),
            width: selected ? 1.3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? theme.colorScheme.primary.withValues(
                      alpha: isDark ? 0.16 : 0.10,
                    )
                  : Colors.black.withValues(alpha: isDark ? 0.16 : 0.04),
              blurRadius: selected ? 24 : 12,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    learner.displayName,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                _PillBadge(
                  text: 'Age ${learner.currentAge}',
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  textColor: theme.colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              learner.currentLevel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PillBadge(
                  text: learner.attentionLabel,
                  color: attentionColor,
                  textColor: attentionTextColor,
                ),
                if (learner.activeAssignment != null)
                  _PillBadge(
                    text: learner.activeAssignment!.title,
                    color: theme.colorScheme.surfaceContainerHighest,
                    textColor: theme.colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
            if (learner.activeAssignment != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    CornerstoneIcons.session,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      learner.nextActionLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    CornerstoneIcons.activity,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      learner.nextActionLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  CornerstoneIcons.review,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Review: ${learner.reviewItemCount}',
                  style: theme.textTheme.bodySmall,
                ),
                if (learner.todaySession != null) ...[
                  const SizedBox(width: 12),
                  Icon(
                    Icons.today_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      learner.todaySession!.title,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [theme.colorScheme.surface, _BrandPalette.slateRaised]
                : [theme.colorScheme.surface, _BrandPalette.warmPaper],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(
              alpha: isDark ? 0.58 : 0.72,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06),
              blurRadius: isDark ? 26 : 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -36,
              right: -24,
              child: IgnorePointer(
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(
                          alpha: isDark ? 0.12 : 0.10,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(padding: const EdgeInsets.all(26), child: child),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [_BrandPalette.slateHigh, _BrandPalette.slateRaised]
              : [Colors.white, _BrandPalette.warmPaper],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.60),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: theme.colorScheme.primary.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactField extends StatelessWidget {
  const _CompactField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _Band extends StatelessWidget {
  const _Band({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [_BrandPalette.slateRaised, _BrandPalette.slateCard]
              : [const Color(0xFFFFFCF6), const Color(0xFFF8F0E3)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.50),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.36),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
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

class _GoldAccentDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.0),
            theme.colorScheme.primary.withValues(alpha: 0.64),
            theme.colorScheme.primary.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

class _PageHeroCard extends StatelessWidget {
  const _PageHeroCard({
    required this.eyebrow,
    required this.title,
    required this.description,
    this.trailing,
    this.chips = const <Widget>[],
  });

  final String eyebrow;
  final String title;
  final String description;
  final Widget? trailing;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF2A241D), Color(0xFF221E1A), Color(0xFF161412)]
              : const [Color(0xFFFFF2C9), Color(0xFFFFFCF7), Color(0xFFF5EBDD)],
          stops: const [0.0, 0.58, 1.0],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(
            alpha: isDark ? 0.28 : 0.20,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = trailing == null || constraints.maxWidth < 760;
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(
                    alpha: isDark ? 0.18 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(
                      alpha: isDark ? 0.28 : 0.20,
                    ),
                  ),
                ),
                child: Text(
                  eyebrow.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(title, style: theme.textTheme.displaySmall),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Text(
                  description,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 20),
                Wrap(spacing: 12, runSpacing: 12, children: chips),
              ],
            ],
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                if (trailing != null) ...[
                  const SizedBox(height: 20),
                  trailing!,
                ],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: content),
              const SizedBox(width: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: trailing!,
              ),
            ],
          );
        },
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final symbolSize = toolbarVariant
        ? (compact ? 22.0 : 26.0)
        : (compact ? 30.0 : 36.0);
    final wordmarkHeight = toolbarVariant
        ? (compact ? 16.0 : 20.0)
        : (compact ? 20.0 : 26.0);
    final padding = toolbarVariant
        ? (compact
              ? const EdgeInsets.fromLTRB(2, 2, 4, 2)
              : const EdgeInsets.fromLTRB(4, 3, 6, 3))
        : compact
        ? const EdgeInsets.fromLTRB(8, 6, 10, 6)
        : const EdgeInsets.fromLTRB(10, 8, 14, 8);
    final radius = toolbarVariant ? 14.0 : 16.0;

    final contents = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BrandSymbol(size: symbolSize),
        if (!compact) ...[
          SizedBox(width: compact ? 6 : 8),
          _BrandWordmark(height: wordmarkHeight),
        ],
      ],
    );

    final badge = toolbarVariant
        ? Padding(padding: padding, child: contents)
        : AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: padding,
            decoration: BoxDecoration(
              color: isDark ? _BrandPalette.slateRaised : Colors.white,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: _BrandPalette.gold.withValues(alpha: 0.24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: contents,
          );

    if (onTap == null) {
      return badge;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: badge,
      ),
    );
  }
}

class _BrandSymbol extends StatelessWidget {
  const _BrandSymbol({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.24),
      ),
      clipBehavior: Clip.antiAlias,
      child: OverflowBox(
        minWidth: size * 1.84,
        minHeight: size * 1.84,
        maxWidth: size * 1.84,
        maxHeight: size * 1.84,
        alignment: Alignment.center,
        child: Image.asset(
          'assets/images/logo_symbol.png',
          width: size * 1.84,
          height: size * 1.84,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _BrandWordmark extends StatelessWidget {
  const _BrandWordmark({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      'Cornerstone',
      maxLines: 1,
      style: GoogleFonts.sora(
        color: theme.colorScheme.onSurface,
        fontSize: height * 1.08,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.1,
        height: 1,
      ),
    );
  }
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
                icon: Icon(Icons.light_mode_rounded, size: 15),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_rounded, size: 15),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_rounded, size: 15),
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
