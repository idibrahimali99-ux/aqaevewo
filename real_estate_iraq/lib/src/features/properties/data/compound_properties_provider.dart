import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../domain/property.dart';

import 'scoped_properties_loader.dart';



final compoundPropertiesProvider = FutureProvider.autoDispose

    .family<List<Property>, String>((ref, compoundId) async {

  return fetchCompoundProperties(ref, compoundId);

});

final compoundPropertiesByTitleProvider = FutureProvider.autoDispose

    .family<List<Property>, ({String compoundId, String title})>((ref, scope) async {

  return fetchCompoundProperties(
    ref,
    scope.compoundId,
    fallbackCompoundName: scope.title,
  );

});

