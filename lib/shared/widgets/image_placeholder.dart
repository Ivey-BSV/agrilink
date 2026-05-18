import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';

class ImagePlaceholder extends StatelessWidget {
  final IconData icon;
  final double borderRadius;
  final Color? tint;

  const ImagePlaceholder({
    super.key,
    this.icon = Icons.image,
    this.borderRadius = 12,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = tint ?? AppTheme.primaryGreen;
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 48,
          color: accent,
        ),
      ),
    );
  }
}
