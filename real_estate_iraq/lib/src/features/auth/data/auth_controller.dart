import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';
import '../domain/user_role.dart';
import 'auth_session_storage.dart';
import 'auth_state.dart';
import 'registration_marketer_provider.dart';

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => AuthState.signedOut;

  Future<void> hydrateFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final restored = await AuthSessionStorage.load(prefs);
    if (restored == null) return;
    state = restored;
    await refreshPostingFromServer();
  }

  Future<void> _persistCurrentSession() async {
    final snap = state;
    final prefs = await SharedPreferences.getInstance();
    await AuthSessionStorage.save(prefs, snap);
  }

  void setRole(UserRole role) {
    state = state.copyWith(role: role);
  }

  UserRole _roleFromApi(String r) {
    switch (r) {
      case 'office':
        return UserRole.office;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.customer;
    }
  }

  String? _tokenFromResponse(Map<String, dynamic> data) {
    final t = data['token'];
    if (t is String && t.isNotEmpty) return t;
    return null;
  }

  String _profilePhotoFromUser(Map<String, dynamic> u) {
    final p = u['profile_photo_url']?.toString().trim() ?? '';
    if (p.isNotEmpty) return p;
    return u['office_photo_url']?.toString().trim() ?? '';
  }

  String _officeNameFromUser(Map<String, dynamic> u) {
    return u['office_name']?.toString().trim() ?? '';
  }

  String _fullNameFromUser(Map<String, dynamic> u, String fallback) {
    final full = u['full_name']?.toString().trim() ?? '';
    return full.isNotEmpty ? full : fallback.trim();
  }

  String _officePhotoFromUser(Map<String, dynamic> u) {
    final office = u['office_photo_url']?.toString().trim() ?? '';
    if (office.isNotEmpty) return office;
    return u['profile_photo_url']?.toString().trim() ?? '';
  }

  /// يُرجع قيماً `null` إن لم تُرسل من الـ API (قبل تفعيل أعمدة الباقة في قاعدة البيانات).
  ({bool? trial, int? rem}) _postingQuotaFromUser(Map<String, dynamic> u) {
    if (!u.containsKey('posting_trial_unlimited')) {
      return (trial: null, rem: null);
    }
    final trial =
        u['posting_trial_unlimited'] == true ||
        u['posting_trial_unlimited'] == 1;
    final r = u['posting_listings_remaining'];
    final rem = r == null
        ? null
        : (r is int ? r : (r is num ? r.toInt() : int.tryParse(r.toString())));
    return (trial: trial, rem: rem);
  }

  /// يحدّث رصيد المنشورات من `GET users/me` (للمكاتب بعد تغيير الباقة من الإدارة).
  Future<void> refreshPostingFromServer() async {
    if (!state.isAuthenticated || state.apiToken == null) return;
    if (state.role != UserRole.office) return;
    final api = ref.read(vewoApiClientProvider);
    try {
      final data = await api.getJson('users/me');
      final u = data['user'];
      if (u is! Map<String, dynamic>) return;
      final pq = _postingQuotaFromUser(u);
      final officeName = _officeNameFromUser(u);
      final fullName = _fullNameFromUser(u, state.fullName);
      state = state.copyWith(
        displayName: state.role == UserRole.office && officeName.isNotEmpty
            ? officeName
            : fullName,
        fullName: fullName,
        officeName: officeName,
        officePhotoUrl: _officePhotoFromUser(u),
        profilePhotoUrl: _profilePhotoFromUser(u),
        postingTrialUnlimited: pq.trial,
        postingListingsRemaining: pq.rem,
      );
    } catch (_) {}
  }

  /// يُرجع `null` عند النجاح، أو نص الخطأ.
  Future<String?> signIn({
    required String login,
    required String password,
  }) async {
    final loginValue = login.trim();
    final api = VewoApiClient();
    try {
      final data = await api.postJson('auth/login', {
        'login': loginValue,
        'password': password,
      });
      final u = data['user'] as Map<String, dynamic>;
      final role = _roleFromApi(u['role'] as String? ?? 'customer');
      final officeApproved =
          u['office_approved'] == true || u['office_approved'] == 1;
      final pq = _postingQuotaFromUser(u);
      final fullName = _fullNameFromUser(u, loginValue);
      final officeName = _officeNameFromUser(u);
      state = AuthState(
        isAuthenticated: true,
        role: role,
        displayName: role == UserRole.office && officeName.isNotEmpty
            ? officeName
            : fullName,
        fullName: fullName,
        officeName: officeName,
        officePhotoUrl: _officePhotoFromUser(u),
        phone: (u['phone'] as String?)?.trim() ?? '',
        email: (u['email'] as String?)?.trim() ?? '',
        profilePhotoUrl: _profilePhotoFromUser(u),
        officeApproved: role == UserRole.office ? officeApproved : true,
        userId: u['id']?.toString(),
        apiToken: _tokenFromResponse(data),
        postingTrialUnlimited: pq.trial,
        postingListingsRemaining: pq.rem,
      );
      await _persistCurrentSession();
      return null;
    } on VewoApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'تعذر الاتصال بالسيرفر. تحقق من إعداد VEWO_API_BASE والشبكة.';
    } finally {
      api.close();
    }
  }

  /// يُرجع `null` عند النجاح، أو نص الخطأ.
  Future<String?> register({
    required String fullName,
    required String iraqiPhone,
    required String email,
    required String password,
    String officeName = '',
    String officeAddress = '',
    String officeLicenseNo = '',
    String officePhotoUrl = '',
    String profilePhotoUrl = '',
    bool isMarketer = false,
    double? officeLat,
    double? officeLng,
  }) async {
    final phone = iraqiPhone.trim();
    final roleName = switch (state.role) {
      UserRole.office => 'office',
      UserRole.admin => 'customer',
      UserRole.customer => 'customer',
    };
    final api = VewoApiClient();
    try {
      final body = <String, dynamic>{
        'full_name': fullName.trim(),
        'phone': phone,
        'email': email.trim(),
        'password': password,
        'role': roleName,
      };
      if (roleName == 'office') {
        body['office_name'] = officeName.trim();
        body['office_address'] = officeAddress.trim();
        body['office_license_no'] = officeLicenseNo.trim();
        body['office_photo_url'] = officePhotoUrl.trim();
        if (isMarketer) {
          body['is_marketer'] = 1;
        }
      }
      final pp = profilePhotoUrl.trim();
      if (pp.isNotEmpty) {
        body['profile_photo_url'] = pp;
      }
      if (roleName == 'office' && officeLat != null && officeLng != null) {
        body['office_lat'] = officeLat;
        body['office_lng'] = officeLng;
      }
      final data = await api.postJson('auth/register', body);
      final u = data['user'] as Map<String, dynamic>;
      final role = _roleFromApi(u['role'] as String? ?? roleName);
      final officeApproved =
          u['office_approved'] == true || u['office_approved'] == 1;
      final apiOfficeName = (u['office_name'] as String?)?.trim() ?? '';
      final fullNameShown = _fullNameFromUser(u, fullName);
      final shownName = role == UserRole.office && apiOfficeName.isNotEmpty
          ? apiOfficeName
          : fullNameShown;
      final pq = _postingQuotaFromUser(u);
      state = AuthState(
        isAuthenticated: true,
        role: role,
        displayName: shownName,
        fullName: fullNameShown,
        officeName: apiOfficeName,
        officePhotoUrl: _officePhotoFromUser(u),
        phone: (u['phone'] as String?)?.trim() ?? phone,
        email: (u['email'] as String?)?.trim() ?? email.trim(),
        profilePhotoUrl: _profilePhotoFromUser(u),
        officeApproved: role == UserRole.office ? officeApproved : true,
        userId: u['id']?.toString(),
        apiToken: _tokenFromResponse(data),
        postingTrialUnlimited: pq.trial,
        postingListingsRemaining: pq.rem,
      );
      await _persistCurrentSession();
      return null;
    } on VewoApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'تعذر الاتصال بالسيرفر. تحقق من إعداد VEWO_API_BASE والشبكة.';
    } finally {
      api.close();
    }
  }

  Future<void> signOut() async {
    ref.read(registrationMarketerProvider.notifier).state = false;
    final prefs = await SharedPreferences.getInstance();
    await AuthSessionStorage.clear(prefs);
    state = AuthState(
      isAuthenticated: false,
      role: state.role,
      displayName: 'زائر',
      phone: '',
      email: '',
      fullName: '',
      officeName: '',
      officePhotoUrl: '',
      officeApproved: false,
      userId: null,
      apiToken: null,
      profilePhotoUrl: '',
      postingTrialUnlimited: null,
      postingListingsRemaining: null,
    );
  }

  void setOfficeApproved(bool approved) {
    state = state.copyWith(officeApproved: approved);
  }

  Future<String?> updateProfile({
    required String fullName,
    String? profilePhotoUrl,
    String? officeName,
  }) async {
    if (!state.isAuthenticated) return 'سجّل الدخول أولاً';
    final name = fullName.trim();
    if (name.length < 2) return 'الاسم قصير جداً';
    final api = ref.read(vewoApiClientProvider);
    try {
      final body = <String, dynamic>{'full_name': name};
      final office = officeName?.trim();
      if (state.role == UserRole.office &&
          office != null &&
          office.isNotEmpty) {
        body['office_name'] = office;
      }
      final photo = profilePhotoUrl?.trim();
      if (photo != null && photo.isNotEmpty) {
        body['profile_photo_url'] = photo;
        if (state.role == UserRole.office) {
          body['office_photo_url'] = photo;
        }
      }
      final data = await api.postJson('users/update-profile', body);
      final u = data['user'];
      if (u is Map<String, dynamic>) {
        final apiFullName = _fullNameFromUser(u, name);
        final apiOfficeName = _officeNameFromUser(u);
        state = state.copyWith(
          displayName: state.role == UserRole.office && apiOfficeName.isNotEmpty
              ? apiOfficeName
              : apiFullName,
          fullName: apiFullName,
          officeName: apiOfficeName,
          officePhotoUrl: _officePhotoFromUser(u),
          phone: u['phone']?.toString().trim() ?? state.phone,
          email: u['email']?.toString().trim() ?? state.email,
          profilePhotoUrl: _profilePhotoFromUser(u),
        );
      } else {
        state = state.copyWith(
          displayName: name,
          fullName: name,
          officeName: office ?? state.officeName,
          officePhotoUrl: photo ?? state.officePhotoUrl,
          profilePhotoUrl: photo ?? state.profilePhotoUrl,
        );
      }
      await _persistCurrentSession();
      return null;
    } on VewoApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'تعذر تحديث الحساب الآن';
    }
  }
}
