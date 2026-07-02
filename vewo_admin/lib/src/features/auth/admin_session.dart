import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// جلسة المسؤول بعد نجاح `auth/admin/login`.
class AdminSession extends ChangeNotifier {
  String? userId;
  String? fullName;
  String? phone;

  /// `admin` أو `staff` — يُستخرج من `user.role` عند تسجيل الدخول.
  String? role;

  List<String> staffPermissions = const [];

  /// يُرجَع من `auth/admin/login` لاستدعاءات `admin/promotions`.
  String? adminApiToken;

  /// يعتمد على **رمز الأدمن** (Bearer) لأن الـAPI لا يقبل إلا الرمز؛
  /// `userId` قد يكون فارغاً بعد استعادة قديمة من التخزين.
  bool get isAuthenticated =>
      adminApiToken != null && adminApiToken!.trim().isNotEmpty;

  void setFromApi(Map<String, dynamic> user) {
    userId = user['id']?.toString();
    fullName = user['full_name']?.toString();
    phone = user['phone']?.toString();
    role = user['role']?.toString();
    staffPermissions = _parsePermissions(user['staff_permissions']);
    notifyListeners();
  }

  /// استجابة تسجيل الدخول كاملة (user + token).
  Future<void> applyLoginResponse(Map<String, dynamic> data) async {
    final u = data['user'] as Map<String, dynamic>?;
    if (u != null) {
      userId = u['id']?.toString();
      fullName = u['full_name']?.toString();
      phone = u['phone']?.toString();
      role = u['role']?.toString();
      staffPermissions = _parsePermissions(u['staff_permissions']);
    }
    adminApiToken = data['token']?.toString();
    notifyListeners();
    await _persist();
  }

  Future<void> restoreFromPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      final token = p.getString(_kToken);
      if (token == null || token.isEmpty) return;
      userId = p.getString(_kUserId);
      fullName = p.getString(_kFullName);
      phone = p.getString(_kPhone);
      role = p.getString(_kRole);
      staffPermissions = p.getStringList(_kPermissions) ?? const [];
      adminApiToken = token;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (adminApiToken == null || adminApiToken!.trim().isEmpty) {
        await p.remove(_kToken);
        await p.remove(_kUserId);
        await p.remove(_kFullName);
        await p.remove(_kPhone);
        await p.remove(_kRole);
        return;
      }
      await p.setString(_kToken, adminApiToken!);
      if (userId != null && userId!.isNotEmpty) {
        await p.setString(_kUserId, userId!);
      } else {
        await p.remove(_kUserId);
      }
      if (fullName != null) await p.setString(_kFullName, fullName!);
      if (phone != null) await p.setString(_kPhone, phone!);
      if (role != null && role!.isNotEmpty) {
        await p.setString(_kRole, role!);
      } else {
        await p.remove(_kRole);
      }
      await p.setStringList(_kPermissions, staffPermissions);
    } catch (_) {}
  }

  Future<void> signOut() async {
    userId = null;
    fullName = null;
    phone = null;
    role = null;
    staffPermissions = const [];
    adminApiToken = null;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_kToken);
      await p.remove(_kUserId);
      await p.remove(_kFullName);
      await p.remove(_kPhone);
      await p.remove(_kRole);
      await p.remove(_kPermissions);
    } catch (_) {}
  }

  bool canAccess(String permission) {
    if (role == 'admin') return true;
    if (role != 'staff') return false;
    return staffPermissions.contains(permission);
  }

  List<String> _parsePermissions(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  static const _kToken = 'vewo_admin_token';
  static const _kUserId = 'vewo_admin_user_id';
  static const _kFullName = 'vewo_admin_full_name';
  static const _kPhone = 'vewo_admin_phone';
  static const _kRole = 'vewo_admin_role';
  static const _kPermissions = 'vewo_admin_staff_permissions';
}
