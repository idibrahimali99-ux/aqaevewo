import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

abstract final class AqarTownSocialLinks {
  static const facebook =
      'https://www.facebook.com/profile.php?id=61591583834702';
  static const instagram = 'https://www.instagram.com/aqaretown';
  static const facebookNative = 'fb://profile/61591583834702';
  static const instagramNative = 'instagram://user?username=aqaretown';
}

Future<void> openAqarTownSocialLink(BuildContext context, String url) async {
  final candidates = <Uri>[
    if (url.contains('facebook.com'))
      Uri.parse(AqarTownSocialLinks.facebookNative),
    if (url.contains('instagram.com'))
      Uri.parse(AqarTownSocialLinks.instagramNative),
    Uri.parse(url),
  ];
  for (final uri in candidates) {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (_) {
      // جرّب الرابط التالي (تطبيق غير مثبت أو سياسة iOS).
    }
  }
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تعذر فتح الرابط')));
  }
}

class FacebookBrandMark extends StatelessWidget {
  const FacebookBrandMark({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF1877F2),
          borderRadius: BorderRadius.circular(size * 0.28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1877F2).withValues(alpha: 0.28),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Align(
          alignment: const Alignment(0.18, -0.12),
          child: Text(
            'f',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.64,
              fontWeight: FontWeight.w800,
              height: 1,
              shadows: const [
                Shadow(color: Color(0x33000000), blurRadius: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class InstagramBrandMark extends StatelessWidget {
  const InstagramBrandMark({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFDD2A7B).withValues(alpha: 0.28),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.28),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: [
                  Color(0xFFF58529),
                  Color(0xFFDD2A7B),
                  Color(0xFF8134AF),
                  Color(0xFF515BD4),
                ],
              ),
            ),
            child: CustomPaint(
              size: Size.square(size),
              painter: const _InstagramCameraPainter(),
            ),
          ),
        ),
      ),
    );
  }
}

class _InstagramCameraPainter extends CustomPainter {
  const _InstagramCameraPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final inset = size.width * 0.22;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - inset * 2,
        size.height - inset * 2,
      ),
      Radius.circular(size.width * 0.16),
    );
    canvas.drawRRect(rect, paint);

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.52),
      size.width * 0.14,
      paint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.68, size.height * 0.34),
      size.width * 0.035,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
