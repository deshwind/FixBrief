import 'package:fixbrief/core/widgets/fixbrief_logo.dart';
import 'package:fixbrief/core/widgets/liquid_glass/fluid_background.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FluidBackground(
        child: Center(
          child: Semantics(
            liveRegion: true,
            label: 'FixBrief is loading',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FixBriefLogo(size: 96, semanticLabel: 'FixBrief'),
                const SizedBox(height: 22),
                Text(
                  'FixBrief',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 22),
                const SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
