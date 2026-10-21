import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../theme/app_theme.dart';

/// The app's primary call-to-action button (solid brand pink, or outlined).
///
/// Grows with large text instead of clipping, and shows a spinner while
/// [loading] so repeated taps cannot submit twice.
class PremiumButton extends StatelessWidget {
  const PremiumButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isOutlined = false,
    this.width,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isOutlined;
  final double? width;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final accent = context.palette.accentInk;
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: isOutlined ? accent : AppColors.deepBlack,
            ),
          )
        else if (icon != null)
          Icon(icon, size: 22),
        if (loading || icon != null) const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
    void tap() {
      HapticFeedback.lightImpact();
      onPressed!();
    }

    final button = isOutlined
        ? OutlinedButton(
            onPressed: enabled ? tap : null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(64, 52),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: content,
          )
        : ElevatedButton(
            onPressed: enabled ? tap : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(64, 52),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: content,
          );
    return SizedBox(width: width, child: button);
  }
}
