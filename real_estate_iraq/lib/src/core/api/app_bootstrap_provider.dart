import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/news/domain/property_news_models.dart';
import 'api_providers.dart';
import 'vewo_api_client.dart';

class HomePromotion {
  const HomePromotion({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.linkType,
    required this.linkTarget,
    required this.sortOrder,
    required this.displayMode,
    required this.popupDurationSec,
    this.campaignEndsAt,
    required this.slot,
  });

  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String linkType;
  final String linkTarget;
  final int sortOrder;

  /// `both` | `slider` | `popup`
  final String displayMode;
  final int popupDurationSec;
  final DateTime? campaignEndsAt;
  final String slot;

  bool get showsInSlider => displayMode == 'both' || displayMode == 'slider';

  bool get showsInPopup => displayMode == 'both' || displayMode == 'popup';

  factory HomePromotion.fromJson(Map<String, dynamic> j) {
    DateTime? ends;
    final endsRaw = j['campaign_ends_at']?.toString();
    if (endsRaw != null && endsRaw.isNotEmpty) {
      ends = DateTime.tryParse(endsRaw);
    }
    return HomePromotion(
      id: j['id']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      subtitle: j['subtitle']?.toString() ?? '',
      imageUrl: j['image_url']?.toString() ?? '',
      linkType: j['link_type']?.toString() ?? 'none',
      linkTarget: j['link_target']?.toString() ?? '',
      sortOrder: int.tryParse(j['sort_order']?.toString() ?? '') ?? 0,
      displayMode: j['display_mode']?.toString() ?? 'both',
      popupDurationSec:
          int.tryParse(j['popup_duration_sec']?.toString() ?? '') ?? 20,
      campaignEndsAt: ends,
      slot: j['slot']?.toString() ?? 'home',
    );
  }
}

class HomeSectionConfig {
  const HomeSectionConfig({
    required this.key,
    required this.label,
    required this.iconName,
    required this.routeTarget,
    required this.sortOrder,
    required this.isActive,
  });

  final String key;
  final String label;
  final String iconName;
  final String routeTarget;
  final int sortOrder;
  final bool isActive;

  factory HomeSectionConfig.fromJson(Map<String, dynamic> j) {
    return HomeSectionConfig(
      key: j['section_key']?.toString() ?? '',
      label: j['label']?.toString() ?? '',
      iconName: j['icon_name']?.toString() ?? 'home',
      routeTarget: j['route_target']?.toString() ?? '',
      sortOrder: int.tryParse(j['sort_order']?.toString() ?? '') ?? 0,
      isActive: j['is_active'] == true || j['is_active']?.toString() == '1',
    );
  }
}

class AppUpdatePolicy {
  const AppUpdatePolicy({
    required this.minVersion,
    required this.minBuild,
    required this.latestVersion,
    required this.latestBuild,
    required this.androidStoreUrl,
    required this.iosStoreUrl,
    required this.title,
    required this.message,
  });

  final String minVersion;
  final int minBuild;
  final String latestVersion;
  final int latestBuild;
  final String androidStoreUrl;
  final String iosStoreUrl;
  final String title;
  final String message;

  static const empty = AppUpdatePolicy(
    minVersion: '',
    minBuild: 0,
    latestVersion: '',
    latestBuild: 0,
    androidStoreUrl: '',
    iosStoreUrl: '',
    title: 'يتوفر إصدار جديد',
    message: 'حدّث تطبيق عقار تاون للاستمرار في استخدام التطبيق.',
  );

  factory AppUpdatePolicy.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return empty;
    var minVersion = json['min_version']?.toString().trim() ?? '';
    var latestVersion = json['latest_version']?.toString().trim() ?? '';
    if (minVersion.isEmpty) minVersion = latestVersion;
    if (latestVersion.isEmpty) latestVersion = minVersion;
    return AppUpdatePolicy(
      minVersion: minVersion,
      minBuild: int.tryParse('${json['min_build'] ?? 0}') ?? 0,
      latestVersion: latestVersion,
      latestBuild: int.tryParse('${json['latest_build'] ?? 0}') ?? 0,
      androidStoreUrl: json['android_store_url']?.toString().trim() ?? '',
      iosStoreUrl: json['ios_store_url']?.toString().trim() ?? '',
      title: (json['title']?.toString().trim().isNotEmpty ?? false)
          ? json['title'].toString().trim()
          : empty.title,
      message: (json['message']?.toString().trim().isNotEmpty ?? false)
          ? json['message'].toString().trim()
          : empty.message,
    );
  }
}

class AppBootstrapData {
  const AppBootstrapData({
    required this.supportPhone,
    required this.promotions,
    required this.propertyNews,
    required this.homeSections,
    this.appUpdate = AppUpdatePolicy.empty,
  });

  final String supportPhone;
  final List<HomePromotion> promotions;
  final List<PropertyNewsSummary> propertyNews;
  final List<HomeSectionConfig> homeSections;
  final AppUpdatePolicy appUpdate;

  static AppBootstrapData empty() => const AppBootstrapData(
    supportPhone: '',
    promotions: [],
    propertyNews: [],
    homeSections: [],
  );

  factory AppBootstrapData.fromJson(Map<String, dynamic> json) {
    final raw = json['promotions'];
    final list = <HomePromotion>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          list.add(HomePromotion.fromJson(e));
        } else if (e is Map) {
          list.add(HomePromotion.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    final rawNews = json['property_news'];
    final newsList = <PropertyNewsSummary>[];
    if (rawNews is List) {
      for (final e in rawNews) {
        if (e is Map<String, dynamic>) {
          newsList.add(PropertyNewsSummary.fromJson(e));
        } else if (e is Map) {
          newsList.add(
            PropertyNewsSummary.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    final rawSections = json['home_sections'];
    final sectionList = <HomeSectionConfig>[];
    if (rawSections is List) {
      for (final e in rawSections) {
        if (e is Map<String, dynamic>) {
          sectionList.add(HomeSectionConfig.fromJson(e));
        } else if (e is Map) {
          sectionList.add(
            HomeSectionConfig.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    return AppBootstrapData(
      supportPhone: json['support_phone']?.toString() ?? '',
      promotions: list,
      propertyNews: newsList,
      homeSections: sectionList.where((s) => s.isActive).toList(),
      appUpdate: AppUpdatePolicy.fromJson(
        json['app_update'] is Map
            ? Map<String, dynamic>.from(json['app_update'] as Map)
            : null,
      ),
    );
  }
}

/// إعدادات عامة من السيرفر (رقم الدعم + إعلانات الرئيسية).
final appBootstrapProvider = FutureProvider<AppBootstrapData>((ref) async {
  final api = ref.read(vewoApiClientProvider);
  try {
    final data = await api.getJson('app/bootstrap');
    return AppBootstrapData.fromJson(data);
  } on VewoApiException {
    return AppBootstrapData(
      supportPhone: '07887444177',
      promotions: const [],
      propertyNews: const [],
      homeSections: const [],
    );
  } catch (_) {
    return AppBootstrapData(
      supportPhone: '07887444177',
      promotions: const [],
      propertyNews: const [],
      homeSections: const [],
    );
  }
});
