import 'dart:convert';

import '../../../core/widgets/app_brand_mark.dart';
import '../domain/property.dart';
import '../domain/property_category.dart';
import '../domain/property_segment.dart';

Property? propertyFromApiRow(
  Map<String, dynamic> j, {
  List<String>? imageUrls,
}) {
  try {
    final id = j['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final catName = j['category']?.toString() ?? 'apartment';
    final segName = j['segment']?.toString() ?? 'standard';
    final category = PropertyCategory.values.firstWhere(
      (e) => e.name == catName,
      orElse: () => PropertyCategory.apartment,
    );
    final segment = PropertySegment.values.firstWhere(
      (e) => e.name == segName,
      orElse: () => PropertySegment.standard,
    );
    final thumb = j['thumb_url']?.toString();
    final images = <String>[];
    if (imageUrls != null && imageUrls.isNotEmpty) {
      images.addAll(imageUrls);
    } else {
      for (final key in const ['image_urls', 'images']) {
        final raw = j[key];
        if (raw is List) {
          for (final u in raw) {
            final s = u?.toString().trim() ?? '';
            if (s.isNotEmpty && !images.contains(s)) images.add(s);
          }
        }
      }
    }
    if (images.isEmpty && thumb != null && thumb.isNotEmpty) {
      images.add(thumb);
    }
    final videoRaw = (j['video_url'] ?? j['videoUrl'])?.toString().trim();
    final videoUrl = videoRaw != null && videoRaw.isNotEmpty ? videoRaw : null;
    // لا صور خارجية — فقط ما يُرجعه السيرفر.
    final status = j['approval_status']?.toString() ?? 'pending';
    final purpose = j['purpose']?.toString() ?? 'sale';
    final soldRaw = j['is_sold'];
    final isSold = soldRaw == true || soldRaw == 1 || soldRaw == '1';
    final ownerRole = j['owner_role']?.toString() ?? '';
    final ownerFn = j['owner_full_name']?.toString().trim() ?? '';
    final ownerOffice = j['owner_office_name']?.toString().trim() ?? '';
    final ovRaw = j['owner_office_verified'];
    final publisherVerified = ovRaw == true || ovRaw == 1 || ovRaw == '1';
    final isOfficePublisher = ownerRole == 'office';
    final isMarketer =
        j['owner_is_marketer'] == true ||
        j['owner_is_marketer'] == 1 ||
        j['owner_is_marketer'] == '1';
    final publisherLabel = isOfficePublisher && !isMarketer
        ? (ownerOffice.isNotEmpty
              ? ownerOffice
              : (ownerFn.isNotEmpty ? ownerFn : 'مكتب عقاري'))
        : AppBrandStrings.plainShort;
    DateTime? publishedAt;
    final createdRaw = j['created_at']?.toString();
    if (createdRaw != null && createdRaw.isNotEmpty) {
      publishedAt = DateTime.tryParse(createdRaw);
    }
    final pubRaw = j['property_public_no'];
    final publicNo = pubRaw is num
        ? pubRaw.toInt()
        : int.tryParse(pubRaw?.toString() ?? '');
    Map<String, dynamic>? detailsJson;
    final dj = j['details_json'];
    if (dj is Map) {
      detailsJson = Map<String, dynamic>.from(dj);
    } else if (dj is String && dj.trim().isNotEmpty) {
      final dec = jsonDecode(dj);
      if (dec is Map) {
        detailsJson = Map<String, dynamic>.from(dec);
      }
    }
    final compoundNameRaw =
        (j['compound_name'] ??
                j['compoundName'] ??
                detailsJson?['compound_name'])
            ?.toString()
            .trim();
    final compoundName = compoundNameRaw != null && compoundNameRaw.isNotEmpty
        ? compoundNameRaw
        : null;
    if (compoundName != null) {
      detailsJson = {...?detailsJson, 'compound_name': compoundName};
    }

    return Property(
      id: id,
      approvalStatus: status,
      title: j['title']?.toString() ?? '',
      governorate: j['governorate']?.toString() ?? '',
      addressLine: (j['address_line'] ?? j['addressLine'])?.toString() ?? '',
      category: category,
      segment: segment,
      purpose: purpose == 'rent' ? 'rent' : 'sale',
      priceIqd: int.tryParse(j['price_iqd']?.toString() ?? '') ?? 0,
      areaSqm: int.tryParse(j['area_sqm']?.toString() ?? '') ?? 0,
      images: images,
      videoUrl: videoUrl,
      videoTrimStartSeconds: int.tryParse(
        detailsJson?['video_trim_start_seconds']?.toString() ?? '',
      ),
      videoTrimEndSeconds: int.tryParse(
        detailsJson?['video_trim_end_seconds']?.toString() ?? '',
      ),
      description: j['description']?.toString() ?? '',
      detailsJson: detailsJson,
      ownerUserId: j['owner_user_id']?.toString(),
      views: int.tryParse(j['views']?.toString() ?? '') ?? 0,
      isApproved: status == 'approved',
      isSold: isSold,
      publisherLabel: publisherLabel,
      publisherVerified: isOfficePublisher ? publisherVerified : true,
      isOfficePublisher: isOfficePublisher,
      ownerPhone: j['owner_phone']?.toString().trim(),
      publicNo: (publicNo != null && publicNo > 0) ? publicNo : null,
      publishedAt: publishedAt,
      compoundId: j['compound_id']?.toString().trim(),
      compoundName: compoundName,
      parcelId: j['parcel_id']?.toString().trim(),
    );
  } catch (_) {
    return null;
  }
}
