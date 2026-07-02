import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';

/// تقارير مجمّعة حسب نطاق تاريخي (من السيرفر).
class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  DateTime? _from;
  DateTime? _to;
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day);
    _from = _to!.subtract(const Duration(days: 30));
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    if (_from == null || _to == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(vewoApiClientProvider);
      final data = await api.getJson(
        'admin/reports',
        query: {
          'from': _ymd(_from!),
          'to': _ymd(_to!),
        },
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } on VewoApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر التحميل';
        _loading = false;
      });
    }
  }

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _from = d);
  }

  String _csvEscape(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  Future<void> _exportExcelCsv() async {
    final d = _data;
    if (d == null || _from == null || _to == null) return;
    final from = _ymd(_from!);
    final to = _ymd(_to!);
    final buf = StringBuffer('\uFEFF');
    buf.writeln(
      '${_csvEscape('تقرير vewo')},${_csvEscape('$from → $to')}',
    );
    buf.writeln(
      '${_csvEscape('منشورات جديدة')},${_csvEscape('${d['new_properties'] ?? ''}')}',
    );
    buf.writeln(
      '${_csvEscape('منشورات تم البيع')},${_csvEscape('${d['sold_properties'] ?? ''}')}',
    );
    buf.writeln(
      '${_csvEscape('حسابات جديدة')},${_csvEscape('${d['new_users'] ?? ''}')}',
    );
    buf.writeln();
    buf.writeln('${_csvEscape('الدور')},${_csvEscape('العدد')}');
    final roles = d['new_users_by_role'];
    if (roles is List) {
      for (final e in roles) {
        if (e is Map) {
          buf.writeln(
            '${_csvEscape('${e['role'] ?? ''}')},${_csvEscape('${e['c'] ?? e['C'] ?? ''}')}',
          );
        }
      }
    }
    await SharePlus.instance.share(
      ShareParams(
        text: buf.toString(),
        subject: 'تقرير vewo $from — $to',
      ),
    );
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _to = d);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقارير'),
        actions: [
          if (_data != null)
            IconButton(
              tooltip: 'تنزيل Excel (CSV)',
              icon: const Icon(Icons.download_rounded),
              onPressed: _loading ? null : _exportExcelCsv,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'اختر الفترة',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickFrom,
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text(_from != null ? _ymd(_from!) : 'من'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickTo,
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: Text(_to != null ? _ymd(_to!) : 'إلى'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loading ? null : _load,
                    icon: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.analytics_outlined),
                    label: const Text('عرض التقرير'),
                  ),
                  if (_data != null) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _exportExcelCsv,
                      icon: const Icon(Icons.table_chart_outlined),
                      label: const Text('تنزيل CSV (Excel)'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
          if (_data != null) ...[
            const SizedBox(height: 16),
            _ReportTile(
              icon: Icons.article_outlined,
              title: 'منشورات جديدة في الفترة',
              value: '${_data!['new_properties'] ?? '—'}',
            ),
            const SizedBox(height: 10),
            _ReportTile(
              icon: Icons.sell_outlined,
              title: 'منشورات تم تعليمها كـ بيع في الفترة',
              value: '${_data!['sold_properties'] ?? '—'}',
            ),
            const SizedBox(height: 10),
            _ReportTile(
              icon: Icons.person_add_alt_outlined,
              title: 'حسابات جديدة',
              value: '${_data!['new_users'] ?? '—'}',
            ),
            const SizedBox(height: 16),
            Text(
              'توزيع الحسابات الجديدة حسب الدور',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            ..._roleRows(_data!['new_users_by_role']),
          ],
        ],
      ),
    );
  }

  List<Widget> _roleRows(dynamic raw) {
    if (raw is! List) {
      return const [Text('—')];
    }
    return [
      for (final e in raw)
        if (e is Map)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(child: Text('${e['role'] ?? ''}')),
                Text(
                  '${e['c'] ?? e['C'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
    ];
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(icon, color: scheme.primary),
        title: Text(title),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
    );
  }
}
