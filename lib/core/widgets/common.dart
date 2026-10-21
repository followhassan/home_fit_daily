import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/app_theme.dart';
import '../../data/models/enums.dart';

/// Constrains content to a readable width and centres it on tablets.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = Space.maxContentWidth});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// A surface card with consistent radius, border and tap feedback.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Space.lg),
    this.gradient,
    this.color,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(Space.radiusLg);
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(onTap: onTap, borderRadius: radius, child: content);
    }
    final card = Ink(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? palette.surface) : null,
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(color: palette.border.withValues(alpha: 0.7)),
      ),
      child: content,
    );
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      container: true,
      child: Material(type: MaterialType.transparency, child: card),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(0, Space.xl, 0, Space.sm),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Semantics(header: true, child: Text(title, style: context.text.titleLarge)),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// Friendly message for empty lists, with an optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(Space.lg),
            decoration: BoxDecoration(
              color: AppColors.premiumPink.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: context.palette.accentInk),
          ),
          const SizedBox(height: Space.lg),
          Text(title, style: context.text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: Space.sm),
          Text(
            message,
            style: context.text.bodyMedium?.copyWith(color: context.palette.textSecondary),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: Space.lg),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// Small icon + label chip used for workout and exercise metadata.
class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final c = color ?? palette.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(Space.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: c),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: context.text.labelMedium?.copyWith(color: palette.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Difficulty shown with both bars and text, so it never relies on colour.
class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.level, this.compact = false});

  final Difficulty level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = switch (level) {
      Difficulty.beginner => palette.success,
      Difficulty.intermediate => palette.warning,
      Difficulty.advanced => palette.accentInk,
    };
    return Semantics(
      label: 'Level: ${level.label}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: palette.surfaceAlt,
          borderRadius: BorderRadius.circular(Space.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 4,
                height: 6.0 + i * 4,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  color: i <= level.rank ? color : palette.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            if (!compact) ...[
              const SizedBox(width: 5),
              Text(
                level.label,
                style: context.text.labelMedium?.copyWith(color: palette.textPrimary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A number with a label, for statistics.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.footnote,
  });

  final IconData icon;
  final String value;
  final String label;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(Space.md + 2),
      semanticLabel: '$label: $value${footnote == null ? '' : ', $footnote'}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: context.palette.accentInk),
            const SizedBox(height: Space.sm),
            Text(value, style: context.text.headlineSmall),
            const SizedBox(height: 2),
            Text(label, style: context.text.bodySmall),
            if (footnote != null)
              Text(footnote!, style: context.text.bodySmall?.copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// A grid whose rows grow to fit their content, so tiles never clip when
/// text is enlarged (unlike fixed-aspect-ratio grids).
class TileGrid extends StatelessWidget {
  const TileGrid({
    super.key,
    required this.children,
    this.minTileWidth = 150,
    this.maxColumns = 4,
    this.spacing = Space.sm,
  });

  final List<Widget> children;
  final double minTileWidth;
  final int maxColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fit = ((constraints.maxWidth + spacing) / (minTileWidth + spacing)).floor();
        final columns = fit.clamp(1, maxColumns);
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += columns) {
          final rowChildren = children.skip(i).take(columns).toList();
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var c = 0; c < columns; c++) ...[
                    if (c > 0) SizedBox(width: spacing),
                    Expanded(
                      child: c < rowChildren.length ? rowChildren[c] : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) SizedBox(height: spacing),
              rows[r],
            ],
          ],
        );
      },
    );
  }
}

/// Circular progress with a centred child.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 72,
    this.strokeWidth = 7,
    this.child,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              backgroundColor: context.palette.surfaceAlt,
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}

/// Asks for confirmation; returns true only if the user confirms.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
  String cancelLabel = 'Cancel',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Text(message)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(cancelLabel)),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: context.palette.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                )
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showMessage(BuildContext context, String message, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action));
}

/// A labelled −/+ stepper for numeric settings.
class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    this.step = 1,
    this.format,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;
  final String Function(int)? format;

  @override
  Widget build(BuildContext context) {
    final text = format?.call(value) ?? '$value';
    return Semantics(
      label: label,
      value: text,
      increasedValue: value + step <= max
          ? (format?.call(value + step) ?? '${value + step}')
          : null,
      decreasedValue: value - step >= min
          ? (format?.call(value - step) ?? '${value - step}')
          : null,
      onIncrease: value + step <= max ? () => onChanged(value + step) : null,
      onDecrease: value - step >= min ? () => onChanged(value - step) : null,
      child: Row(
        children: [
          Expanded(
            child: ExcludeSemantics(child: Text(label, style: context.text.bodyLarge)),
          ),
          ExcludeSemantics(
            child: IconButton.filledTonal(
              onPressed: value - step >= min ? () => onChanged(value - step) : null,
              icon: const Icon(Icons.remove_rounded),
              tooltip: 'Decrease',
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 64),
            child: ExcludeSemantics(
              child: Text(text, textAlign: TextAlign.center, style: context.text.titleMedium),
            ),
          ),
          ExcludeSemantics(
            child: IconButton.filledTonal(
              onPressed: value + step <= max ? () => onChanged(value + step) : null,
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Increase',
            ),
          ),
        ],
      ),
    );
  }
}

/// A row of selectable chips for one value.
class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> options;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: Space.sm,
    runSpacing: Space.sm,
    children: [
      for (final option in options)
        ChoiceChip(
          label: Text(labelOf(option)),
          selected: option == selected,
          onSelected: (_) => onSelected(option),
        ),
    ],
  );
}

/// A row of toggleable chips for a set of values.
class MultiChoiceChips<T> extends StatelessWidget {
  const MultiChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  final List<T> options;
  final Set<T> selected;
  final String Function(T) labelOf;
  final ValueChanged<Set<T>> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: Space.sm,
    runSpacing: Space.sm,
    children: [
      for (final option in options)
        FilterChip(
          label: Text(labelOf(option)),
          selected: selected.contains(option),
          onSelected: (on) =>
              onChanged(on ? {...selected, option} : ({...selected}..remove(option))),
        ),
    ],
  );
}
