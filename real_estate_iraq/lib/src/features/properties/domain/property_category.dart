enum PropertyCategory { land, house, apartment, shop, compound, villa }

extension PropertyCategoryX on PropertyCategory {
  String get labelAr => switch (this) {
        PropertyCategory.land => 'أرض',
        PropertyCategory.house => 'بيت',
        PropertyCategory.apartment => 'شقة',
        PropertyCategory.shop => 'محل',
        PropertyCategory.compound => 'مجمع',
        PropertyCategory.villa => 'فيلا',
      };
}

