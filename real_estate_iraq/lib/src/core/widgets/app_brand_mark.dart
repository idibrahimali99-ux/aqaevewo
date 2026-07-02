import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// نصوص العلامة للقوائم والبيانات (بدون أداة الرسم).
abstract final class AppBrandStrings {
  static const String arabicName = 'عقار تاون';
  static const String englishName = 'AQAR TOWN';
  static const String plainShort = '$arabicName | $englishName';
  static const String iconAsset = 'assets/app_icon.png';
}

/// ألوان شعار الإطار — نفس قيم [AppColors.frameNavy] / [AppColors.frameGold].
abstract final class AppBrandEmblemColors {
  static const Color frameNavy = AppColors.frameNavy;
  static const Color frameGold = AppColors.frameGold;
}

/// شعار التطبيق النصي الموحّد: عقار تاون | AQAR TOWN.
enum AppBrandMarkVariant {
  /// صفحة ترحيب، رأس تسجيل.
  hero,

  /// شريط التطبيق والعناوين المضغوطة.
  compact,
}

class AppBrandMark extends StatelessWidget {
  const AppBrandMark({
    super.key,
    this.variant = AppBrandMarkVariant.hero,
    this.showTagline = false,
    this.tagline = 'عقاراتك بثقة',
    this.color,
    this.englishName = AppBrandStrings.englishName,
  });

  final AppBrandMarkVariant variant;
  final bool showTagline;
  final String tagline;
  final Color? color;

  /// الاسم الإنجليزي الظاهر تحت الاسم العربي.
  final String englishName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    final compact = variant == AppBrandMarkVariant.compact;

    final iconSize = compact ? 30.0 : 42.0;
    final arabicSize = compact ? 18.0 : 27.0;
    final englishSize = compact ? 8.5 : 11.5;

    final core = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BrandIcon(size: iconSize, compact: compact),
        const SizedBox(width: 10),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: compact ? 92 : 190),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppBrandStrings.arabicName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: arabicSize,
                  height: 1.05,
                  color: c,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                englishName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: englishSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: compact ? 1.6 : 2.4,
                  color: c.withValues(alpha: 0.78),
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final marked = showTagline
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              core,
              const SizedBox(height: 5),
              Text(
                tagline,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          )
        : core;

    return Semantics(label: AppBrandStrings.plainShort, child: marked);
  }
}

class _BrandIcon extends StatelessWidget {
  const _BrandIcon({required this.size, required this.compact});

  final double size;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(compact ? 10 : 15);
    final pinSize = compact ? 13.0 : 17.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.frameGold.withValues(alpha: 0.22),
                    blurRadius: compact ? 8 : 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: Image.asset(
                  AppBrandStrings.iconAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => ColoredBox(
                    color: AppColors.frameGold,
                    child: Icon(
                      Icons.home_work_rounded,
                      color: AppColors.onBrand,
                      size: compact ? 18 : 25,
                    ),
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            end: compact ? -2 : -3,
            bottom: compact ? -2 : -3,
            child: Container(
              width: pinSize,
              height: pinSize,
              decoration: BoxDecoration(
                color: AppColors.onBrand,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.frameGold, width: 1.3),
              ),
              child: Icon(
                Icons.location_on_rounded,
                size: compact ? 9 : 12,
                color: AppColors.frameGold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// عنوان AppBar عادي: عنوان الشاشة + شعار مضغوط في سطر واحد (RTL).
class AppBarBrandTitle extends StatelessWidget {
  const AppBarBrandTitle(this.screenTitle, {super.key});

  final String screenTitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.rtl,
      children: [
        Flexible(
          child: Text(
            screenTitle,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.onBrand,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 26,
          width: 126,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AppBrandMark(
              variant: AppBrandMarkVariant.compact,
              color: AppColors.onBrand,
            ),
          ),
        ),
      ],
    );
  }
}

/// عنوان لـ [SliverAppBar.large]: شعار + اسم الشاشة تحته.
class SliverAppBarBrandHeading extends StatelessWidget {
  const SliverAppBarBrandHeading({super.key, required this.screenTitle});

  final String screenTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AppBrandMark(
          variant: AppBrandMarkVariant.compact,
          color: AppColors.onBrand,
        ),
        const SizedBox(height: 6),
        Text(
          screenTitle,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.onBrand.withValues(alpha: 0.86),
          ),
        ),
      ],
    );
  }
}

/// شعار الصفحة الرئيسية: إطار فاخر باسم عقار تاون / AQAR TOWN.
class HomeFramedBrandMark extends StatelessWidget {
  const HomeFramedBrandMark({super.key});

  static const Color _navy = AppBrandEmblemColors.frameNavy;
  static const Color _gold = AppBrandEmblemColors.frameGold;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(200.0, 292.0)
            : 268.0;
        final tracking = ((maxW - 72) / 22).clamp(5.0, 11.0);

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _navy,
                border: Border.all(color: _gold, width: 1.25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppBrandStrings.englishName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _gold,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: tracking,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 11),
                    const Text(
                      AppBrandStrings.arabicName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _gold,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// رأس [SliverAppBar.large] للصفحة الرئيسية فقط — إطار عقار تاون.
class SliverHomeBrandHeading extends StatelessWidget {
  const SliverHomeBrandHeading({super.key, required this.screenTitle});

  final String screenTitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const HomeFramedBrandMark(),
        const SizedBox(height: 9),
        Text(
          screenTitle,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
