/// مطابقة أسماء المحافظات بين القوائم المحلية وجداول السيرفر.
bool governorateNamesMatch(String a, String b) {
  final x = a.trim().toLowerCase().replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا');
  final y = b.trim().toLowerCase().replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا');
  if (x.isEmpty || y.isEmpty) return true;
  return x == y || x.contains(y) || y.contains(x);
}
