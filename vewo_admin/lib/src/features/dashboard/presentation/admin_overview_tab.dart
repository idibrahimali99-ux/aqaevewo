import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';
import '../../../core/theme/admin_theme.dart';
import '../../auth/auth_providers.dart';
import '../../reports/presentation/admin_reports_screen.dart';

class AdminOverviewTab extends ConsumerStatefulWidget {
  const AdminOverviewTab({super.key, required this.onOpenSection});

  final ValueChanged<int> onOpenSection;

  @override
  ConsumerState<AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends ConsumerState<AdminOverviewTab> {
  int? _pendingProps;
  int? _pendingOffices;
  int? _activeUsers;
  int? _activeCustomers;
  int? _activeOffices;
  int? _activeStaff;
  int? _activeAdmins;
  int? _threads;
  int? _unreadThreads;
  String? _error;
  int? _pendingReels;
  int? _approvedReels;
  int? _totalPropertyViews;
  int? _totalReelViews;
  Map<String, dynamic>? _topProperty;
  Map<String, dynamic>? _topReel;
  List<Map<String, dynamic>> _urgentSaleItems = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(vewoApiClientProvider);
      final data = await api.getJson('admin/stats');
      if (!mounted) return;
      setState(() {
        _pendingProps = (data['pending_properties'] as num?)?.toInt();
        _pendingOffices = (data['pending_offices'] as num?)?.toInt();
        _activeUsers = (data['active_users'] as num?)?.toInt();
        _activeCustomers = (data['active_customers'] as num?)?.toInt();
        _activeOffices = (data['active_offices'] as num?)?.toInt();
        _activeStaff = (data['active_staff'] as num?)?.toInt();
        _activeAdmins = (data['active_admins'] as num?)?.toInt();
        _threads = (data['chat_threads'] as num?)?.toInt();
        _unreadThreads = (data['chat_unread_threads'] as num?)?.toInt();
        _pendingReels = (data['pending_reels'] as num?)?.toInt();
        _approvedReels = (data['approved_reels'] as num?)?.toInt();
        _totalPropertyViews = (data['total_property_views'] as num?)?.toInt();
        _totalReelViews = (data['total_reel_views'] as num?)?.toInt();
        final tp = data['top_property'];
        _topProperty = tp is Map<String, dynamic>
            ? tp
            : tp is Map
            ? Map<String, dynamic>.from(tp)
            : null;
        final tr = data['top_reel'];
        _topReel = tr is Map<String, dynamic>
            ? tr
            : tr is Map
            ? Map<String, dynamic>.from(tr)
            : null;
        final urgentRaw = data['urgent_sale_items'];
        _urgentSaleItems = urgentRaw is List
            ? urgentRaw
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
            : const [];
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
        _error = 'تعذر تحميل الإحصاءات';
        _loading = false;
      });
    }
  }

  String _v(int? n) => n == null ? '—' : '$n';

  Future<void> _cancelUrgentSale(String id) async {
    try {
      final api = ref.read(vewoApiClientProvider);
      await api.postJson('admin/properties', {
        'id': id,
        'action': 'cancel_urgent_sale',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إلغاء البيع العاجل')));
      await _load();
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(adminSessionProvider);
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'مرحباً، ${session.fullName ?? 'المسؤول'}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              tooltip: 'تحديث',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: scheme.error)),
        ],
        const SizedBox(height: 10),
        Text(
          'لوحة مرتبة لمتابعة النشاط، الموافقات، المحادثات، وحسابات الفريق.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        _OverviewGrid(
          children: [
            _StatTile(
              icon: Icons.apartment_rounded,
              title: 'منشورات بانتظار المراجعة',
              value: _loading ? '…' : _v(_pendingProps),
              subtitle: 'قسم المنشورات',
              onTap: () => widget.onOpenSection(7),
            ),
            _StatTile(
              icon: Icons.storefront_rounded,
              title: 'مكاتب بانتظار الموافقة',
              value: _loading ? '…' : _v(_pendingOffices),
              subtitle: 'قسم المكاتب',
              onTap: () => widget.onOpenSection(3),
            ),
            _StatTile(
              icon: Icons.people_outline_rounded,
              title: 'مستخدمون نشطون',
              value: _loading ? '…' : _v(_activeUsers),
              subtitle: 'قسم المستخدمين',
              onTap: () => widget.onOpenSection(11),
            ),
            _StatTile(
              icon: Icons.person_outline_rounded,
              title: 'حسابات شخصية',
              value: _loading ? '…' : _v(_activeCustomers),
              subtitle: 'قسم المستخدمين',
              onTap: () => widget.onOpenSection(11),
            ),
            _StatTile(
              icon: Icons.store_mall_directory_outlined,
              title: 'مكاتب نشطة',
              value: _loading ? '…' : _v(_activeOffices),
              subtitle: 'قسم المكاتب',
              onTap: () => widget.onOpenSection(3),
            ),
            _StatTile(
              icon: Icons.badge_outlined,
              title: 'موظفو لوحة',
              value: _loading ? '…' : _v(_activeStaff),
              subtitle: 'قسم المستخدمين',
              onTap: () => widget.onOpenSection(11),
            ),
            _StatTile(
              icon: Icons.admin_panel_settings_outlined,
              title: 'أدمن رئيسي',
              value: _loading ? '…' : _v(_activeAdmins),
              subtitle: 'قسم المستخدمين',
              onTap: () => widget.onOpenSection(11),
            ),
            _StatTile(
              icon: Icons.forum_outlined,
              title: 'محادثات',
              value: _loading ? '…' : _v(_threads),
              subtitle: 'قسم المحادثات',
              onTap: () => widget.onOpenSection(10),
            ),
            _StatTile(
              icon: Icons.mark_chat_unread_outlined,
              title: 'محادثات غير مقروءة',
              value: _loading ? '…' : _v(_unreadThreads),
              subtitle: 'تحتاج متابعة',
              onTap: () => widget.onOpenSection(10),
            ),
            _StatTile(
              icon: Icons.video_collection_outlined,
              title: 'ريلز بانتظار المراجعة',
              value: _loading ? '…' : _v(_pendingReels),
              subtitle: 'قسم الريلز',
              onTap: () => widget.onOpenSection(8),
            ),
            _StatTile(
              icon: Icons.verified_outlined,
              title: 'ريلز منشورة',
              value: _loading ? '…' : _v(_approvedReels),
              subtitle: 'معتمدة في التطبيق',
              onTap: () => widget.onOpenSection(8),
            ),
            _StatTile(
              icon: Icons.visibility_outlined,
              title: 'مشاهدات المنشورات',
              value: _loading ? '…' : _v(_totalPropertyViews),
              subtitle: 'قسم المنشورات',
              onTap: () => widget.onOpenSection(7),
            ),
            _StatTile(
              icon: Icons.play_circle_outline_rounded,
              title: 'مشاهدات الريلز',
              value: _loading ? '…' : _v(_totalReelViews),
              subtitle: 'قسم الريلز',
              onTap: () => widget.onOpenSection(8),
            ),
            _StatTile(
              icon: Icons.local_fire_department_rounded,
              title: 'بيع عاجل نشط',
              value: _loading ? '…' : '${_urgentSaleItems.length}',
              subtitle: 'قائمة البيع العاجل',
              onTap: () {},
            ),
          ],
        ),
        if (_urgentSaleItems.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'البيع العاجل النشط',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          ..._urgentSaleItems.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _UrgentSaleAdminCard(
                row: row,
                onCancel: () => _cancelUrgentSale(row['id']?.toString() ?? ''),
              ),
            ),
          ),
        ],
        if (_topProperty != null) ...[
          const SizedBox(height: 16),
          Text(
            'أعلى منشور (مشاهدات)',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          _TopPropertyCard(row: _topProperty!),
        ],
        if (_topReel != null) ...[
          const SizedBox(height: 16),
          Text(
            'أعلى ريل (مشاهدات + تفاعل)',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          _TopReelCard(row: _topReel!),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const AdminReportsScreen(),
              ),
            ),
            icon: const Icon(Icons.analytics_outlined),
            label: const Text('تقارير مفصّلة'),
          ),
        ),
      ],
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  const _OverviewGrid({required this.children});

  final List<Widget> children;

  static const int _columns = 3;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gap = width >= 960
            ? 20.0
            : width >= 600
            ? 14.0
            : 10.0;
        final itemWidth = (width - (gap * (_columns - 1))) / _columns;
        const tileHeightFactor = 1.48;
        final tileHeight = itemWidth * tileHeightFactor;
        final rows = (children.length + _columns - 1) ~/ _columns;
        final gridHeight = (tileHeight * rows) + (gap * (rows - 1));

        return SizedBox(
          height: gridHeight,
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _columns,
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
              childAspectRatio: itemWidth / tileHeight,
            ),
            physics: const NeverScrollableScrollPhysics(),
            itemCount: children.length,
            itemBuilder: (context, index) => children[index],
          ),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? scheme.surface : AdminTheme.surfaceLight;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: isDark
              ? scheme.outline.withValues(alpha: 0.35)
              : AdminTheme.border.withValues(alpha: 0.85),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(19),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AdminTheme.brandPrimary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: AdminTheme.brandPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AdminTheme.brandPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AdminTheme.textPrimary,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                    color: isDark ? scheme.onSurface : AdminTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.15,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopPropertyCard extends StatelessWidget {
  const _TopPropertyCard({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = row['title']?.toString() ?? '';
    final views = row['views'];
    final pub = row['property_public_no']?.toString() ?? '';
    return Card(
      elevation: 1.2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: scheme.primaryContainer.withValues(alpha: 0.6),
              child: Icon(
                Icons.apartment_rounded,
                color: scheme.primary,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pub.isNotEmpty ? 'منشور #$pub' : 'منشور',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'مشاهدات: $views',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UrgentSaleAdminCard extends StatelessWidget {
  const _UrgentSaleAdminCard({required this.row, required this.onCancel});

  final Map<String, dynamic> row;
  final VoidCallback onCancel;

  String _remainingText() {
    final raw = row['urgent_sale_expires_at']?.toString() ?? '';
    final end = DateTime.tryParse(raw)?.toLocal();
    if (end == null) return 'بدون تاريخ انتهاء';
    final diff = end.difference(DateTime.now());
    if (diff.isNegative) return 'منتهي';
    final days = diff.inDays;
    final hours = diff.inHours.remainder(24);
    final minutes = diff.inMinutes.remainder(60);
    if (days > 0) return 'ينتهي بعد $days يوم و $hours ساعة';
    if (hours > 0) return 'ينتهي بعد $hours ساعة و $minutes دقيقة';
    return 'ينتهي بعد $minutes دقيقة';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = row['title']?.toString().trim() ?? '';
    final pub = row['property_public_no']?.toString().trim() ?? '';
    final thumb = row['thumb_url']?.toString().trim() ?? '';
    final days = row['urgent_sale_days']?.toString() ?? '';
    return Card(
      elevation: 1.2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: thumb.isNotEmpty
                  ? Image.network(
                      thumb,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _UrgentThumbFallback(color: scheme.primary),
                    )
                  : _UrgentThumbFallback(color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pub.isNotEmpty ? 'منشور #$pub' : 'منشور عاجل',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title.isNotEmpty ? title : 'بدون عنوان',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  StreamBuilder<int>(
                    stream: Stream.periodic(
                      const Duration(minutes: 1),
                      (i) => i,
                    ),
                    builder: (context, _) {
                      final remainingText = _remainingText();
                      return Text(
                        days.isNotEmpty && days != '0'
                            ? '$remainingText • مدة $days يوم'
                            : remainingText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: onCancel,
              icon: const Icon(Icons.close_rounded),
              label: const Text('إلغاء'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UrgentThumbFallback extends StatelessWidget {
  const _UrgentThumbFallback({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      color: color.withValues(alpha: 0.12),
      child: Icon(Icons.local_fire_department_rounded, color: color),
    );
  }
}

class _TopReelCard extends StatelessWidget {
  const _TopReelCard({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cap = row['caption']?.toString() ?? '';
    final pub = row['reel_public_no']?.toString() ?? '';
    final vc = row['view_count'];
    final syn = row['synthetic_likes'];
    final rl = row['real_likes'];
    return Card(
      elevation: 1.2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: scheme.secondaryContainer.withValues(
                alpha: 0.65,
              ),
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: scheme.primary,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pub.isNotEmpty ? 'ريل #$pub' : 'ريل',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cap.isNotEmpty ? cap : '—',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'مشاهدات: $vc • لايكات: ${rl ?? 0} + تركيبي $syn',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
