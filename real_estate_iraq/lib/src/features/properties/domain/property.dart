import 'property_category.dart';
import 'property_segment.dart';

class Property {
  const Property({
    required this.id,
    required this.title,
    required this.governorate,
    required this.addressLine,
    required this.category,
    required this.segment,
    this.purpose = 'sale',
    required this.priceIqd,
    required this.areaSqm,
    required this.images,
    this.videoUrl,
    this.videoTrimStartSeconds,
    this.videoTrimEndSeconds,
    required this.description,
    this.detailsJson,
    this.ownerUserId,
    required this.views,
    required this.isApproved,
    this.isSold = false,
    this.publisherLabel = '',
    this.publisherVerified = false,
    this.isOfficePublisher = false,
    this.ownerPhone,
    this.publicNo,
    this.approvalStatus = 'approved',
    this.publishedAt,
    this.compoundId,
    this.compoundName,
    this.parcelId,
  });

  final String id;
  final String title;
  final String governorate;
  final String addressLine;
  final PropertyCategory category;
  final PropertySegment segment;

  /// بيع أو إيجار (`sale` / `rent`)
  final String purpose;
  final int priceIqd;
  final int areaSqm;
  final List<String> images;
  final String? videoUrl;
  final int? videoTrimStartSeconds;
  final int? videoTrimEndSeconds;
  final String description;
  final Map<String, dynamic>? detailsJson;
  final String? ownerUserId;
  final int views;
  final bool isApproved;
  final bool isSold;

  /// اسم المكتب أو الناشر الشخصي (من السيرفر).
  final String publisherLabel;

  /// شارة توثيق للمكتب فقط.
  final bool publisherVerified;
  final bool isOfficePublisher;
  final String? ownerPhone;

  /// رقم العرض (#…) للبحث والنسخ.
  final int? publicNo;

  /// من السيرفر: `approved` | `pending` | `rejected` | …
  final String approvalStatus;

  /// وقت النشر من السيرفر.
  final DateTime? publishedAt;

  final String? compoundId;
  final String? compoundName;
  final String? parcelId;

  /// تسمية الفئة في البطاقة (مقاطعة بدل أرض للمنشورات ضمن مقاطعة).
  String get displayCategoryAr {
    if (segment == PropertySegment.parcel) return 'مقاطعة';
    return category.labelAr;
  }
}
