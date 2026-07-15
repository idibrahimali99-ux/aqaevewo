import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/user_role.dart';
import 'auth_state.dart';

const _kAuthJson = 'vewo_auth_session_v1';

class AuthSessionStorage {
  AuthSessionStorage._();

  static Future<void> save(SharedPreferences prefs, AuthState state) async {
    if (!state.isAuthenticated || state.apiToken == null) {
      await prefs.remove(_kAuthJson);
      return;
    }
    final map = <String, dynamic>{
      'token': state.apiToken,
      'userId': state.userId,
      'role': switch (state.role) {
        UserRole.office => 'office',
        UserRole.admin => 'admin',
        UserRole.customer => 'customer',
      },
      'displayName': state.displayName,
      'fullName': state.fullName,
      'officeName': state.officeName,
      'officePhotoUrl': state.officePhotoUrl,
      'phone': state.phone,
      'email': state.email,
      'profilePhotoUrl': state.profilePhotoUrl,
      'isMarketer': state.isMarketer,
      'officeApproved': state.officeApproved,
      'postingTrialUnlimited': state.postingTrialUnlimited,
      'postingListingsRemaining': state.postingListingsRemaining,
    };
    await prefs.setString(_kAuthJson, jsonEncode(map));
  }

  static Future<void> clear(SharedPreferences prefs) async {
    await prefs.remove(_kAuthJson);
  }

  /// يُرجع `null` إن لم تكن هناك جلسة مخزّنة أو كانت البيانات ناقصة.
  static AuthState? parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final m = jsonDecode(raw);
      if (m is! Map<String, dynamic>) return null;
      final token = m['token']?.toString() ?? '';
      if (token.length != 64) return null;
      final roleName = m['role']?.toString() ?? 'customer';
      final role = switch (roleName) {
        'office' => UserRole.office,
        'admin' => UserRole.admin,
        _ => UserRole.customer,
      };
      final trial = m['postingTrialUnlimited'];
      final rem = m['postingListingsRemaining'];
      return AuthState(
        isAuthenticated: true,
        role: role,
        displayName: (m['displayName']?.toString() ?? 'مستخدم').trim(),
        fullName: (m['fullName']?.toString() ?? '').trim(),
        officeName: (m['officeName']?.toString() ?? '').trim(),
        officePhotoUrl: (m['officePhotoUrl']?.toString() ?? '').trim(),
        phone: (m['phone']?.toString() ?? '').trim(),
        email: (m['email']?.toString() ?? '').trim(),
        profilePhotoUrl: (m['profilePhotoUrl']?.toString() ?? '').trim(),
        isMarketer: m['isMarketer'] == true || m['isMarketer'] == 1,
        officeApproved: m['officeApproved'] == true || m['officeApproved'] == 1,
        userId: m['userId']?.toString(),
        apiToken: token,
        postingTrialUnlimited: trial == null
            ? null
            : (trial == true || trial == 1),
        postingListingsRemaining: rem == null
            ? null
            : (rem is int ? rem : int.tryParse(rem.toString())),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<AuthState?> load(SharedPreferences prefs) async {
    return parse(prefs.getString(_kAuthJson));
  }
}
