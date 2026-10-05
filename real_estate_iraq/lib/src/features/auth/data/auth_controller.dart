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

  bool _isMarketerFromUser(Map<String, dynamic> u) {
    final raw = u['is_marketer'];
    return raw == true || raw == 1 || raw?.toString() == '1';
  }

  bool _isFarmFromUser(Map<String, dynamic> u) {
    final raw = u['is_farm'];
    return raw == true || raw == 1 || raw?.toString() == '1';
  }

  String _displayFromUser({
    required UserRole role,
    required bool isMarketer,
    required bool isFarm,
    required String officeName,
    required String farmName,
    required String fullName,
  }) {
    if (isFarm && farmName.isNotEmpty) return farmName;
    if (role == UserRole.office && !isMarketer && officeName.isNotEmpty) {
      return officeName;
    }
    return fullName;
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
      final isMarketer = _isMarketerFromUser(u);
      final isFarm = _isFarmFromUser(u);
      final farmName = u['farm_name']?.toString().trim() ?? '';
      final displayName = _displayFromUser(
        role: state.role,
        isMarketer: isMarketer,
        isFarm: isFarm,
        officeName: officeName,
        farmName: farmName,
        fullName: fullName,
      );
      final officePhoto = _officePhotoFromUser(u);
      final profilePhoto = _profilePhotoFromUser(u);
      if (state.displayName == displayName &&
          state.fullName == fullName &&
          state.officeName == officeName &&
          state.officePhotoUrl == officePhoto &&
          state.profilePhotoUrl == profilePhoto &&
          state.isMarketer == isMarketer &&
          state.isFarm == isFarm &&
          state.farmName == farmName &&
          state.postingTrialUnlimited == pq.trial &&
          state.postingListingsRemaining == pq.rem) {
        return;
      }
      state = state.copyWith(
        displayName: displayName,
        fullName: fullName,
        officeName: officeName,
        officePhotoUrl: officePhoto,
        profilePhotoUrl: profilePhoto,
        isMarketer: isMarketer,
        isFarm: isFarm,
        farmId: u['farm_id']?.toString() ?? '',
        farmName: farmName,
        farmPublicCode: u['farm_public_code']?.toString() ?? '',
        farmStatus: u['farm_status']?.toString() ?? '',
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
      final isMarketer = _isMarketerFromUser(u);
      final isFarm = _isFarmFromUser(u);
      final farmName = u['farm_name']?.toString().trim() ?? '';
      state = AuthState(
        isAuthenticated: true,
        role: role,
        displayName: _displayFromUser(
          role: role,
          isMarketer: isMarketer,
          isFarm: isFarm,
          officeName: officeName,
          farmName: farmName,
          fullName: fullName,
        ),
        fullName: fullName,
        officeName: officeName,
        officePhotoUrl: _officePhotoFromUser(u),
        phone: (u['phone'] as String?)?.trim() ?? '',
        email: (u['email'] as String?)?.trim() ?? '',
        profilePhotoUrl: _profilePhotoFromUser(u),
        isMarketer: isMarketer,
        isFarm: isFarm,
        farmId: u['farm_id']?.toString() ?? '',
        farmName: farmName,
        farmPublicCode: u['farm_public_code']?.toString() ?? '',
        farmStatus: u['farm_status']?.toString() ?? '',
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
      return 'تعذر الاتصال بالسيرفر. تحقق من الشبكة وحاول مجدداً.';
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
    bool isFarm = false,
    double? officeLat,
    double? officeLng,
    List<String> farmImageUrls = const [],
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
        if (isFarm) {
          body['is_farm'] = 1;
          body['account_kind'] = 'farm';
          body['farm_name'] = officeName.trim();
          body['images'] = farmImageUrls;
          if (farmImageUrls.isNotEmpty) {
            body['cover_url'] = farmImageUrls.first;
            body['office_photo_url'] = farmImageUrls.first;
          }
        } else if (isMarketer) {
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
      final isMarketerAccount = _isMarketerFromUser(u);
      final accountIsFarm = _isFarmFromUser(u);
      final farmName = u['farm_name']?.toString().trim() ?? '';
      final shownName = _displayFromUser(
        role: role,
        isMarketer: isMarketerAccount,
        isFarm: accountIsFarm,
        officeName: apiOfficeName,
        farmName: farmName,
        fullName: fullNameShown,
      );
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
        isMarketer: isMarketerAccount,
        isFarm: accountIsFarm,
        farmId: u['farm_id']?.toString() ?? '',
        farmName: farmName,
        farmPublicCode: u['farm_public_code']?.toString() ?? '',
        farmStatus: u['farm_status']?.toString() ?? '',
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
      return 'تعذر الاتصال بالسيرفر. تحقق من الشبكة وحاول مجدداً.';
    } finally {
      api.close();
    }
  }

  Future<void> signOut() async {
    ref.read(registrationMarketerProvider.notifier).state = false;
    ref.read(registrationFarmProvider.notifier).state = false;
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
      isMarketer: false,
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
        final isMarketer = _isMarketerFromUser(u);
        final isFarm = _isFarmFromUser(u);
        final farmName = u['farm_name']?.toString().trim() ?? '';
        state = state.copyWith(
          displayName: _displayFromUser(
            role: state.role,
            isMarketer: isMarketer,
            isFarm: isFarm,
            officeName: apiOfficeName,
            farmName: farmName,
            fullName: apiFullName,
          ),
          fullName: apiFullName,
          officeName: apiOfficeName,
          officePhotoUrl: _officePhotoFromUser(u),
          phone: u['phone']?.toString().trim() ?? state.phone,
          email: u['email']?.toString().trim() ?? state.email,
          profilePhotoUrl: _profilePhotoFromUser(u),
          isMarketer: isMarketer,
          isFarm: isFarm,
          farmId: u['farm_id']?.toString() ?? state.farmId,
          farmName: farmName.isNotEmpty ? farmName : state.farmName,
          farmPublicCode: u['farm_public_code']?.toString() ?? state.farmPublicCode,
          farmStatus: u['farm_status']?.toString() ?? state.farmStatus,
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

  /// حذف الحساب نهائياً (Apple Guideline 5.1.1). يتطلب كلمة مرور الحساب.
  Future<String?> deleteAccount({required String password}) async {
    if (!state.isAuthenticated) return 'سجّل الدخول أولاً';
    if (state.role == UserRole.admin) {
      return 'حساب المسؤول لا يُحذف من التطبيق';
    }
    final pw = password.trim();
    if (pw.isEmpty) return 'أدخل كلمة مرور الحساب';
    final api = ref.read(vewoApiClientProvider);
    try {
      await api.postJson('users/delete-account', {
        'confirm': 'DELETE',
        'password': pw,
      });
      await signOut();
      return null;
    } on VewoApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'تعذر حذف الحساب. تحقق من الشبكة وحاول مجدداً.';
    }
  }
}
