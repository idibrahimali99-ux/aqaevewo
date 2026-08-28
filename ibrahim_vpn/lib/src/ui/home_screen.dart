import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../vpn/models.dart';
import '../vpn/vpn_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final VpnController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final connected = controller.isConnected;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                connected ? const Color(0xFF08251F) : const Color(0xFF101628),
                AppColors.bg,
                AppColors.bg,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                _Header(controller: controller),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                    children: [
                      const SizedBox(height: 6),
                      _ServerCard(controller: controller),
                      const SizedBox(height: 22),
                      _ConnectButton(controller: controller),
                      const SizedBox(height: 10),
                      _StatusCaption(controller: controller),
                      const SizedBox(height: 22),
                      _StatsRow(controller: controller),
                      const SizedBox(height: 16),
                      _LocationCard(controller: controller),
                      const SizedBox(height: 16),
                      _DetailsCard(controller: controller),
                      const SizedBox(height: 16),
                      _OperationsBox(controller: controller),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller});
  final VpnController controller;

  @override
  Widget build(BuildContext context) {
    final connected = controller.isConnected;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [AppColors.gold, Color(0xFFB89020)],
              ),
            ),
            child: const Icon(Icons.shield_outlined, color: Color(0xFF1A1404)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ابراهيم VPN',
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                Text(
                  'حماية احترافية لنفقك الخاص',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.muted,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: connected
                  ? AppColors.teal.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: connected ? AppColors.teal : AppColors.cardBorder,
              ),
            ),
            child: Text(
              connected ? 'محمي' : 'غير محمي',
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: connected ? AppColors.teal : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({required this.controller});
  final VpnController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.server;
    return _Glass(
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(s.flag, style: const TextStyle(fontSize: 30)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.countryAr,
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${s.city} · ${s.protocol} · UDP ${s.port}',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'السيرفر',
                style: GoogleFonts.cairo(fontSize: 11, color: AppColors.muted),
              ),
              Text(
                s.host,
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectButton extends StatelessWidget {
  const _ConnectButton({required this.controller});
  final VpnController controller;

  @override
  Widget build(BuildContext context) {
    final connected = controller.isConnected;
    final busy = controller.isBusy;
    final color = connected
        ? AppColors.teal
        : (busy ? AppColors.gold : const Color(0xFF8EA0BE));

    return Center(
      child: GestureDetector(
        onTap: busy
            ? null
            : () {
                HapticFeedback.mediumImpact();
                controller.toggle();
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          width: 168,
          height: 168,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: connected ? 0.45 : 0.18),
                blurRadius: connected ? 36 : 16,
                spreadRadius: connected ? 4 : 0,
              ),
            ],
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: 0.28),
                const Color(0xFF101828),
              ],
            ),
            border: Border.all(color: color, width: 3),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy && !connected)
                SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: color,
                  ),
                )
              else
                Icon(
                  connected ? Icons.power_settings_new : Icons.power_settings_new,
                  size: 46,
                  color: color,
                ),
              const SizedBox(height: 8),
              Text(
                busy
                    ? (connected ? 'جاري القطع' : 'جاري الاتصال')
                    : (connected ? 'قطع الاتصال' : 'اتصال'),
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCaption extends StatelessWidget {
  const _StatusCaption({required this.controller});
  final VpnController controller;

  @override
  Widget build(BuildContext context) {
    final d = controller.sessionDuration;
    String text;
    switch (controller.state) {
      case VpnUiState.connected:
        text = d == null
            ? 'متصل الآن — كل حركة الإنترنت مشفّرة'
            : 'مدة الجلسة ${formatDuration(d)}';
      case VpnUiState.connecting:
        text = 'يتم إنشاء النفق المشفر...';
      case VpnUiState.disconnecting:
        text = 'يتم إغلاق النفق...';
      case VpnUiState.disconnected:
        text = 'اضغط اتصال لتأمين اتصالك عبر ألمانيا';
    }
    return Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 13),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.controller});
  final VpnController controller;

  @override
  Widget build(BuildContext context) {
    final ping = controller.pingMs;
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.speed_rounded,
            label: 'البنغ',
            value: ping == null ? '—' : '$ping ms',
            color: AppColors.gold,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.download_rounded,
            label: 'تنزيل',
            value: formatRate(controller.downloadBps),
            color: AppColors.teal,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.upload_rounded,
            label: 'رفع',
            value: formatRate(controller.uploadBps),
            color: AppColors.info,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.cairo(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.controller});
  final VpnController controller;

  @override
  Widget build(BuildContext context) {
    final loc = controller.location;
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.public, color: AppColors.teal, size: 18),
              const SizedBox(width: 8),
              Text(
                'الموقع الحالي',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: controller.isBusy
                    ? null
                    : () => controller.refreshLocation(
                          reason: 'تحديث يدوي للموقع',
                        ),
                child: Text(
                  'تحديث',
                  style: GoogleFonts.cairo(color: AppColors.gold),
                ),
              ),
            ],
          ),
          if (loc == null)
            Text(
              'جاري تحديد موقعك العام...',
              style: GoogleFonts.cairo(color: AppColors.muted),
            )
          else ...[
            Text(
              '${loc.flag}  ${loc.country}',
              style: GoogleFonts.cairo(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              loc.locationLine,
              style: GoogleFonts.cairo(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            _kv('عنوان IP', loc.ip),
            _kv('مزود الخدمة', loc.isp.isEmpty ? '—' : loc.isp),
            _kv('التوقيت', loc.timezone.isEmpty ? '—' : loc.timezone),
          ],
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.controller});
  final VpnController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.server;
    final hs = controller.handshakeAt;
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.gold, size: 18),
              const SizedBox(width: 8),
              Text(
                'التفاصيل',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _kv('الدولة', '${s.flag} ${s.countryAr}'),
          _kv('المدينة', s.city),
          _kv('البروتوكول', s.protocol),
          _kv('التشفير', s.cipher),
          _kv('المنفذ', 'UDP ${s.port}'),
          _kv('الحالة', _stateAr(controller.state)),
          _kv('تنزيل تراكمي', formatBytes(controller.rxBytes)),
          _kv('رفع تراكمي', formatBytes(controller.txBytes)),
          _kv(
            'آخر مصافحة',
            hs == null ? '—' : DateFormat('HH:mm:ss').format(hs),
          ),
        ],
      ),
    );
  }
}

class _OperationsBox extends StatelessWidget {
  const _OperationsBox({required this.controller});
  final VpnController controller;

  @override
  Widget build(BuildContext context) {
    final logs = controller.logs;
    return _Glass(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: AppColors.info, size: 18),
                const SizedBox(width: 8),
                Text(
                  'سجل العمليات',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Text(
                  '${logs.length} حركة',
                  style: GoogleFonts.cairo(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 220,
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            decoration: BoxDecoration(
              color: const Color(0xFF070B12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: logs.isEmpty
                ? Center(
                    child: Text(
                      'لا توجد عمليات بعد',
                      style: GoogleFonts.cairo(color: AppColors.muted),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    itemCount: logs.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 10,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    itemBuilder: (context, i) {
                      final e = logs[i];
                      final c = _kindColor(e.kind);
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 7),
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('HH:mm:ss').format(e.time),
                            style: GoogleFonts.robotoMono(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.message,
                              style: GoogleFonts.cairo(
                                fontSize: 12.5,
                                height: 1.35,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: child,
    );
  }
}

Widget _kv(String k, String v) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            k,
            style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            v,
            textAlign: TextAlign.left,
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}

Color _kindColor(LogKind kind) {
  switch (kind) {
    case LogKind.success:
      return AppColors.teal;
    case LogKind.error:
      return AppColors.danger;
    case LogKind.warn:
      return AppColors.warn;
    case LogKind.net:
      return AppColors.info;
    case LogKind.info:
      return AppColors.gold;
  }
}

String _stateAr(VpnUiState state) {
  switch (state) {
    case VpnUiState.connected:
      return 'متصل';
    case VpnUiState.connecting:
      return 'جاري الاتصال';
    case VpnUiState.disconnecting:
      return 'جاري القطع';
    case VpnUiState.disconnected:
      return 'غير متصل';
  }
}
