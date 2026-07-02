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

class AppBootstrapData {
  const AppBootstrapData({
    required this.supportPhone,
    required this.promotions,
    required this.propertyNews,
    required this.homeSections,
  });

  final String supportPhone;
  final List<HomePromotion> promotions;
  final List<PropertyNewsSummary> propertyNews;
  final List<HomeSectionConfig> homeSections;

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
      supportPhone: '07871456361',
      promotions: const [],
      propertyNews: const [],
      homeSections: const [],
    );
  } catch (_) {
    return AppBootstrapData(
      supportPhone: '07871456361',
      promotions: const [],
      propertyNews: const [],
      homeSections: const [],
    );
  }
});
