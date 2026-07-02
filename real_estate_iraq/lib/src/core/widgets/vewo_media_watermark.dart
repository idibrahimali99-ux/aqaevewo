import 'package:flutter/material.dart';

/// علامة مائية شفافة بهوية عقار تاون.
class VewoMediaWatermark extends StatelessWidget {
  const VewoMediaWatermark({
    super.key,
    this.propertyCode,
    this.phone = supportPhone,
    this.opacity = 0.38,
  });

  final int? propertyCode;
  final String phone;
  final double opacity;

  static const String brandLine = 'عقار تاون | AQAR TOWN';
  static const String supportPhone = '07871456361';
  static const Color wmColor = Color(0xFFD4A000);
  static const String assetPath = 'assets/appha.png';

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) {
          return Center(
            child: Transform.rotate(
              angle: -0.42,
              child: Opacity(
                opacity: opacity.clamp(0.22, 0.55),
                child: Image.asset(
                  assetPath,
                  width: (c.maxWidth * 0.42).clamp(96, 260),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => _FallbackCenterWatermark(
                    propertyCode: propertyCode,
                    phone: phone,
                    opacity: opacity,
                    width: c.maxWidth,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class VewoCornerWatermark extends StatelessWidget {
  const VewoCornerWatermark({super.key, this.opacity = 0.42, this.width = 94});

  final double opacity;
  final double width;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity.clamp(0.22, 0.55),
        child: Image.asset(
          VewoMediaWatermark.assetPath,
          width: width,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const _FallbackCornerWatermark(),
        ),
      ),
    );
  }
}

class _FallbackCenterWatermark extends StatelessWidget {
  const _FallbackCenterWatermark({
    required this.propertyCode,
    required this.phone,
    required this.opacity,
    required this.width,
  });

  final int? propertyCode;
  final String phone;
  final double opacity;
  final double width;

  @override
  Widget build(BuildContext context) {
    final codeLine = propertyCode != null && propertyCode! > 0
        ? '#$propertyCode'
        : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WmText(
          VewoMediaWatermark.brandLine,
          fontSize: width * 0.11,
          opacity: opacity,
        ),
        const SizedBox(height: 6),
        _WmText(phone, fontSize: width * 0.055, opacity: opacity * 0.95),
        if (codeLine != null) ...[
          const SizedBox(height: 4),
          _WmText(codeLine, fontSize: width * 0.065, opacity: opacity * 0.9),
        ],
      ],
    );
  }
}

class _FallbackCornerWatermark extends StatelessWidget {
  const _FallbackCornerWatermark();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          VewoMediaWatermark.brandLine,
          style: TextStyle(
            color: VewoMediaWatermark.wmColor.withValues(alpha: 0.45),
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          VewoMediaWatermark.supportPhone,
          style: TextStyle(
            color: VewoMediaWatermark.wmColor.withValues(alpha: 0.4),
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _WmText extends StatelessWidget {
  const _WmText(this.text, {required this.fontSize, required this.opacity});

  final String text;
  final double fontSize;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: VewoMediaWatermark.wmColor.withValues(
          alpha: opacity.clamp(0.22, 0.55),
        ),
        fontWeight: FontWeight.w900,
        fontSize: fontSize.clamp(14, 42),
        letterSpacing: 0.6,
        height: 1.1,
      ),
    );
  }
}

/// علامة مائية متحركة للريلز مثل تيكتوك: مرة يسار ومرة يمين.
class VewoReelWatermark extends StatefulWidget {
  const VewoReelWatermark({super.key, this.reelCode});

  final int? reelCode;

  @override
  State<VewoReelWatermark> createState() => _VewoReelWatermarkState();
}

class _VewoReelWatermarkState extends State<VewoReelWatermark> {
  bool _right = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 6), _swapSide);
  }

  void _swapSide() {
    if (!mounted) return;
    setState(() => _right = !_right);
    Future<void>.delayed(const Duration(seconds: 6), _swapSide);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPositionedDirectional(
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
      start: _right ? null : 14,
      end: _right ? 14 : null,
      top: 56,
      child: Column(
        crossAxisAlignment: _right
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          const VewoCornerWatermark(width: 94, opacity: 0.42),
          if (widget.reelCode != null && widget.reelCode! > 0)
            Text(
              '#${widget.reelCode}',
              style: TextStyle(
                color: VewoMediaWatermark.wmColor.withValues(alpha: 0.38),
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }
}
