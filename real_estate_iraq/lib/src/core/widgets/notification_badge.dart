import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// شارة عدد الإشعارات — [onBrandHeader] للهيدر الذهبي، [alert] للخلفيات الفاتحة.
enum NotificationBadgeStyle { onBrandHeader, alert }

class NotificationCountBadge extends StatelessWidget {
  const NotificationCountBadge({
    super.key,
    required this.count,
    this.style = NotificationBadgeStyle.alert,
    this.compact = true,
  });

  final int count;
  final NotificationBadgeStyle style;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final txt = count > 99 ? '99+' : '$count';
    final onHeader = style == NotificationBadgeStyle.onBrandHeader;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: onHeader ? AppColors.textPrimary : const Color(0xFFDC2626),
        borderRadius: BorderRadius.circular(999),
        border: onHeader
            ? Border.all(color: AppColors.onBrand, width: 1.5)
            : null,
        boxShadow: onHeader
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Text(
        txt,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: compact ? 10 : 11,
        ),
      ),
    );
  }
}

class NotificationIconWithBadge extends StatelessWidget {
  const NotificationIconWithBadge({
    super.key,
    required this.count,
    this.style = NotificationBadgeStyle.alert,
    this.icon = Icons.notifications_none_rounded,
  });

  final int count;
  final NotificationBadgeStyle style;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return Icon(icon);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          top: -2,
          right: -2,
          child: NotificationCountBadge(
            count: count,
            style: style,
          ),
        ),
      ],
    );
  }
}
