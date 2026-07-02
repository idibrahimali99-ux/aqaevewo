import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../domain/property.dart';

import 'scoped_properties_loader.dart';



final parcelPropertiesProvider = FutureProvider.autoDispose

    .family<List<Property>, String>((ref, parcelId) async {

  return fetchParcelProperties(ref, parcelId);

});

