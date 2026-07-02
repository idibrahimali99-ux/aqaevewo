import 'package:flutter/material.dart';

class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.isLoading && widget.onPressed != null;
    return Listener(
      onPointerDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onPointerUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onPointerCancel: enabled ? (_) => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: widget.isLoading ? null : widget.onPressed,
            icon: widget.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(widget.icon ?? Icons.arrow_forward),
            label: Text(widget.label),
          ),
        ),
      ),
    );
  }
}
