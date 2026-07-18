import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_text_field.dart';
import 'package:flutter/material.dart';

class DraftTextField extends StatefulWidget {
  const DraftTextField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hintText,
    this.prefixIcon,
    this.onVoiceInput,
    this.suffixIcon,
    this.maxLength,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.enabled = true,
    super.key,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? hintText;
  final IconData? prefixIcon;
  final VoidCallback? onVoiceInput;
  final Widget? suffixIcon;
  final int? maxLength;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool enabled;

  @override
  State<DraftTextField> createState() => _DraftTextFieldState();
}

class _DraftTextFieldState extends State<DraftTextField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant DraftTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text && !_focusNode.hasFocus) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassTextField(
      controller: _controller,
      focusNode: _focusNode,
      label: widget.label,
      hintText: widget.hintText,
      prefixIcon: widget.prefixIcon,
      onVoiceInput: widget.onVoiceInput,
      suffixIcon: widget.suffixIcon,
      maxLength: widget.maxLength,
      maxLines: widget.maxLines,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
    );
  }
}
