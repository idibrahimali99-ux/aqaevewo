import 'dart:math' as math;

import 'package:flutter/material.dart';

enum AppScreenClass { compact, medium, expanded }

class AppResponsive {
  const AppResponsive._();

  static AppScreenClass screenClass(BuildContext context) {
    final width = MediaQuery.sizeOf(context).shortestSide;
    if (width >= 840) return AppScreenClass.expanded;
    if (width >= 600) return AppScreenClass.medium;
    return AppScreenClass.compact;
  }

  static bool isTablet(BuildContext context) =>
      screenClass(context) != AppScreenClass.compact;

  static double pageHorizontalPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return switch (screenClass(context)) {
      AppScreenClass.compact => 16,
      AppScreenClass.medium => 24,
      AppScreenClass.expanded => math.min(36, width * 0.045),
    };
  }

  static double readableMaxWidth(BuildContext context) {
    return switch (screenClass(context)) {
      AppScreenClass.compact => double.infinity,
      AppScreenClass.medium => 680,
      AppScreenClass.expanded => 760,
    };
  }

  static double bottomNavHeight(
    BuildContext context, {
    bool collapsed = false,
  }) {
    return collapsed ? 56 : 66;
  }

  static double floatingNavBottomGap(
    BuildContext context, {
    bool collapsed = false,
  }) {
    return MediaQuery.viewPaddingOf(context).bottom + (collapsed ? 8 : 12);
  }

  static double shellContentBottomPadding(
    BuildContext context, {
    bool collapsed = false,
    double extra = 24,
  }) {
    return floatingNavBottomGap(context, collapsed: collapsed) +
        bottomNavHeight(context, collapsed: collapsed) +
        extra;
  }

  static double keyboardAwareBottomPadding(
    BuildContext context, {
    double min = 16,
    double extra = 0,
  }) {
    final media = MediaQuery.of(context);
    return math.max(media.viewPadding.bottom, media.viewInsets.bottom) +
        min +
        extra;
  }

  static EdgeInsets pagePadding(
    BuildContext context, {
    double top = 16,
    double bottomExtra = 0,
    bool accountForShellNav = false,
  }) {
    final horizontal = pageHorizontalPadding(context);
    final bottom = accountForShellNav
        ? shellContentBottomPadding(context, extra: bottomExtra)
        : keyboardAwareBottomPadding(context, extra: bottomExtra);
    return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
  }
}

class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final resolvedMaxWidth =
        maxWidth ?? AppResponsive.readableMaxWidth(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
