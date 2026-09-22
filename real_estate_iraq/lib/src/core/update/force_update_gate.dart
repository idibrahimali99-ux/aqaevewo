import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/app_bootstrap_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/app_brand_mark.dart';

int compareAppVersions(String a, String b) {
  List<int> parts(String raw) {
    final cleaned = raw.trim().split(RegExp(r'[^0-9.]+')).first;
    return cleaned
        .split('.')
        .where((e) => e.isNotEmpty)
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
  }

  final left = parts(a);
  final right = parts(b);
  final n = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < n; i++) {
    final lv = i < left.length ? left[i] : 0;
    final rv = i < right.length ? right[i] : 0;
    if (lv != rv) return lv.compareTo(rv);
  }
  return 0;
}

bool appNeedsRequiredUpdate({
  required String installedVersion,
  required int installedBuild,
  required AppUpdatePolicy policy,
}) {
  final minVersion = policy.minVersion.trim();
  if (minVersion.isEmpty && policy.minBuild <= 0) return false;
  if (minVersion.isNotEmpty) {
    final cmp = compareAppVersions(installedVersion, minVersion);
    if (cmp < 0) return true;
    if (cmp > 0) return false;
  }
  if (policy.minBuild > 0 && installedBuild < policy.minBuild) return true;
  return false;
}

class AppUpdateDecision {
  const AppUpdateDecision({required this.required, required this.policy});

  final bool required;
  final AppUpdatePolicy policy;
}

final appUpdateDecisionProvider = FutureProvider<AppUpdateDecision>((
  ref,
) async {
  final boot = await ref.watch(appBootstrapProvider.future);
  final info = await PackageInfo.fromPlatform();
  final policy = boot.appUpdate;
  final required = appNeedsRequiredUpdate(
    installedVersion: info.version,
    installedBuild: int.tryParse(info.buildNumber) ?? 0,
    policy: policy,
  );
  return AppUpdateDecision(required: required, policy: policy);
});

class ForceUpdateGate extends ConsumerStatefulWidget {
  const ForceUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ForceUpdateGate> createState() => _ForceUpdateGateState();
}

class _ForceUpdateGateState extends ConsumerState<ForceUpdateGate>
    with WidgetsBindingObserver {
  bool _openingStore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(appBootstrapProvider);
      ref.invalidate(appUpdateDecisionProvider);
    }
  }

  Future<void> _openStore(AppUpdatePolicy policy) async {
    if (_openingStore) return;
    setState(() => _openingStore = true);
    try {
      if (kIsWeb) {
        return;
      }
      final urls = <Uri>[];
      final isIos = defaultTargetPlatform == TargetPlatform.iOS;
      if (isIos) {
        final ios = policy.iosStoreUrl.trim();
        if (ios.isNotEmpty) urls.add(Uri.parse(ios));
        if (ios.isEmpty || ios.contains('apps.apple.com')) {
          urls.add(
            Uri.parse(
              'https://apps.apple.com/search?term=${Uri.encodeComponent('عقار تاون')}',
            ),
          );
        }
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final android = policy.androidStoreUrl.trim();
        if (android.isNotEmpty) urls.add(Uri.parse(android));
        final looksLikeDirect = android.toLowerCase().contains('.apk') ||
            (android.isNotEmpty &&
                !android.contains('play.google.com') &&
                !android.startsWith('market:'));
        if (!looksLikeDirect) {
          urls.add(Uri.parse('market://details?id=com.aqartown.app'));
          urls.add(
            Uri.parse(
              'https://play.google.com/store/apps/details?id=com.aqartown.app',
            ),
          );
        }
      }
      var opened = false;
      for (final uri in urls) {
        try {
          if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
            opened = true;
            break;
          }
        } catch (_) {}
      }
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح المتجر. حاول مرة أخرى.')),
        );
      }
    } finally {
      if (mounted) setState(() => _openingStore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return widget.child;
    final decision = ref.watch(appUpdateDecisionProvider);
    return decision.maybeWhen(
      data: (d) {
        if (!d.required) return widget.child;
        return _ForceUpdateScreen(
          policy: d.policy,
          opening: _openingStore,
          onUpdate: () => _openStore(d.policy),
        );
      },
      orElse: () => widget.child,
    );
  }
}

class _ForceUpdateScreen extends StatelessWidget {
  const _ForceUpdateScreen({
    required this.policy,
    required this.opening,
    required this.onUpdate,
  });

  final AppUpdatePolicy policy;
  final bool opening;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final latest = policy.latestVersion.trim().isNotEmpty
        ? policy.latestVersion.trim()
        : policy.minVersion.trim();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: AppColors.appBackground,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                children: [
                  const Spacer(),
                  const AppBrandMark(variant: AppBrandMarkVariant.hero),
                  const SizedBox(height: 28),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWarm,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.frameGold, width: 1.4),
                    ),
                    child: const Icon(
                      Icons.system_update_alt_rounded,
                      size: 36,
                      color: AppColors.frameNavy,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    policy.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (latest.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'الإصدار $latest',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.frameGold,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    policy.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      height: 1.6,
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: opening ? null : onUpdate,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: AppColors.frameNavy,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: opening
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.4),
                            )
                          : const Text(
                              'تحديث الآن',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    defaultTargetPlatform == TargetPlatform.iOS
                        ? 'سيتم فتح App Store'
                        : (policy.androidStoreUrl.toLowerCase().contains('.apk') ||
                              (policy.androidStoreUrl.isNotEmpty &&
                                  !policy.androidStoreUrl.contains(
                                    'play.google.com',
                                  )))
                        ? 'سيتم فتح رابط تحميل التحديث'
                        : 'سيتم فتح Google Play',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
