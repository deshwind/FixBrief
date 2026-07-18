import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_text_field.dart';
import 'package:flutter/material.dart';

class LiquidGlassSearchBar extends StatelessWidget {
  const LiquidGlassSearchBar({
    required this.onChanged,
    this.controller,
    this.hintText = 'Search',
    this.onClear,
    super.key,
  });

  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final String hintText;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassTextField(
      label: 'Search',
      controller: controller,
      hintText: hintText,
      prefixIcon: Icons.search_rounded,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      suffixIcon: onClear == null
          ? null
          : IconButton(
              onPressed: onClear,
              tooltip: 'Clear search',
              icon: const Icon(Icons.close_rounded),
            ),
    );
  }
}
