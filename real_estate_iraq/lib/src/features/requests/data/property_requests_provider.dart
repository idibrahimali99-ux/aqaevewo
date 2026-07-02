import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';

final myPropertyRequestsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final data = await ref
          .read(vewoApiClientProvider)
          .getJson('property-requests');
      final raw = data['items'];
      if (raw is! List) return const [];
      return [
        for (final e in raw)
          if (e is Map<String, dynamic>)
            e
          else if (e is Map)
            Map<String, dynamic>.from(e),
      ];
    });

class PropertyRequestSubmitter {
  const PropertyRequestSubmitter(this.ref);

  final Ref ref;

  Future<({String? error, int? requestNo})> submit(
    Map<String, dynamic> body,
  ) async {
    try {
      final data = await ref
          .read(vewoApiClientProvider)
          .postJson('property-requests', body);
      return (
        error: null,
        requestNo: int.tryParse(data['request_no']?.toString() ?? ''),
      );
    } on VewoApiException catch (e) {
      return (error: e.message, requestNo: null);
    } catch (_) {
      return (error: 'تعذر إرسال الطلب الآن', requestNo: null);
    }
  }
}

final propertyRequestSubmitterProvider = Provider<PropertyRequestSubmitter>(
  (ref) => PropertyRequestSubmitter(ref),
);
