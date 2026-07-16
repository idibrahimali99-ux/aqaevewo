import 'package:url_launcher/url_launcher.dart';

import 'package:vewo_shared/vewo_shared.dart' show IQDFormatter;

import '../../features/properties/domain/property.dart';

/// رقم واتساب الدعم/الإدارة (بدون صفر).
const kSupportWhatsAppDigits = '9647871456461';

String normalizeIraqPhoneForWhatsApp(String phone) {
  var digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.startsWith('0')) digits = digits.substring(1);
  if (digits.startsWith('7') && digits.length == 10) {
    digits = '964$digits';
  } else if (!digits.startsWith('964')) {
    digits = '964$digits';
  }
  return digits;
}

/// هاتف التواصل: مكتب/مسوق → رقم الناشر، زبون → رقم الدعم.
String resolvePropertyContactPhone(Property property, String supportPhone) {
  if (property.usesPublisherContact) {
    return property.ownerPhone!.trim();
  }
  final fallback = supportPhone.trim();
  return fallback.isNotEmpty ? fallback : '07871456361';
}

String buildPropertyWhatsAppMessage(Property property) {
  final lines = <String>[
    if (property.publicNo != null) 'رقم المنشور: #${property.publicNo}',
    if (property.title.trim().isNotEmpty)
      property.title.trim()
    else
      property.displayCategoryAr,
    '${property.governorate}${property.addressLine.trim().isEmpty ? '' : ' • ${property.addressLine.trim()}'}',
    if (property.priceIqd > 0)
      'السعر: ${IQDFormatter.format(property.priceIqd)}'
    else
      'السعر: حسب الاتفاق',
    if (property.areaSqm > 1) 'المساحة: ${property.areaSqm} م²',
    if (property.segment.name == 'parcel') ...[
      if (_detailStr(property, 'facade_m').isNotEmpty)
        'الواجهة: ${_detailStr(property, 'facade_m')} م',
      if (_detailStr(property, 'depth_m').isNotEmpty)
        'النزال: ${_detailStr(property, 'depth_m')} م',
    ],
    if (property.description.trim().isNotEmpty)
      property.description.trim(),
  ];
  return lines.where((e) => e.trim().isNotEmpty).join('\n');
}

String _detailStr(Property property, String key) =>
    property.detailsJson?[key]?.toString().trim() ?? '';

Future<bool> openWhatsAppToPhone(
  String phone, {
  String? message,
}) async {
  final digits = normalizeIraqPhoneForWhatsApp(phone);
  if (digits.isEmpty) return false;
  final text = message?.trim();
  final encoded = text != null && text.isNotEmpty
      ? Uri.encodeComponent(text)
      : null;
  final candidates = [
    if (encoded != null)
      Uri.parse('https://api.whatsapp.com/send?phone=$digits&text=$encoded'),
    if (encoded != null) Uri.parse('https://wa.me/$digits?text=$encoded'),
    Uri.parse('https://api.whatsapp.com/send?phone=$digits'),
    Uri.parse('https://wa.me/$digits'),
    Uri.parse('whatsapp://send?phone=$digits'),
  ];
  for (final uri in candidates) {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return true;
    } catch (_) {}
  }
  return false;
}

Future<bool> openWhatsAppForProperty(
  Property property,
  String supportPhone,
) async {
  final phone = resolvePropertyContactPhone(property, supportPhone);
  final message = buildPropertyWhatsAppMessage(property);
  return openWhatsAppToPhone(phone, message: message);
}

Future<bool> openWhatsAppSupport({String? message}) async {
  return openWhatsAppToPhone(kSupportWhatsAppDigits, message: message);
}
