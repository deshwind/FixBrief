import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/theme/liquid_glass_tokens.dart';
import 'package:fixbrief/core/theme/motion_tokens.dart';
import 'package:flutter/material.dart';

class LiquidGlassTextField extends StatefulWidget {
  const LiquidGlassTextField({
    required this.label,
    this.controller,
    this.focusNode,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.onVoiceInput,
    this.onChanged,
    this.validator,
    this.maxLength,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onFieldSubmitted,
    this.enabled = true,
    this.obscureText = false,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final VoidCallback? onVoiceInput;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final int? maxLength;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;
  final bool obscureText;

  @override
  State<LiquidGlassTextField> createState() => _LiquidGlassTextFieldState();
}

class _LiquidGlassTextFieldState extends State<LiquidGlassTextField> {
  late final FocusNode _focusNode;
  late final bool _ownsFocusNode;

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.glassColors;
    final tokens = context.glassTokens;
    final colorScheme = Theme.of(context).colorScheme;
    final focused = _focusNode.hasFocus;

    return Semantics(
      textField: true,
      label: widget.label,
      child: AnimatedContainer(
        duration: MotionTokens.smallChange,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.controlRadius),
          color: colors.glassTint.withValues(
            alpha: Theme.of(context).brightness == Brightness.dark
                ? 0.72
                : 0.78,
          ),
          border: Border.all(
            width: focused ? 1.8 : 1,
            color: focused
                ? colorScheme.primary
                : colors.glassBorder.withValues(
                    alpha: tokens.borderOpacity + 0.12,
                  ),
          ),
        ),
        child: TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          obscureText: widget.obscureText,
          onChanged: widget.onChanged,
          validator: widget.validator,
          maxLength: widget.maxLength,
          maxLines: widget.maxLines,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          onFieldSubmitted: widget.onFieldSubmitted,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hintText,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(widget.prefixIcon),
            suffixIcon: widget.onVoiceInput != null
                ? IconButton(
                    onPressed: widget.onVoiceInput,
                    tooltip: 'Enter ${widget.label} by voice',
                    icon: const Icon(Icons.mic_none_rounded),
                  )
                : widget.suffixIcon,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 17,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
