import 'package:flutter/material.dart';

/// سجل حركة الأدمن/الموظف تحت المنشور أو الريل.
class AdminActivityBlock extends StatelessWidget {
  const AdminActivityBlock({super.key, required this.raw});

  final dynamic raw;

  @override
  Widget build(BuildContext context) {
    final items = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          items.add(e);
        } else if (e is Map) {
          items.add(Map<String, dynamic>.from(e));
        }
      }
    }
    if (items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'حركة الإدارة',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              for (final a in items.take(6))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    [
                      a['message']?.toString() ?? '',
                      _shortTime(a['created_at']?.toString()),
                    ].where((e) => e.trim().isNotEmpty).join(' · '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 1.35,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _shortTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    final local = d.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.year}/${local.month}/${local.day} $hh:$mm';
  }
}
