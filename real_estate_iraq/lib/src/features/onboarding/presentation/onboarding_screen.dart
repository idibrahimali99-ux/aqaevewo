import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_brand_mark.dart';
import '../../../routing/app_routes.dart';

class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key, required this.child});

  final Widget child;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  static const _seenVersionKey = 'aqar_town_onboarding_seen_version_v1';

  bool? _showOnboarding;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final info = await PackageInfo.fromPlatform();
    final current = '${info.version}+${info.buildNumber}';
    final seen = prefs.getString(_seenVersionKey);
    if (!mounted) return;
    setState(() => _showOnboarding = seen != current);
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    final info = await PackageInfo.fromPlatform();
    await prefs.setString(
      _seenVersionKey,
      '${info.version}+${info.buildNumber}',
    );
    if (!mounted) return;
    setState(() => _showOnboarding = false);
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final show = _showOnboarding;
    if (show == null) {
      return const ColoredBox(
        color: AppColors.appBackground,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (show) {
      return OnboardingScreen(onDone: _finish);
    }
    return widget.child;
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _slides = [
    _OnboardingSlide(
      eyebrow: 'مرحباً بك في',
      title: 'عقار تاون',
      subtitle:
          'منصة عقارية متكاملة تجمع البيع والإيجار والخرائط والريلز في مكان واحد.',
      visual: _OnboardingVisual.hero,
    ),
    _OnboardingSlide(
      eyebrow: 'كل الخدمات',
      title: 'بين يديك',
      subtitle:
          'بيع، إيجار، أراضي، شقق، محلات ومجمعات سكنية بترتيب واضح وسريع.',
      visual: _OnboardingVisual.services,
    ),
    _OnboardingSlide(
      eyebrow: 'اكتشف عقارك',
      title: 'المناسب',
      subtitle:
          'ابحث في الناصرية، ذي قار، الشموخ، وشاهد العقارات على الخريطة مباشرة.',
      visual: _OnboardingVisual.search,
    ),
    _OnboardingSlide(
      eyebrow: 'تجربة سهلة',
      title: 'وآمنة',
      subtitle:
          'بيانات محفوظة، محادثات منظمة، تنبيهات مباشرة، ومنشورات موثوقة.',
      visual: _OnboardingVisual.trust,
    ),
  ];

  final _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_index >= _slides.length - 1) {
      widget.onDone();
      return;
    }
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _slides.length - 1;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.appBackground,
        body: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _slides.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, index) {
                return _SlidePage(slide: _slides[index]);
              },
            ),
            SafeArea(
              child: Align(
                alignment: AlignmentDirectional.topEnd,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(top: 8, end: 10),
                  child: IconButton.filledTonal(
                    tooltip: 'تخطي',
                    onPressed: widget.onDone,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              start: 34,
              end: 34,
              bottom: 22,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _OnboardingDots(count: _slides.length, index: _index),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.frameGold,
                          foregroundColor: Colors.black,
                          elevation: 10,
                          shadowColor: AppColors.frameGold.withValues(
                            alpha: 0.35,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        label: Text(
                          isLast ? 'استكشف التطبيق' : 'التالي',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.visual,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final _OnboardingVisual visual;
}

enum _OnboardingVisual { hero, services, search, trust }

class _SlidePage extends StatelessWidget {
  const _SlidePage({required this.slide});

  final _OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return Stack(
      fit: StackFit.expand,
      children: [
        const _OnboardingBackground(),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 50, 22, 120),
            child: Column(
              children: [
                _SlideHeading(slide: slide),
                SizedBox(height: height < 720 ? 14 : 24),
                Expanded(child: _SlideVisual(type: slide.visual)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OnboardingBackground extends StatelessWidget {
  const _OnboardingBackground();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.appBackground,
      child: Stack(
        children: [
          PositionedDirectional(
            top: 118,
            start: 24,
            end: 24,
            child: Container(
              height: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(48),
                gradient: RadialGradient(
                  colors: [
                    AppColors.frameGold.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: -90,
            end: -82,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.frameGold.withValues(alpha: 0.24),
              ),
            ),
          ),
          PositionedDirectional(
            bottom: 40,
            start: -70,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.frameGold.withValues(alpha: 0.22),
                  width: 2,
                ),
              ),
            ),
          ),
          const PositionedDirectional(top: 28, start: 22, child: _DotPattern()),
          const PositionedDirectional(
            bottom: 92,
            end: 24,
            child: _DotPattern(),
          ),
        ],
      ),
    );
  }
}

class _DotPattern extends StatelessWidget {
  const _DotPattern();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (r) => Row(
          children: List.generate(
            4,
            (c) => Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.frameGold.withValues(alpha: 0.72),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlideHeading extends StatelessWidget {
  const _SlideHeading({required this.slide});

  final _OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          slide.eyebrow,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          slide.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: AppColors.frameGold,
            fontWeight: FontWeight.w900,
            height: 1.0,
            fontSize: 46,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 14),
        const _TitleDivider(),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 330),
          child: Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}

class _TitleDivider extends StatelessWidget {
  const _TitleDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 54, height: 1.4, color: AppColors.frameGold),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.home_rounded, size: 15, color: AppColors.frameGold),
        ),
        Container(width: 54, height: 1.4, color: AppColors.frameGold),
      ],
    );
  }
}

class _SlideVisual extends StatelessWidget {
  const _SlideVisual({required this.type});

  final _OnboardingVisual type;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: switch (type) {
        _OnboardingVisual.hero => const _HeroVisual(),
        _OnboardingVisual.services => const _ServicesVisual(),
        _OnboardingVisual.search => const _SearchVisual(),
        _OnboardingVisual.trust => const _TrustVisual(),
      },
    );
  }
}

class _HeroVisual extends StatelessWidget {
  const _HeroVisual();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          const _CitySilhouette(),
          Transform.rotate(
            angle: -0.055,
            child: const _PhoneMockup(child: _PhoneHomeScreen()),
          ),
        ],
      ),
    );
  }
}

class _SearchVisual extends StatelessWidget {
  const _SearchVisual();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          const _PhoneMockup(
            child: Padding(
              padding: EdgeInsets.fromLTRB(18, 52, 18, 18),
              child: Column(
                children: [
                  _SearchBarMockup(),
                  SizedBox(height: 18),
                  Expanded(child: _MapMockup()),
                ],
              ),
            ),
          ),
          PositionedDirectional(
            bottom: 18,
            start: -10,
            end: -10,
            child: _PropertyPreviewCard(),
          ),
        ],
      ),
    );
  }
}

class _ServicesVisual extends StatelessWidget {
  const _ServicesVisual();

  @override
  Widget build(BuildContext context) {
    const services = [
      (Icons.home_rounded, 'بيع'),
      (Icons.vpn_key_rounded, 'إيجار'),
      (Icons.location_on_rounded, 'أراضي'),
      (Icons.apartment_rounded, 'شقق'),
      (Icons.storefront_rounded, 'محلات'),
      (Icons.location_city_rounded, 'مجمعات'),
    ];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.18,
          children: [
            for (final item in services)
              _ServiceTile(icon: item.$1, label: item.$2),
          ],
        ),
      ),
    );
  }
}

class _TrustVisual extends StatelessWidget {
  const _TrustVisual();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.verified_user_outlined, 'بياناتك محفوظة'),
      (Icons.lock_outline_rounded, 'تصفح آمن'),
      (Icons.support_agent_rounded, 'دعم فني متواصل'),
      (Icons.workspace_premium_outlined, 'عقارات موثوقة'),
    ];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in items) _TrustChip(icon: item.$1, label: item.$2),
          ],
        ),
        const SizedBox(height: 34),
        const _VillaTrustCard(),
      ],
    );
  }
}

class _PhoneMockup extends StatelessWidget {
  const _PhoneMockup({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        PositionedDirectional(
          start: -4,
          top: 86,
          child: _PhoneSideButton(height: 54),
        ),
        PositionedDirectional(
          end: -4,
          top: 122,
          child: _PhoneSideButton(height: 76),
        ),
        Container(
          width: 252,
          height: 420,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(42),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF454545), Color(0xFF0B0B0B), Color(0xFF7A6A3A)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 34,
                offset: const Offset(0, 24),
              ),
              BoxShadow(
                color: AppColors.frameGold.withValues(alpha: 0.22),
                blurRadius: 34,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFF050505),
              borderRadius: BorderRadius.circular(36),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFD559), AppColors.frameGold],
                  ),
                ),
                child: Stack(
                  children: [
                    const _PhoneStatusBar(),
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        margin: const EdgeInsets.only(top: 10),
                        width: 82,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned.fill(child: child),
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.18),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.04),
                            ],
                            stops: const [0, 0.35, 1],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhoneSideButton extends StatelessWidget {
  const _PhoneSideButton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _PhoneStatusBar extends StatelessWidget {
  const _PhoneStatusBar();

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      top: 13,
      start: 18,
      end: 18,
      child: Row(
        children: const [
          Text(
            '9:41',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          Spacer(),
          Icon(
            Icons.signal_cellular_alt_rounded,
            size: 14,
            color: Colors.black,
          ),
          SizedBox(width: 4),
          Icon(Icons.wifi_rounded, size: 14, color: Colors.black),
          SizedBox(width: 4),
          Icon(Icons.battery_full_rounded, size: 16, color: Colors.black),
        ],
      ),
    );
  }
}

class _PhoneHomeScreen extends StatelessWidget {
  const _PhoneHomeScreen();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 50, 18, 18),
      child: Column(
        children: [
          const Image(
            image: AssetImage(AppBrandStrings.iconAsset),
            width: 76,
            height: 76,
          ),
          const SizedBox(height: 14),
          const AppBrandMark(
            showTagline: true,
            tagline: 'منصة عقارية متكاملة',
            color: Colors.white,
          ),
          const SizedBox(height: 22),
          const _SearchBarMockup(),
          const SizedBox(height: 14),
          const _MiniHomeCard(),
          const Spacer(),
          Row(
            children: const [
              _MiniMetric(icon: Icons.home_work_outlined, label: 'عقارات'),
              SizedBox(width: 8),
              _MiniMetric(icon: Icons.map_outlined, label: 'خريطة'),
              SizedBox(width: 8),
              _MiniMetric(icon: Icons.play_circle_outline, label: 'ريلز'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniHomeCard extends StatelessWidget {
  const _MiniHomeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: const LinearGradient(
                colors: [Color(0xFF263B36), Color(0xFFDEA21E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.villa_rounded, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'بيت في الشموخ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                ),
                SizedBox(height: 3),
                Text(
                  'الناصرية - ذي قار',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10),
                ),
                SizedBox(height: 4),
                Text(
                  '250,000,000 د.ع',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBarMockup extends StatelessWidget {
  const _SearchBarMockup();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsetsDirectional.only(start: 14, end: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'ابحث عن موقع أو اسم العقار',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFFB0B0B0),
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: AppColors.frameGold,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}

class _MapMockup extends StatelessWidget {
  const _MapMockup();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF6F1DE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          for (final top in [38.0, 105.0, 176.0])
            Positioned(
              top: top,
              left: 0,
              right: 0,
              child: Divider(
                color: Colors.white.withValues(alpha: 0.95),
                thickness: 2,
              ),
            ),
          for (final left in [46.0, 118.0])
            Positioned(
              top: 0,
              bottom: 0,
              left: left,
              child: VerticalDivider(
                color: Colors.white.withValues(alpha: 0.95),
                thickness: 2,
              ),
            ),
          const Positioned(top: 72, right: 26, child: _Pin(size: 34)),
          const Positioned(top: 126, left: 44, child: _Pin(size: 30)),
          const Positioned(top: 156, right: 82, child: _Pin(size: 26)),
          PositionedDirectional(
            bottom: 14,
            start: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Text(
                'الناصرية - ذي قار - الشموخ',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.location_on_rounded,
      size: size,
      color: AppColors.frameGold,
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: 0.16),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

class _PropertyPreviewCard extends StatelessWidget {
  const _PropertyPreviewCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 92,
            height: 76,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [Color(0xFF2D3C36), Color(0xFFD99E36)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(
              Icons.villa_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'بيت حديث للبيع',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      color: AppColors.frameGold,
                      size: 16,
                    ),
                    SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        'الشموخ - الناصرية',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  '250,000,000 د.ع',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.frameGold, size: 42),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _TrustChip extends StatelessWidget {
  const _TrustChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 142,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.frameGold, size: 30),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _VillaTrustCard extends StatelessWidget {
  const _VillaTrustCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 185,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFF35443E), Color(0xFFFFC235)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.13),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Center(
            child: Icon(
              Icons.house_siding_rounded,
              size: 96,
              color: Colors.white,
            ),
          ),
          PositionedDirectional(
            bottom: 18,
            end: 18,
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.24),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: Colors.white,
                size: 46,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CitySilhouette extends StatelessWidget {
  const _CitySilhouette();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: 330,
        height: 180,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final h in [76.0, 118.0, 92.0, 148.0, 108.0, 70.0])
              Container(
                width: 38,
                height: h,
                decoration: BoxDecoration(
                  color: AppColors.frameGold.withValues(alpha: 0.16),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingDots extends StatelessWidget {
  const _OnboardingDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: i == index ? 22 : 10,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: i == index ? AppColors.frameGold : const Color(0xFFD9D9D9),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
      ],
    );
  }
}
