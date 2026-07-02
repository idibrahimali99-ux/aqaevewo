import 'package:flutter_riverpod/flutter_riverpod.dart';

/// أثناء التسجيل/تسجيل الدخول: مسوّق عقاري يُخزَّن هنا حتى لا نخلط مع `AuthState.role`.
final registrationMarketerProvider = StateProvider<bool>((ref) => false);
