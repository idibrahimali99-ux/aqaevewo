import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_session.dart';

final adminSessionProvider = ChangeNotifierProvider<AdminSession>((ref) => AdminSession());
