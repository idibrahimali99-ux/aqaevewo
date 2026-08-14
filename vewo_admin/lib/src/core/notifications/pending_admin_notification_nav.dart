/// طابور تنقّل من إشعار أدمن — يُنفَّذ بعد جاهزية الكونسول.
class PendingAdminNotificationNav {
  PendingAdminNotificationNav._();

  static Map<String, dynamic>? _pending;

  static void store(Map<String, dynamic> data) {
    if (data.isEmpty) return;
    _pending = Map<String, dynamic>.from(data);
  }

  static Map<String, dynamic>? take() {
    final p = _pending;
    _pending = null;
    return p;
  }

  static void clear() => _pending = null;
}
