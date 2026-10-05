import 'package:flutter_riverpod/flutter_riverpod.dart';

/// أثناء التسجيل: مسوّق عقاري أو حساب مزرعة، منفصل عن `AuthState.role`.
final registrationMarketerProvider = StateProvider<bool>((ref) => false);

final registrationFarmProvider = StateProvider<bool>((ref) => false);
