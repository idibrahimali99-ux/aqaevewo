class PropertyNewsSummary {
  const PropertyNewsSummary({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.publishedAt,
  });

  final String id;
  final String title;
  final String imageUrl;
  final DateTime publishedAt;

  factory PropertyNewsSummary.fromJson(Map<String, dynamic> j) {
    final raw = j['published_at']?.toString() ?? j['created_at']?.toString() ?? '';
    return PropertyNewsSummary(
      id: j['id']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      imageUrl: j['image_url']?.toString() ?? '',
      publishedAt: DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// تنسيق تاريخ بسيط بدون `DateFormat` حتى لا يتعطل التطبيق إن لم تُهيَّأ بيانات locale.
String formatPropertyNewsDate(DateTime d) {
  final x = d.toLocal();
  return '${x.day.toString().padLeft(2, '0')}/${x.month.toString().padLeft(2, '0')}/${x.year}';
}

class PropertyNewsDetail {
  const PropertyNewsDetail({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.body,
    required this.publishedAt,
  });

  final String id;
  final String title;
  final String imageUrl;
  final String body;
  final DateTime publishedAt;

  factory PropertyNewsDetail.fromJson(Map<String, dynamic> j) {
    final raw = j['published_at']?.toString() ?? j['created_at']?.toString() ?? '';
    return PropertyNewsDetail(
      id: j['id']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      imageUrl: j['image_url']?.toString() ?? '',
      body: j['body']?.toString() ?? '',
      publishedAt: DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
