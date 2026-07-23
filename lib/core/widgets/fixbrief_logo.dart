import 'package:flutter/material.dart';

/// The canonical FixBrief brand mark used throughout the application.
class FixBriefLogo extends StatelessWidget {
  const FixBriefLogo({
    this.size = 48,
    this.semanticLabel = 'FixBrief logo',
    super.key,
  });

  static const assetPath = 'assets/branding/fixbrief_logo.png';

  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.235),
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
