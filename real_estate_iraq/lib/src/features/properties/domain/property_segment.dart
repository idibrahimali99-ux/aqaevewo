/// مقاطعة = قطعة أرض أو وحدة ضمن مجمع (عرض في الأقسام الخاصة).
enum PropertySegment {
  /// عادي (شقة/بيت/محل/أرض كاملة…)
  standard,

  /// مقاطعة / قطعة للبيع ضمن أراضي أو مجمعات
  parcel,
}

extension PropertySegmentX on PropertySegment {
  String? get badgeAr => switch (this) {
        PropertySegment.standard => null,
        PropertySegment.parcel => 'مقاطعة',
      };
}
