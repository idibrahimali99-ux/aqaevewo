import 'package:flutter/material.dart';

/// أبعاد الزوايا والحدود الموحّدة للثيم (بطاقات، أزرار، حقول، نوافذ سفلية).
abstract final class AppShape {
  static const double radiusXs = 6;
  static const double radiusSm = 12;
  static const double radiusMd = 18;
  static const double radiusLg = 26;

  static BorderRadius get borderXs => BorderRadius.circular(radiusXs);

  static BorderRadius get borderSm => BorderRadius.circular(radiusSm);
  static BorderRadius get borderMd => BorderRadius.circular(radiusMd);
  static BorderRadius get borderLg => BorderRadius.circular(radiusLg);

  static BorderRadius get bottomSheetTop =>
      BorderRadius.vertical(top: Radius.circular(radiusLg));
}
