import '../domain/user_role.dart';

class AuthState {
  const AuthState({
    required this.isAuthenticated,
    required this.role,
    required this.displayName,
    required this.phone,
    required this.email,
    required this.officeApproved,
    this.fullName = '',
    this.officeName = '',
    this.officePhotoUrl = '',
    this.userId,
    this.apiToken,
    this.profilePhotoUrl = '',
    this.isMarketer = false,
    this.postingTrialUnlimited,
    this.postingListingsRemaining,
  });

  final bool isAuthenticated;
  final UserRole role;
  final String displayName;
  final String phone;
  final String email;
  final bool officeApproved;
  final String fullName;
  final String officeName;
  final String officePhotoUrl;

  /// معرّف المستخدم من الـAPI (للمحادثات وغيرها).
  final String? userId;

  /// رمز الجلسة لـ `Authorization: Bearer` بعد تسجيل الدخول أو التسجيل.
  final String? apiToken;
  final String profilePhotoUrl;
  final bool isMarketer;

  /// `null` إذا لم يُرجع الخادم حقول الباقة بعد (قبل تنفيذ الباتش).
  final bool? postingTrialUnlimited;

  /// المتبقي عند إيقاف التجريبي؛ يُستخدم مع [postingTrialUnlimited] == false.
  final int? postingListingsRemaining;

  AuthState copyWith({
    bool? isAuthenticated,
    UserRole? role,
    String? displayName,
    String? phone,
    String? email,
    bool? officeApproved,
    String? fullName,
    String? officeName,
    String? officePhotoUrl,
    String? userId,
    String? apiToken,
    String? profilePhotoUrl,
    bool? isMarketer,
    bool? postingTrialUnlimited,
    int? postingListingsRemaining,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      officeApproved: officeApproved ?? this.officeApproved,
      fullName: fullName ?? this.fullName,
      officeName: officeName ?? this.officeName,
      officePhotoUrl: officePhotoUrl ?? this.officePhotoUrl,
      userId: userId ?? this.userId,
      apiToken: apiToken ?? this.apiToken,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      isMarketer: isMarketer ?? this.isMarketer,
      postingTrialUnlimited:
          postingTrialUnlimited ?? this.postingTrialUnlimited,
      postingListingsRemaining:
          postingListingsRemaining ?? this.postingListingsRemaining,
    );
  }

  static const signedOut = AuthState(
    isAuthenticated: false,
    role: UserRole.customer,
    displayName: 'زائر',
    phone: '',
    email: '',
    officeApproved: false,
    fullName: '',
    officeName: '',
    officePhotoUrl: '',
    userId: null,
    apiToken: null,
    profilePhotoUrl: '',
    isMarketer: false,
    postingTrialUnlimited: null,
    postingListingsRemaining: null,
  );
}
