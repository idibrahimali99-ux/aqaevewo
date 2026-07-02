import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../../core/media/vewo_image_watermark_burn.dart';

import 'package:vewo_shared/vewo_shared.dart' show Iraq;
import '../../../core/widgets/app_brand_mark.dart';
import '../../../core/governorates/governorates_provider.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/widgets/local_video_preview.dart';
import '../../../core/widgets/map_location_picker_sheet.dart';
import '../../auth/data/auth_controller.dart';
import '../../auth/domain/user_role.dart';
import 'posting_quota_dialog.dart';
import '../data/properties_providers.dart';
import '../domain/property_category.dart';
import '../domain/property_segment.dart';
import '../../offices/data/offices_providers.dart';
import '../../../core/utils/gov_name_match.dart';

class AddPropertyScreen extends ConsumerStatefulWidget {
  const AddPropertyScreen({super.key, this.editPropertyId});

  final String? editPropertyId;

  @override
  ConsumerState<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _PropertyTypeCard extends StatelessWidget {
  const _PropertyTypeCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white,
            border: Border.all(
              color: selected
                  ? accent
                  : scheme.outlineVariant.withValues(alpha: 0.7),
              width: selected ? 2.4 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? accent : scheme.onSurfaceVariant,
                size: selected ? 34 : 28,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: selected ? accent : scheme.onSurface,
                  fontSize: selected ? 15 : 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineStepAction extends StatelessWidget {
  const _InlineStepAction({
    required this.isLastStep,
    required this.loading,
    required this.onNext,
    required this.onPreview,
    required this.onPublish,
  });

  final bool isLastStep;
  final bool loading;
  final Future<void> Function() onNext;
  final VoidCallback onPreview;
  final Future<void> Function() onPublish;

  @override
  Widget build(BuildContext context) {
    if (!isLastStep) {
      return FilledButton.icon(
        onPressed: loading ? null : onNext,
        icon: const Icon(Icons.arrow_back_rounded),
        label: const Text('التالي'),
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: loading ? null : onPreview,
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('معاينة'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: loading ? null : onPublish,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.publish_rounded),
            label: Text(loading ? 'جاري النشر…' : 'نشر'),
          ),
        ),
      ],
    );
  }
}

class _AddPropertyScreenState extends ConsumerState<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  int _step = 0;

  final _price = TextEditingController();
  final _area = TextEditingController();
  final _facadeM = TextEditingController();
  final _depthM = TextEditingController();
  final _rooms = TextEditingController();
  final _bathrooms = TextEditingController();
  final _salons = TextEditingController();
  final _floor = TextEditingController();
  final _totalFloors = TextEditingController();
  final _parcelName = TextEditingController();
  final _parcelNo = TextEditingController();
  final _pieceNo = TextEditingController();
  final _aptPerFloor = TextEditingController();
  final _description = TextEditingController();

  PropertyCategory _category = PropertyCategory.apartment;
  PropertySegment _segment = PropertySegment.standard;
  String _gov = Iraq.governorates.first;
  String _purpose = 'sale';
  String _bathType = 'غربي';
  String _streetType = 'رئيسي';
  String _aptPosition = 'أمام';
  String _aptDirection = 'شمالي';

  bool _balcony = false;
  String _furnishedStatus = 'غير مؤثثة';
  bool _kitchenHot = false;
  bool _kitchenCold = false;
  bool _parking = false;
  bool _guard = false;
  bool _parcelCorner = false;
  bool _aptCornerBuilding = false;
  bool _aptElev = false;
  bool _aptShared = false;
  bool _commStreet = false;
  bool _investment = false;

  final List<XFile> _pickedImages = [];
  XFile? _pickedVideo;
  Duration? _pickedVideoDuration;
  RangeValues? _videoTrimRange;
  LatLng? _pickedLocation;

  bool _loading = false;
  static const _mediaTools = MethodChannel(
    'com.aqaevewo.real_estate_iraq/media_tools',
  );

  /// مقاطعة من لوحة الإدارة (منشور «مقطع» المبسّط فقط).
  String? _selectedParcelId;

  /// محافظة / قضاء من السيرفر (جدول المحافظات والأقضية).
  String? _govUuid;
  String? _districtUuid;
  String? _districtNameApi;

  /// مجمع سكني من لوحة الإدارة (فئة compound).
  String? _selectedCompoundId;

  bool _negotiable = false;

  /// يُفعّل بعد اختيار قسم النشر؛ ثم تظهر أزرار بيع/إيجار.
  bool _step0CategoryChosen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.invalidate(parcelsListProvider);
      ref.invalidate(compoundsListProvider);
      await _loadEditableDraftIfNeeded();
      final auth = ref.read(authControllerProvider);
      if (!officePostingQuotaExhausted(
        isOffice: auth.role == UserRole.office,
        postingTrialUnlimited: auth.postingTrialUnlimited,
        postingListingsRemaining: auth.postingListingsRemaining,
      )) {
        return;
      }
      if (!mounted) return;
      await showPostingQuotaBlockedDialog(context);
      if (mounted) context.pop();
    });
  }

  Future<void> _loadEditableDraftIfNeeded() async {
    final id = widget.editPropertyId?.trim();
    if (id == null || id.isEmpty) return;
    setState(() => _loading = true);
    try {
      final p = await ref.read(propertyDetailProvider(id).future);
      if (p == null || !mounted) return;
      setState(() {
        _category = p.category;
        _segment = p.segment;
        _purpose = p.purpose;
        _gov = p.governorate.trim().isNotEmpty ? p.governorate : _gov;
        _price.text = p.priceIqd > 0 ? '${p.priceIqd}' : '';
        _area.text = p.areaSqm > 0 ? '${p.areaSqm}' : '';
        _description.text = p.description;
        _selectedParcelId =
            p.detailsJson?['parcel_id']?.toString().trim().isNotEmpty == true
            ? p.detailsJson!['parcel_id'].toString()
            : null;
        _selectedCompoundId =
            p.detailsJson?['compound_id']?.toString().trim().isNotEmpty == true
            ? p.detailsJson!['compound_id'].toString()
            : null;
        _step0CategoryChosen = true;
        _step = 1;
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحميل بيانات المنشور السابق للتعديل'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحميل بيانات المنشور للتعديل')),
      );
    }
  }

  @override
  void dispose() {
    _price.dispose();
    _area.dispose();
    _facadeM.dispose();
    _depthM.dispose();
    _rooms.dispose();
    _bathrooms.dispose();
    _salons.dispose();
    _floor.dispose();
    _totalFloors.dispose();
    _parcelName.dispose();
    _parcelNo.dispose();
    _pieceNo.dispose();
    _aptPerFloor.dispose();
    _description.dispose();
    super.dispose();
  }

  /// حقول اسم/رقم مقاطعة يدوية لم نعد نستخدمها — المقاطعات تُختار من الإدارة.
  bool get _needsParcel => false;

  bool get _parcelSimpleFlow =>
      _segment == PropertySegment.parcel &&
      (_category == PropertyCategory.land ||
          _category == PropertyCategory.compound);

  bool get _showBuildingBlock {
    switch (_category) {
      case PropertyCategory.land:
        return false;
      default:
        return true;
    }
  }

  int get _lastStepIndex => _parcelSimpleFlow ? 1 : 3;

  int get _progressSegments => _parcelSimpleFlow ? 2 : 4;

  /// إذا وُجدت أقضية مُعرَّفة للمحافظة على السيرفر يجب اختيار واحد.
  bool _districtChoiceRequiredSync() {
    final gid = _govUuid;
    if (gid == null || gid.length < 32) return false;
    final async = ref.read(districtsForGovernorateProvider(gid));
    final list = async.valueOrNull ?? const [];
    return list.isNotEmpty;
  }

  Widget _fallbackGovernorateDropdownParcel(BuildContext context) {
    final names =
        ref.watch(governoratesProvider).valueOrNull ?? Iraq.governorates;
    return DropdownButtonFormField<String>(
      key: ValueKey<String?>('addprop_gov_parcel_$_gov'),
      initialValue: names.contains(_gov) ? _gov : null,
      decoration: const InputDecoration(
        labelText: 'المحافظة',
        prefixIcon: Icon(Icons.map_outlined),
      ),
      items: names
          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          _gov = v;
          _govUuid = null;
          _districtUuid = null;
          _districtNameApi = null;
          _selectedParcelId = null;
        });
      },
    );
  }

  Widget _fallbackGovernorateDropdownStandard() {
    final names =
        ref.watch(governoratesProvider).valueOrNull ?? Iraq.governorates;
    return DropdownButtonFormField<String>(
      key: ValueKey<String?>('addprop_gov_std_$_gov'),
      initialValue: names.contains(_gov) ? _gov : null,
      decoration: const InputDecoration(
        labelText: 'المحافظة',
        prefixIcon: Icon(Icons.map_outlined),
      ),
      items: names
          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          _gov = v;
          _govUuid = null;
          _districtUuid = null;
          _districtNameApi = null;
        });
      },
    );
  }

  bool _validateStep() {
    switch (_step) {
      case 0:
        if (!_step0CategoryChosen) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('اختر القسم أولاً (مقاطعات، أرض، شقة…)'),
            ),
          );
          return false;
        }
        return true;
      case 1:
        if (_parcelSimpleFlow) {
          final reqDist = _districtChoiceRequiredSync();
          if (reqDist &&
              (_districtUuid == null || _districtUuid!.trim().isEmpty)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('اختر القضاء أو الناحية')),
            );
            return false;
          }
          if (_selectedParcelId == null || _selectedParcelId!.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('اختر اسم المقاطعة من القائمة')),
            );
            return false;
          }
          final pr = int.tryParse(_price.text.replaceAll(',', '').trim());
          if (pr == null || pr < 1) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('أدخل السعر (د.ع)')));
            return false;
          }
          if (_description.text.trim().length < 10) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('أدخل وصفاً أوضح (10 أحرف على الأقل)'),
              ),
            );
            return false;
          }
          if (_pickedImages.length != 1) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ارفع صورة واحدة فقط')),
            );
            return false;
          }
          if (_pickedLocation == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('حدد موقع العقار على الخريطة')),
            );
            return false;
          }
          return true;
        }
        final reqDistStd = _districtChoiceRequiredSync();
        if (reqDistStd &&
            (_districtUuid == null || _districtUuid!.trim().isEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('اختر القضاء أو الناحية')),
          );
          return false;
        }
        final pr = int.tryParse(_price.text.replaceAll(',', '').trim());
        final ar = int.tryParse(_area.text.trim());
        if (pr == null || pr < 1 || ar == null || ar < 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تحقق من السعر والمساحة')),
          );
          return false;
        }
        if (_pickedImages.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('أضف صورة واحدة على الأقل (حتى 15)')),
          );
          return false;
        }
        if (_pickedImages.length > 15) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('15 صورة كحد أقصى')));
          return false;
        }
        if (_pickedLocation == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('حدد موقع العقار على الخريطة')),
          );
          return false;
        }
        if (_category == PropertyCategory.compound &&
            (_selectedCompoundId == null ||
                _selectedCompoundId!.trim().isEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('اختر المجمع السكني من القائمة')),
          );
          return false;
        }
        return true;
      case 2:
        return true;
      case 3:
        if (_description.text.trim().length < 10) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('الوصف النهائي مطلوب (10 أحرف على الأقل)'),
            ),
          );
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  Map<String, dynamic> _detailsJson() {
    final building = <String, dynamic>{
      if (_showBuildingBlock) ...{
        'rooms': _rooms.text.trim(),
        'bathrooms': _bathrooms.text.trim(),
        'bath_type': _bathType,
        'salons': _salons.text.trim(),
        'kitchen_hot': _kitchenHot,
        'kitchen_cold': _kitchenCold,
        if (_category != PropertyCategory.house) 'floor': _floor.text.trim(),
        'total_floors': _totalFloors.text.trim(),
      },
      if (_needsParcel) ...{
        'parcel_name': _parcelName.text.trim(),
        'parcel_no': _parcelNo.text.trim(),
        'piece_no': _pieceNo.text.trim(),
        'street_type': _streetType,
        'corner': _parcelCorner,
      },
      if (_category == PropertyCategory.apartment) ...{
        'apt_floor': _floor.text.trim(),
        'apt_position': _aptPosition,
        'apt_corner': _aptCornerBuilding,
        'apts_per_floor': _aptPerFloor.text.trim(),
        'apt_direction': _aptDirection,
        'apt_elevator': _aptElev,
        'apt_shared_services': _aptShared,
        'balcony': _balcony,
        'furnished': _furnishedStatus,
      },
    };

    final amenities = <String, dynamic>{
      if (_category == PropertyCategory.compound) ...{
        'parking': _parking,
        'guard': _guard,
      },
    };

    final features = <String, dynamic>{
      'commercial_street': _commStreet,
      'investment': _investment,
    };

    return {
      if (_pickedLocation != null)
        'location': {
          'lat': _pickedLocation!.latitude,
          'lng': _pickedLocation!.longitude,
        },
      if (_districtUuid != null && _districtUuid!.trim().isNotEmpty) ...{
        'district_id': _districtUuid!.trim(),
        'district_name': (_districtNameApi ?? '').trim(),
      },
      'facade_m': _facadeM.text.trim(),
      'depth_m': _depthM.text.trim(),
      'building': building,
      'amenities': amenities,
      'features': features,
      if (_videoTrimRange != null) ...{
        'video_trim_start_seconds': _videoTrimRange!.start.round(),
        'video_trim_end_seconds': _videoTrimRange!.end.round(),
      },
    };
  }

  Future<void> _handlePublishError(String message) async {
    await ref.read(authControllerProvider.notifier).refreshPostingFromServer();
    if (!mounted) return;
    final quota =
        message.contains('نفدت') ||
        message.contains('حصة') ||
        message.contains('باقتك');
    if (quota) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تنبيه الباقة'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
            TextButton(
              onPressed: () async {
                final uri = Uri.parse('https://wa.me/9647871456361');
                await launchUrl(uri, mode: LaunchMode.externalApplication);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('واتساب الدعم'),
            ),
          ],
        ),
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _draftAddress() {
    if (_parcelSimpleFlow) {
      final parcels =
          ref.read(parcelsListProvider).valueOrNull ?? const <ParcelSummary>[];
      for (final p in parcels) {
        if (p.id == _selectedParcelId) return p.displayName;
      }
    }
    final district = (_districtNameApi ?? '').trim();
    if (district.isNotEmpty) return district;
    return _gov.trim();
  }

  String _draftTitle() {
    if (_parcelSimpleFlow) {
      final address = _draftAddress();
      return address.isEmpty ? 'مقاطعة' : 'مقاطعة — $address';
    }
    final address = _draftAddress();
    return '${_category.labelAr}${address.isEmpty ? '' : ' — $address'}';
  }

  String? _selectedCompoundName() {
    final id = _selectedCompoundId?.trim();
    if (id == null || id.isEmpty) return null;
    final compounds =
        ref.read(compoundsListProvider).valueOrNull ??
        const <CompoundSummary>[];
    for (final c in compounds) {
      if (c.id == id) return c.displayName;
    }
    return null;
  }

  String _formatIqd(int value) {
    if (value <= 0) return 'قابل للتفاوض';
    final s = value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '$s د.ع';
  }

  Future<void> _openPreview() async {
    if (!_validateStep()) return;
    final price = int.tryParse(_price.text.replaceAll(',', '').trim()) ?? 0;
    final area = int.tryParse(_area.text.trim()) ?? 0;
    final address = _draftAddress();
    final images = _pickedImages
        .map((e) => e.path)
        .where((e) => e.isNotEmpty)
        .toList();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SafeArea(
          top: false,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.82,
            minChildSize: 0.45,
            maxChildSize: 0.94,
            builder: (context, scrollController) => ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  'معاينة المنشور',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                _DraftPropertyPreviewCard(
                  title: _draftTitle(),
                  category: _category.labelAr,
                  purpose: _purpose == 'rent' ? 'إيجار' : 'بيع',
                  governorate: _gov,
                  address: address,
                  price: _formatIqd(price),
                  area: _parcelSimpleFlow || area <= 0 ? null : '$area م²',
                  description: _description.text.trim(),
                  imagePaths: images,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('المعاينة جيدة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _publish() async {
    final auth = ref.read(authControllerProvider);
    if (auth.role != UserRole.office && auth.role != UserRole.customer) return;
    if (officePostingQuotaExhausted(
      isOffice: auth.role == UserRole.office,
      postingTrialUnlimited: auth.postingTrialUnlimited,
      postingListingsRemaining: auth.postingListingsRemaining,
    )) {
      if (mounted) await showPostingQuotaBlockedDialog(context);
      return;
    }
    if (auth.apiToken == null || auth.apiToken!.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('انتهت الجلسة — سجّل الدخول من جديد')),
        );
      }
      return;
    }
    if (!_validateStep()) return;

    setState(() => _loading = true);

    try {
      final api = ref.read(vewoApiClientProvider);
      final urls = <String>[];
      for (var i = 0; i < _pickedImages.length; i++) {
        final x = _pickedImages[i];
        var bytes = await x.readAsBytes();
        if (bytes.isEmpty) continue;
        bytes = await burnVewoWatermarkOnImageBytes(bytes);
        var name = x.name.trim().isNotEmpty ? x.name : 'img_$i.jpg';
        if (!name.toLowerCase().endsWith('.jpg') &&
            !name.toLowerCase().endsWith('.jpeg')) {
          name = 'img_$i.jpg';
        }
        final up = await api.postMultipartBytes(
          'properties/upload',
          'file',
          bytes,
          name,
        );
        final u = up['public_url']?.toString();
        if (u != null && u.isNotEmpty) urls.add(u);
      }
      if (urls.isEmpty) {
        throw Exception('فشل رفع الصور');
      }

      if (_parcelSimpleFlow) {
        final parcelsAsync = ref.read(parcelsListProvider);
        final parcels = parcelsAsync.asData?.value ?? const <ParcelSummary>[];
        ParcelSummary? parcel;
        for (final p in parcels) {
          if (p.id == _selectedParcelId) {
            parcel = p;
            break;
          }
        }
        if (parcel == null) {
          if (!mounted) return;
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'المقاطعة غير متوفرة — تأكد من الاتصال أو حدّث الصفحة.',
              ),
            ),
          );
          return;
        }

        final purpose = _purpose;
        final autoTitle = 'مقاطعة — ${parcel.name}';
        final price = int.parse(_price.text.replaceAll(',', '').trim());
        final res = await ref
            .read(propertyListingsProvider.notifier)
            .createRemote(
              title: autoTitle,
              governorate: _gov.trim().isNotEmpty
                  ? _gov
                  : (parcel.governorate.trim().isNotEmpty
                        ? parcel.governorate
                        : Iraq.governorates.first),
              addressLine: parcel.displayName.trim(),
              category: _category,
              segment: _segment,
              purpose: purpose,
              detailsJson: {
                'parcel_listing': true,
                'parcel_id': parcel.id,
                'parcel_name': parcel.displayName,
                'negotiable': _negotiable,
                if (_districtUuid != null &&
                    _districtUuid!.trim().isNotEmpty) ...{
                  'district_id': _districtUuid!.trim(),
                  'district_name': (_districtNameApi ?? '').trim(),
                },
                if (_pickedLocation != null)
                  'location': {
                    'lat': _pickedLocation!.latitude,
                    'lng': _pickedLocation!.longitude,
                  },
              },
              priceIqd: price,
              areaSqm: 1,
              description: _description.text.trim(),
              imageUrls: urls,
              parcelId: parcel.id,
            );

        if (!mounted) return;
        setState(() => _loading = false);

        if (res.error != null) {
          await _handlePublishError(res.error!);
          return;
        }
        if (mounted) {
          final ap = res.approval ?? 'pending';
          final msg = ap == 'approved'
              ? 'تم نشر المقطع — يظهر مباشرة (حساب مكتب)'
              : 'تم الإرسال للمراجعة — سيظهر بعد موافقة الإدارة (حساب شخصي)';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
        context.pop();
        return;
      }

      final price = int.parse(_price.text.replaceAll(',', '').trim());
      final area = int.parse(_area.text.trim());
      final districtLine =
          (_districtNameApi != null && _districtNameApi!.trim().isNotEmpty)
          ? _districtNameApi!.trim()
          : _gov.trim();
      final address = districtLine.isNotEmpty ? districtLine : _gov.trim();
      final purpose = _purpose;

      String? videoUrl;
      if (_pickedVideo != null && _pickedVideo!.path.isNotEmpty) {
        final uploadVideo = await _trimVideoForUpload(_pickedVideo!);
        final vb = await uploadVideo.readAsBytes();
        if (vb.isNotEmpty) {
          final vn = uploadVideo.name.trim().isNotEmpty
              ? uploadVideo.name
              : 'video.mp4';
          final uv = await api.postMultipartBytes(
            'properties/upload',
            'file',
            vb,
            vn,
          );
          videoUrl = uv['public_url']?.toString();
        }
      }

      final autoTitle = '${_category.labelAr} — $address';
      final res = await ref
          .read(propertyListingsProvider.notifier)
          .createRemote(
            title: autoTitle,
            governorate: _gov,
            addressLine: address,
            category: _category,
            segment: _segment,
            purpose: purpose,
            detailsJson: {
              ..._detailsJson(),
              if (_selectedCompoundId != null)
                'compound_id': _selectedCompoundId,
              if ((_selectedCompoundName() ?? '').isNotEmpty)
                'compound_name': _selectedCompoundName(),
              'negotiable': _negotiable,
            },
            priceIqd: price,
            areaSqm: area,
            description: _description.text.trim(),
            imageUrls: urls,
            videoUrl: videoUrl,
            compoundId: _selectedCompoundId,
          );

      if (!mounted) return;
      setState(() => _loading = false);

      if (res.error != null) {
        await _handlePublishError(res.error!);
        return;
      }
      if (mounted) {
        final ap = res.approval ?? 'pending';
        final msg = ap == 'approved'
            ? 'تم نشر العقار — يظهر مباشرة (حساب مكتب)'
            : 'تم الإرسال للمراجعة — سيظهر بعد موافقة الإدارة (حساب شخصي)';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر النشر: $e')));
    }
  }

  Future<void> _next() async {
    if (!_validateStep()) return;
    if (_step == 0) {
      final scheme = Theme.of(context).colorScheme;
      final picked = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (ctx) {
          var local = _purpose;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: StatefulBuilder(
                builder: (ctx, setModal) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'ما الغرض؟',
                      textAlign: TextAlign.center,
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'اختر إيجاراً أو بيعاً قبل إكمال الخطوات التالية.',
                      textAlign: TextAlign.center,
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'sale',
                          icon: Icon(Icons.sell_outlined),
                          label: Text('بيع'),
                        ),
                        ButtonSegment(
                          value: 'rent',
                          icon: Icon(Icons.key_outlined),
                          label: Text('إيجار'),
                        ),
                      ],
                      selected: {local},
                      onSelectionChanged: (s) =>
                          setModal(() => local = s.first),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, local),
                      child: const Text('متابعة'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
      if (!mounted || picked == null) return;
      setState(() => _purpose = picked);
    }
    if (_step < _lastStepIndex) {
      setState(() => _step++);
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const AppBarBrandTitle('نشر عقار'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: _back,
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: List.generate(_progressSegments, (i) {
                        final active = i <= _step;
                        return Expanded(
                          child: Container(
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(99),
                              color: active
                                  ? scheme.primary
                                  : scheme.outlineVariant.withValues(
                                      alpha: 0.35,
                                    ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _parcelSimpleFlow
                            ? switch (_step) {
                                0 => '١ — نوع العقار والغرض',
                                _ => '٢ — المقاطعة والوصف والصورة',
                              }
                            : switch (_step) {
                                0 => '١ — نوع العقار والغرض',
                                1 => '٢ — المعلومات الأساسية',
                                2 =>
                                  _category == PropertyCategory.compound
                                      ? '٣ — التفاصيل والمرافق'
                                      : '٣ — التفاصيل',
                                _ => '٤ — المميزات والوصف',
                              },
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 132),
                      children: [
                        Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: scheme.primaryContainer.withValues(
                            alpha: 0.35,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'يُرسل للمراجعة ثم يُنشر في القسم المناسب بعد موافقة الإدارة.',
                              style: TextStyle(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        ..._buildStepBody(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 18,
                        offset: const Offset(0, -6),
                      ),
                    ],
                    border: Border(
                      top: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Row(
                      children: [
                        if (_step > 0) ...[
                          OutlinedButton(
                            onPressed: _loading ? null : _back,
                            child: const Text('رجوع'),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: _InlineStepAction(
                            isLastStep: _step >= _lastStepIndex,
                            loading: _loading,
                            onNext: () async => _next(),
                            onPreview: _openPreview,
                            onPublish: _publish,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStepBody(BuildContext context) {
    final List<Widget> body;
    if (_step == 0) {
      body = _step0(context);
    } else if (_step == 1) {
      body = _step1(context);
    } else if (_step == 2) {
      body = [..._step2(context), ..._step3Amenities(context)];
    } else {
      body = _step4(context);
    }
    return body;
  }

  List<Widget> _step0(BuildContext context) {
    return [
      const Text(
        'اختر القسم الذي تريد النشر فيه',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.45,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        children: [
          _PropertyTypeCard(
            label: 'مقاطعات',
            icon: Icons.grid_view_rounded,
            selected:
                _category == PropertyCategory.land &&
                _segment == PropertySegment.parcel,
            onTap: () => setState(() {
              _step0CategoryChosen = true;
              _category = PropertyCategory.land;
              _segment = PropertySegment.parcel;
              _selectedParcelId = null;
              _selectedCompoundId = null;
            }),
          ),
          _PropertyTypeCard(
            label: 'أرض',
            icon: Icons.park_outlined,
            selected:
                _category == PropertyCategory.land &&
                _segment == PropertySegment.standard,
            onTap: () => setState(() {
              _step0CategoryChosen = true;
              _category = PropertyCategory.land;
              _segment = PropertySegment.standard;
              _selectedParcelId = null;
              _selectedCompoundId = null;
            }),
          ),
          _PropertyTypeCard(
            label: 'بيت',
            icon: Icons.home_rounded,
            selected: _category == PropertyCategory.house,
            onTap: () => setState(() {
              _step0CategoryChosen = true;
              _category = PropertyCategory.house;
              _segment = PropertySegment.standard;
              _selectedParcelId = null;
              _selectedCompoundId = null;
            }),
          ),
          _PropertyTypeCard(
            label: 'شقة',
            icon: Icons.apartment_rounded,
            selected: _category == PropertyCategory.apartment,
            onTap: () => setState(() {
              _step0CategoryChosen = true;
              _category = PropertyCategory.apartment;
              _segment = PropertySegment.standard;
              _selectedParcelId = null;
              _selectedCompoundId = null;
            }),
          ),
          _PropertyTypeCard(
            label: 'محل',
            icon: Icons.storefront_outlined,
            selected: _category == PropertyCategory.shop,
            onTap: () => setState(() {
              _step0CategoryChosen = true;
              _category = PropertyCategory.shop;
              _segment = PropertySegment.standard;
              _selectedParcelId = null;
              _selectedCompoundId = null;
            }),
          ),
          _PropertyTypeCard(
            label: 'مجمع سكني',
            icon: Icons.location_city_outlined,
            selected: _category == PropertyCategory.compound,
            onTap: () => setState(() {
              _step0CategoryChosen = true;
              _category = PropertyCategory.compound;
              _segment = PropertySegment.standard;
              _selectedParcelId = null;
              _selectedCompoundId = null;
            }),
          ),
          _PropertyTypeCard(
            label: 'فيلا',
            icon: Icons.villa_outlined,
            selected: _category == PropertyCategory.villa,
            onTap: () => setState(() {
              _step0CategoryChosen = true;
              _category = PropertyCategory.villa;
              _segment = PropertySegment.standard;
              _selectedParcelId = null;
              _selectedCompoundId = null;
            }),
          ),
        ],
      ),
      if (_step0CategoryChosen)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            'تم اختيار القسم. اضغط «التالي» من الأسفل لاختيار البيع أو الإيجار.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        )
      else
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            'بعد اختيار القسم اضغط «التالي» لاختيار البيع أو الإيجار.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
    ];
  }

  List<Widget> _step1(BuildContext context) {
    if (_parcelSimpleFlow) {
      final parcelsAsync = ref.watch(parcelsListProvider);
      return parcelsAsync.when(
        loading: () => [
          const SizedBox(height: 40),
          const Center(child: CircularProgressIndicator()),
        ],
        error: (_, _) => [
          const Text(
            'تعذر تحميل قائمة المقاطعات. تحقق من الشبكة وحاول مجدداً.',
          ),
        ],
        data: (parcels) {
          if (parcels.isEmpty) {
            return [
              Card(
                color: Theme.of(
                  context,
                ).colorScheme.errorContainer.withValues(alpha: 0.35),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('لا توجد مقاطعات متاحة حالياً.'),
                ),
              ),
            ];
          }
          final filtered = parcels.where((p) {
            if (_gov.trim().isNotEmpty &&
                !governorateNamesMatch(p.governorate, _gov)) {
              return false;
            }
            if (_districtUuid != null && _districtUuid!.trim().isNotEmpty) {
              final pd = p.districtId;
              if (pd != null && pd.trim().isNotEmpty) {
                return pd.trim() == _districtUuid!.trim();
              }
            }
            return true;
          }).toList();
          final listForPicker = filtered.isNotEmpty ? filtered : parcels;
          final validId =
              _selectedParcelId != null &&
                  listForPicker.any((p) => p.id == _selectedParcelId)
              ? _selectedParcelId
              : null;
          final govFull = ref.watch(governoratesWithIdProvider);
          final govBlock = govFull.when(
            loading: () => <Widget>[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
            ],
            error: (_, _) => <Widget>[
              _fallbackGovernorateDropdownParcel(context),
            ],
            data: (govList) {
              if (govList.isEmpty) {
                return <Widget>[_fallbackGovernorateDropdownParcel(context)];
              }
              final w = <Widget>[
                DropdownButtonFormField<String>(
                  key: ValueKey<String?>('addparcel_gov_${_govUuid ?? 'null'}'),
                  initialValue:
                      _govUuid != null && govList.any((g) => g.id == _govUuid)
                      ? _govUuid
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'المحافظة',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                  items: govList
                      .map(
                        (g) => DropdownMenuItem<String>(
                          value: g.id,
                          child: Text(g.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    final row = govList.firstWhere((g) => g.id == v);
                    setState(() {
                      _govUuid = v;
                      _gov = row.name;
                      _districtUuid = null;
                      _districtNameApi = null;
                      _selectedParcelId = null;
                    });
                  },
                ),
              ];
              final gid = _govUuid;
              if (gid != null && gid.length >= 32) {
                final distAsync = ref.watch(
                  districtsForGovernorateProvider(gid),
                );
                w.add(const SizedBox(height: 12));
                w.add(
                  distAsync.when(
                    loading: () => const SizedBox(height: 4),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (dlist) {
                      if (dlist.isEmpty) return const SizedBox.shrink();
                      final dVal =
                          _districtUuid != null &&
                              dlist.any((d) => d.id == _districtUuid)
                          ? _districtUuid
                          : null;
                      return DropdownButtonFormField<String>(
                        key: ValueKey<String?>(
                          'addparcel_dist_${gid}_${_districtUuid ?? 'null'}',
                        ),
                        initialValue: dVal,
                        decoration: const InputDecoration(
                          labelText: 'القضاء أو الناحية',
                          prefixIcon: Icon(Icons.account_balance_outlined),
                        ),
                        items: dlist
                            .map(
                              (d) => DropdownMenuItem<String>(
                                value: d.id,
                                child: Text(
                                  d.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          final name = dlist.firstWhere((d) => d.id == v).name;
                          setState(() {
                            _districtUuid = v;
                            _districtNameApi = name;
                            _selectedParcelId = null;
                          });
                        },
                      );
                    },
                  ),
                );
              }
              return w;
            },
          );
          return [
            ...govBlock,
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey<String?>('addparcel_name_$validId'),
              initialValue: validId,
              decoration: const InputDecoration(
                labelText: 'اسم المقاطعة',
                prefixIcon: Icon(Icons.map_outlined),
              ),
              items: listForPicker
                  .map(
                    (p) => DropdownMenuItem<String>(
                      value: p.id,
                      child: Text(
                        '${p.displayName} (${p.governorate})',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedParcelId = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'السعر (د.ع)',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('قابل للتفاوض'),
              value: _negotiable,
              onChanged: _loading
                  ? null
                  : (v) => setState(() => _negotiable = v),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _description,
              minLines: 4,
              maxLines: 10,
              decoration: const InputDecoration(
                alignLabelWithHint: true,
                labelText: 'الوصف',
                hintText: 'صف المنشور باختصار…',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'صورة واحدة',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _loading ? null : _pickParcelImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_pickedImages.isEmpty ? 'اختر صورة' : 'تغيير الصورة'),
            ),
            const SizedBox(height: 16),
            const Text(
              'الموقع على الخريطة',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _loading ? null : _openLocationPicker,
              icon: const Icon(Icons.map_outlined),
              label: Text(
                _pickedLocation == null
                    ? 'اختر موقعاً على الخريطة'
                    : 'تم تحديد الموقع — تعديل',
              ),
            ),
            if (_pickedImages.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  File(_pickedImages.first.path),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ];
        },
      );
    }

    final govFullStd = ref.watch(governoratesWithIdProvider);
    final govBlockStd = govFullStd.when(
      loading: () => <Widget>[
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(),
        ),
      ],
      error: (_, _) => <Widget>[_fallbackGovernorateDropdownStandard()],
      data: (govList) {
        if (govList.isEmpty) {
          return <Widget>[_fallbackGovernorateDropdownStandard()];
        }
        final w = <Widget>[
          DropdownButtonFormField<String>(
            key: ValueKey<String?>('addstd_gov_${_govUuid ?? 'null'}'),
            initialValue:
                _govUuid != null && govList.any((g) => g.id == _govUuid)
                ? _govUuid
                : null,
            decoration: const InputDecoration(
              labelText: 'المحافظة',
              prefixIcon: Icon(Icons.map_outlined),
            ),
            items: govList
                .map(
                  (g) => DropdownMenuItem<String>(
                    value: g.id,
                    child: Text(g.name),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              final row = govList.firstWhere((g) => g.id == v);
              setState(() {
                _govUuid = v;
                _gov = row.name;
                _districtUuid = null;
                _districtNameApi = null;
                _selectedCompoundId = null;
              });
            },
          ),
        ];
        final gid = _govUuid;
        if (gid != null && gid.length >= 32) {
          final distAsync = ref.watch(districtsForGovernorateProvider(gid));
          w.add(const SizedBox(height: 12));
          w.add(
            distAsync.when(
              loading: () => const SizedBox(height: 4),
              error: (_, _) => const SizedBox.shrink(),
              data: (dlist) {
                if (dlist.isEmpty) return const SizedBox.shrink();
                final dVal =
                    _districtUuid != null &&
                        dlist.any((d) => d.id == _districtUuid)
                    ? _districtUuid
                    : null;
                return DropdownButtonFormField<String>(
                  key: ValueKey<String?>(
                    'addstd_dist_${gid}_${_districtUuid ?? 'null'}',
                  ),
                  initialValue: dVal,
                  decoration: const InputDecoration(
                    labelText: 'القضاء أو الناحية',
                    prefixIcon: Icon(Icons.account_balance_outlined),
                  ),
                  items: dlist
                      .map(
                        (d) => DropdownMenuItem<String>(
                          value: d.id,
                          child: Text(
                            d.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    final name = dlist.firstWhere((d) => d.id == v).name;
                    setState(() {
                      _districtUuid = v;
                      _districtNameApi = name;
                      _selectedCompoundId = null;
                    });
                  },
                );
              },
            ),
          );
        }
        return w;
      },
    );

    return [
      ...govBlockStd,
      const SizedBox(height: 12),
      if (_category != PropertyCategory.land &&
          _category != PropertyCategory.shop &&
          _category != PropertyCategory.house) ...[
        const SizedBox(height: 12),
        ...ref
            .watch(compoundsListProvider)
            .when(
              loading: () => [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                ),
              ],
              error: (_, _) => [const Text('تعذر تحميل قائمة المجمعات')],
              data: (compounds) {
                if (compounds.isEmpty) {
                  return [
                    Card(
                      color: Theme.of(
                        context,
                      ).colorScheme.errorContainer.withValues(alpha: 0.35),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'لا توجد مجمعات في الخادم — أضفها من لوحة الإدارة.',
                        ),
                      ),
                    ),
                  ];
                }
                final byGov = compounds.where((c) {
                  final g = _gov.trim();
                  if (g.isEmpty) return true;
                  return governorateNamesMatch(c.governorate, g);
                }).toList();
                final listForPicker = byGov.isNotEmpty ? byGov : compounds;
                final validId =
                    _selectedCompoundId != null &&
                        listForPicker.any((c) => c.id == _selectedCompoundId)
                    ? _selectedCompoundId
                    : null;
                return [
                  DropdownButtonFormField<String>(
                    key: ValueKey<String?>('addcompound_$validId'),
                    initialValue: validId,
                    decoration: InputDecoration(
                      labelText: _category == PropertyCategory.compound
                          ? 'المجمع السكني'
                          : 'داخل مجمع سكني (اختياري)',
                      prefixIcon: const Icon(Icons.location_city_outlined),
                      suffixIcon:
                          _category != PropertyCategory.compound &&
                              validId != null
                          ? IconButton(
                              tooltip: 'إلغاء اختيار المجمع',
                              onPressed: () =>
                                  setState(() => _selectedCompoundId = null),
                              icon: const Icon(Icons.close_rounded),
                            )
                          : null,
                    ),
                    items: [
                      if (_category != PropertyCategory.compound)
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('بدون مجمع'),
                        ),
                      ...listForPicker.map(
                        (c) => DropdownMenuItem<String>(
                          value: c.id,
                          child: Text(
                            '${c.displayName} (${c.governorate})',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(
                      () => _selectedCompoundId = v == null || v.trim().isEmpty
                          ? null
                          : v,
                    ),
                  ),
                ];
              },
            ),
      ],
      const SizedBox(height: 12),
      TextFormField(
        controller: _price,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: _category == PropertyCategory.land
              ? 'السعر (د.ع) — يظهر في الإعلان مباشرة'
              : 'السعر (د.ع)',
          prefixIcon: const Icon(Icons.payments_outlined),
        ),
      ),
      const SizedBox(height: 6),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('قابل للتفاوض'),
        value: _negotiable,
        onChanged: _loading ? null : (v) => setState(() => _negotiable = v),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _area,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'المساحة (م²)',
          prefixIcon: Icon(Icons.square_foot_outlined),
        ),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _facadeM,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'الواجهة (م)',
          helperText: 'عرض الواجهة على الشارع',
          prefixIcon: Icon(Icons.straighten),
        ),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _depthM,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'النزال / العمق (م)',
          prefixIcon: Icon(Icons.straighten),
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'الموقع على الخريطة',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      OutlinedButton.icon(
        onPressed: _loading ? null : _openLocationPicker,
        icon: const Icon(Icons.map_outlined),
        label: Text(
          _pickedLocation == null
              ? 'اختر موقعاً على الخريطة'
              : 'تم تحديد الموقع — تعديل',
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'الصور والفيديو',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      Text(
        'صور: من 1 إلى 15 — فيديو: اختياري (ملف واحد فقط)',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.tonalIcon(
            onPressed: _loading ? null : _pickImages,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('إضافة صور'),
          ),
          FilledButton.tonalIcon(
            onPressed: _loading ? null : _pickVideo,
            icon: const Icon(Icons.videocam_outlined),
            label: Text(
              _pickedVideo == null ? 'فيديو (اختياري)' : 'تغيير الفيديو',
            ),
          ),
        ],
      ),
      if (_pickedVideo != null) ...[
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: LocalVideoPreview(
              path: _pickedVideo!.path,
              trimStartSeconds: _videoTrimRange?.start.round(),
              trimEndSeconds: _videoTrimRange?.end.round(),
              showProgress: false,
            ),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: _loading
                    ? null
                    : () => setState(() {
                        _pickedVideo = null;
                        _pickedVideoDuration = null;
                        _videoTrimRange = null;
                      }),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('حذف الفيديو'),
              ),
              if (_pickedVideoDuration != null)
                Chip(
                  avatar: const Icon(Icons.timer_outlined, size: 18),
                  label: Text('${_pickedVideoDuration!.inSeconds} ثانية'),
                ),
            ],
          ),
        ),
        if (_pickedVideoDuration != null &&
            _pickedVideoDuration!.inMilliseconds > 100) ...[
          const SizedBox(height: 4),
          Text(
            'قص حر للفيديو قبل النشر',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          _VideoTimelineTrimmer(
            duration: _pickedVideoDuration!,
            values:
                _videoTrimRange ??
                RangeValues(0, _pickedVideoDuration!.inMilliseconds / 1000),
            enabled: !_loading,
            onChanged: (v) => setState(() => _videoTrimRange = v),
          ),
        ],
      ],
      if (_pickedImages.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(
          '${_pickedImages.length} صورة',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _pickedImages.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final f = _pickedImages[i];
              return Stack(
                children: [
                  GestureDetector(
                    onTap: () => _openPickedImagesPreview(i),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(f.path),
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 2,
                    left: 2,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                        onPressed: () =>
                            setState(() => _pickedImages.removeAt(i)),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ];
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final list = await picker.pickMultiImage(imageQuality: 82);
    if (!mounted) return;
    if (list.isEmpty) return;
    final prepared = <XFile>[];
    for (final x in list) {
      final cropped = await _previewAndCropImage(x);
      if (!mounted) return;
      if (cropped != null) prepared.add(cropped);
    }
    if (prepared.isEmpty) return;
    setState(() {
      _pickedImages.addAll(prepared);
      if (_pickedImages.length > 15) {
        _pickedImages.removeRange(15, _pickedImages.length);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الاحتفاظ بأول 15 صورة فقط')),
        );
      }
    });
  }

  Future<void> _openPickedImagesPreview(int initialIndex) async {
    if (_pickedImages.isEmpty) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (ctx) {
        final controller = PageController(initialPage: initialIndex);
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: SafeArea(
            child: Stack(
              children: [
                PageView.builder(
                  controller: controller,
                  itemCount: _pickedImages.length,
                  itemBuilder: (context, index) => InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: Image.file(
                        File(_pickedImages[index].path),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                Positioned.directional(
                  textDirection: Directionality.of(ctx),
                  top: 8,
                  end: 8,
                  child: IconButton.filled(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickParcelImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (!mounted || x == null) return;
    final prepared = await _previewAndCropImage(x);
    if (!mounted || prepared == null) return;
    setState(() {
      _pickedImages
        ..clear()
        ..add(prepared);
    });
  }

  Future<XFile?> _previewAndCropImage(XFile source) async {
    img.Image? original;
    try {
      original = img.decodeImage(await source.readAsBytes());
    } catch (_) {
      original = null;
    }
    if (original == null) return source;
    if (!mounted) return null;
    final cropRect = await showModalBottomSheet<Rect>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _ManualImageCropSheet(
        imagePath: source.path,
        imageWidth: original!.width,
        imageHeight: original.height,
      ),
    );
    if (cropRect == null) return null;
    if (cropRect == Rect.largest) return source;
    try {
      final x = (cropRect.left * original.width).round().clamp(
        0,
        original.width - 1,
      );
      final y = (cropRect.top * original.height).round().clamp(
        0,
        original.height - 1,
      );
      final w = (cropRect.width * original.width).round().clamp(
        1,
        original.width - x,
      );
      final h = (cropRect.height * original.height).round().clamp(
        1,
        original.height - y,
      );
      final cropped = img.copyCrop(original, x: x, y: y, width: w, height: h);
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/vewo_crop_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(img.encodeJpg(cropped, quality: 88));
      return XFile(file.path, name: file.uri.pathSegments.last);
    } catch (_) {
      return source;
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final v = await picker.pickVideo(source: ImageSource.gallery);
    if (!mounted) return;
    if (v == null) return;
    Duration? duration;
    final controller = VideoPlayerController.file(File(v.path));
    try {
      await controller.initialize();
      duration = controller.value.duration;
    } catch (_) {
      duration = null;
    } finally {
      await controller.dispose();
    }
    if (!mounted) return;
    setState(() {
      _pickedVideo = v;
      _pickedVideoDuration = duration;
      _videoTrimRange = duration == null
          ? null
          : RangeValues(0, duration.inMilliseconds / 1000);
    });
  }

  Future<XFile> _trimVideoForUpload(XFile source) async {
    final duration = _pickedVideoDuration;
    final range = _videoTrimRange;
    if (duration == null || range == null) return source;
    final total = duration.inMilliseconds / 1000;
    final start = range.start.clamp(0, total).toDouble();
    final end = range.end.clamp(0, total).toDouble();
    if (start <= 0.2 && end >= total - 0.2) return source;
    if (end - start < 0.1) {
      throw Exception('مدة الفيديو المحددة قصيرة جداً');
    }
    final dir = await getTemporaryDirectory();
    final out = File(
      '${dir.path}/vewo_trim_${DateTime.now().microsecondsSinceEpoch}.mp4',
    );
    try {
      await _mediaTools.invokeMethod<String>('trimVideo', {
        'inputPath': source.path,
        'outputPath': out.path,
        'startMs': (start * 1000).round(),
        'endMs': (end * 1000).round(),
      });
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'فشل قص الفيديو');
    }
    if (!await out.exists() || await out.length() < 1024) {
      throw Exception('فشل قص الفيديو، حاول اختيار فيديو آخر أو مدة أطول');
    }
    return XFile(out.path, name: out.uri.pathSegments.last);
  }

  Future<void> _openLocationPicker() async {
    final res = await showMapLocationPicker(
      context,
      ref,
      initial: _pickedLocation,
      title: 'حدد الموقع على الخريطة',
    );
    if (res != null && mounted) setState(() => _pickedLocation = res);
  }

  List<Widget> _step2(BuildContext context) {
    if (_category == PropertyCategory.shop) {
      return [
        const Text(
          'لا تفاصيل إضافية لهذا النوع — انتقل للتالي.',
          style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
        ),
      ];
    }
    final blocks = <Widget>[];
    if (_showBuildingBlock) {
      blocks.addAll([
        const Text(
          'تفاصيل البناء',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _rooms,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'عدد الغرف'),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _bathrooms,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'عدد الحمامات'),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey<String>('addprop_bath_$_bathType'),
          initialValue: _bathType,
          decoration: const InputDecoration(labelText: 'نوع الحمام'),
          items: const [
            'غربي',
            'شرقي',
            'الاثنين',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => _bathType = v ?? _bathType),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _salons,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'عدد الصالات'),
        ),
        const SizedBox(height: 10),
        const Text('المطبخ', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('مطبخ حار'),
              selected: _kitchenHot,
              onSelected: (v) => setState(() => _kitchenHot = v),
            ),
            FilterChip(
              label: const Text('مطبخ بارد'),
              selected: _kitchenCold,
              onSelected: (v) => setState(() => _kitchenCold = v),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_category != PropertyCategory.house)
          TextFormField(
            controller: _floor,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'الطابق'),
          ),
        if (_category != PropertyCategory.house) const SizedBox(height: 8),
        TextFormField(
          controller: _totalFloors,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'عدد الطوابق الكلي'),
        ),
        const SizedBox(height: 8),
        // بلكونة/تأثيث: حسب الطلب تظهر فقط بالشقق (وليس البيوت)
        const SizedBox(height: 16),
      ]);
    }
    if (_category == PropertyCategory.apartment) {
      blocks.addAll([
        const Text(
          'تفاصيل إضافية للشقة',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey<String>('addprop_furn_$_furnishedStatus'),
          initialValue: _furnishedStatus,
          decoration: const InputDecoration(labelText: 'التأثيث'),
          items: const [
            'غير مؤثثة',
            'مؤثثة',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) =>
              setState(() => _furnishedStatus = v ?? _furnishedStatus),
        ),
        SwitchListTile(
          title: const Text('بلكونة'),
          value: _balcony,
          onChanged: (v) => setState(() => _balcony = v),
        ),
        DropdownButtonFormField<String>(
          key: ValueKey<String>('addprop_aptpos_$_aptPosition'),
          initialValue: _aptPosition,
          decoration: const InputDecoration(labelText: 'موقع الشقة'),
          items: const [
            'أمام',
            'خلف',
            'زاوية',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => _aptPosition = v ?? _aptPosition),
        ),
        SwitchListTile(
          title: const Text('زاوية (مبنى)'),
          value: _aptCornerBuilding,
          onChanged: (v) => setState(() => _aptCornerBuilding = v),
        ),
        TextFormField(
          controller: _aptPerFloor,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'عدد الشقق في الطابق'),
        ),
        DropdownButtonFormField<String>(
          key: ValueKey<String>('addprop_aptdir_$_aptDirection'),
          initialValue: _aptDirection,
          decoration: const InputDecoration(labelText: 'اتجاه الشقة'),
          items: const [
            'شمالي',
            'جنوبي',
            'شرقي',
            'غربي',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => _aptDirection = v ?? _aptDirection),
        ),
        SwitchListTile(
          title: const Text('مصعد'),
          value: _aptElev,
          onChanged: (v) => setState(() => _aptElev = v),
        ),
        SwitchListTile(
          title: const Text('خدمات مشتركة'),
          value: _aptShared,
          onChanged: (v) => setState(() => _aptShared = v),
        ),
        const SizedBox(height: 16),
      ]);
    }
    if (_needsParcel) {
      blocks.addAll([
        const Text(
          'مقاطعات (قطعة مسجّلة)',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        TextFormField(
          controller: _parcelName,
          decoration: const InputDecoration(labelText: 'اسم المقاطعة'),
        ),
        TextFormField(
          controller: _parcelNo,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'رقم المقاطعة'),
        ),
        TextFormField(
          controller: _pieceNo,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'رقم القطعة'),
        ),
        DropdownButtonFormField<String>(
          key: ValueKey<String>('addprop_street_$_streetType'),
          initialValue: _streetType,
          decoration: const InputDecoration(labelText: 'الشارع'),
          items: const [
            'رئيسي',
            'فرعي',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => _streetType = v ?? _streetType),
        ),
        SwitchListTile(
          title: const Text('زاوية'),
          value: _parcelCorner,
          onChanged: (v) => setState(() => _parcelCorner = v),
        ),
      ]);
    }
    if (blocks.isEmpty) {
      return [const Text('لا حقول إضافية لهذا النوع — انتقل للتالي.')];
    }
    return blocks;
  }

  List<Widget> _step3Amenities(BuildContext context) {
    if (_category == PropertyCategory.compound) {
      return [
        const SizedBox(height: 16),
        const Text(
          'مرافق المجمع',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          title: const Text('موقف سيارات'),
          value: _parking,
          onChanged: (v) => setState(() => _parking = v),
        ),
        SwitchListTile(
          title: const Text('حراسة'),
          value: _guard,
          onChanged: (v) => setState(() => _guard = v),
        ),
      ];
    }
    return const [];
  }

  List<Widget> _step4(BuildContext context) {
    return [
      const Text(
        'مميزات إضافية',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      SwitchListTile(
        title: const Text('شارع تجاري'),
        value: _commStreet,
        onChanged: (v) => setState(() => _commStreet = v),
      ),
      SwitchListTile(
        title: const Text('مناسب للاستثمار'),
        value: _investment,
        onChanged: (v) => setState(() => _investment = v),
      ),
      const SizedBox(height: 16),
      const Text('وصف حر', style: TextStyle(fontWeight: FontWeight.w800)),
      TextFormField(
        controller: _description,
        minLines: 5,
        maxLines: 12,
        decoration: const InputDecoration(
          alignLabelWithHint: true,
          hintText: 'مثال: البيت مجدد حديثاً، موقع ممتاز قريب من الخدمات…',
        ),
      ),
    ];
  }
}

class _ManualImageCropSheet extends StatefulWidget {
  const _ManualImageCropSheet({
    required this.imagePath,
    required this.imageWidth,
    required this.imageHeight,
  });

  final String imagePath;
  final int imageWidth;
  final int imageHeight;

  @override
  State<_ManualImageCropSheet> createState() => _ManualImageCropSheetState();
}

class _ManualImageCropSheetState extends State<_ManualImageCropSheet> {
  Rect _crop = const Rect.fromLTWH(0.08, 0.20, 0.84, 0.552);
  static const _minSize = 0.16;
  static const _cardAspect = 1.52;

  void _move(Offset delta, Size boxSize) {
    setState(() {
      final dx = delta.dx / boxSize.width;
      final dy = delta.dy / boxSize.height;
      _crop = _clampRect(_crop.shift(Offset(dx, dy)));
    });
  }

  void _resize(Offset delta, Size boxSize, Alignment handle) {
    setState(() {
      final dx = delta.dx / boxSize.width;
      final dy = delta.dy / boxSize.height;
      var left = _crop.left;
      var top = _crop.top;
      var right = _crop.right;
      var bottom = _crop.bottom;
      if (handle.x < 0) left += dx;
      if (handle.x > 0) right += dx;
      if (handle.y < 0) top += dy;
      if (handle.y > 0) bottom += dy;
      if (right - left < _minSize) {
        if (handle.x < 0) left = right - _minSize;
        if (handle.x > 0) right = left + _minSize;
      }
      if (bottom - top < _minSize) {
        if (handle.y < 0) top = bottom - _minSize;
        if (handle.y > 0) bottom = top + _minSize;
      }
      _crop = _clampRect(
        _withCardAspect(Rect.fromLTRB(left, top, right, bottom)),
      );
    });
  }

  Rect _withCardAspect(Rect r) {
    final c = r.center;
    var w = r.width.abs().clamp(_minSize, 1.0);
    var h = w / _cardAspect;
    if (h > 1.0) {
      h = 1.0;
      w = h * _cardAspect;
    }
    return Rect.fromCenter(center: c, width: w, height: h);
  }

  Rect _clampRect(Rect r) {
    var left = r.left.clamp(0.0, 1.0 - _minSize);
    var top = r.top.clamp(0.0, 1.0 - _minSize);
    var right = r.right.clamp(left + _minSize, 1.0);
    var bottom = r.bottom.clamp(top + _minSize, 1.0);
    if (right > 1) {
      left -= right - 1;
      right = 1;
    }
    if (bottom > 1) {
      top -= bottom - 1;
      bottom = 1;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  Rect _imageRectFor(Size box) {
    final imageRatio = widget.imageWidth / widget.imageHeight;
    final boxRatio = box.width / box.height;
    if (imageRatio > boxRatio) {
      final h = box.width / imageRatio;
      return Rect.fromLTWH(0, (box.height - h) / 2, box.width, h);
    }
    final w = box.height * imageRatio;
    return Rect.fromLTWH((box.width - w) / 2, 0, w, box.height);
  }

  Widget _handle(Size imageSize, Alignment alignment) {
    return Align(
      alignment: Alignment(
        _crop.left * 2 - 1 + _crop.width * (alignment.x + 1),
        _crop.top * 2 - 1 + _crop.height * (alignment.y + 1),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => _resize(d.delta, imageSize, alignment),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: Colors.black87, width: 2),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'قص الصورة يدوياً',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text('حرّك مربع القص أو اسحب الزوايا مثل واتساب.'),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final boxSize = Size(constraints.maxWidth, 360);
                final imageRect = _imageRectFor(boxSize);
                final cropPx = Rect.fromLTWH(
                  imageRect.left + _crop.left * imageRect.width,
                  imageRect.top + _crop.top * imageRect.height,
                  _crop.width * imageRect.width,
                  _crop.height * imageRect.height,
                );
                final imageSize = imageRect.size;
                return SizedBox(
                  height: boxSize.height,
                  child: Stack(
                    children: [
                      Positioned.fromRect(
                        rect: imageRect,
                        child: Image.file(
                          File(widget.imagePath),
                          fit: BoxFit.fill,
                        ),
                      ),
                      Positioned.fromRect(
                        rect: imageRect,
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _CropOverlayPainter(crop: cropPx),
                          ),
                        ),
                      ),
                      Positioned.fromRect(
                        rect: cropPx,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onPanUpdate: (d) => _move(d.delta, imageSize),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fromRect(
                        rect: imageRect,
                        child: Stack(
                          children: [
                            _handle(imageSize, Alignment.topLeft),
                            _handle(imageSize, Alignment.topRight),
                            _handle(imageSize, Alignment.bottomLeft),
                            _handle(imageSize, Alignment.bottomRight),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء الصورة'),
                  ),
                ),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, Rect.largest),
                    child: const Text('بدون قص'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _crop),
                    child: const Text('اعتماد القص'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  const _CropOverlayPainter({required this.crop});

  final Rect crop;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.48);
    final full = Path()..addRect(Offset.zero & size);
    final hole = Path()..addRect(crop);
    canvas.drawPath(
      Path.combine(PathOperation.difference, full, hole),
      overlay,
    );
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final dx = crop.left + crop.width * i / 3;
      final dy = crop.top + crop.height * i / 3;
      canvas.drawLine(Offset(dx, crop.top), Offset(dx, crop.bottom), grid);
      canvas.drawLine(Offset(crop.left, dy), Offset(crop.right, dy), grid);
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.crop != crop;
  }
}

class _VideoTimelineTrimmer extends StatelessWidget {
  const _VideoTimelineTrimmer({
    required this.duration,
    required this.values,
    required this.enabled,
    required this.onChanged,
  });

  final Duration duration;
  final RangeValues values;
  final bool enabled;
  final ValueChanged<RangeValues> onChanged;

  String _fmt(double seconds) {
    final d = Duration(milliseconds: (seconds * 1000).round());
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final tenths = (d.inMilliseconds.remainder(1000) / 100).floor();
    return h > 0 ? '$h:$m:$s.$tenths' : '$m:$s.$tenths';
  }

  @override
  Widget build(BuildContext context) {
    final max = (duration.inMilliseconds / 1000)
        .clamp(0.1, double.infinity)
        .toDouble();
    final start = values.start.clamp(0, max).toDouble();
    final end = values.end.clamp(start, max).toDouble();
    final selected = (end - start).clamp(0, max).toDouble();
    final scheme = Theme.of(context).colorScheme;
    const minSelection = 0.1;

    void updateFromDx(double dx, double width) {
      if (!enabled || width <= 0) return;
      final seconds = (dx / width * max).clamp(0, max).toDouble();
      final startDx = width * (start / max);
      final endDx = width * (end / max);
      if ((dx - startDx).abs() <= (dx - endDx).abs()) {
        final nextStart = seconds.clamp(0, end - minSelection).toDouble();
        onChanged(RangeValues(nextStart, end));
      } else {
        final nextEnd = seconds.clamp(start + minSelection, max).toDouble();
        onChanged(RangeValues(start, nextEnd));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 72,
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(18),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final startX = constraints.maxWidth * (start / max);
              final endX = constraints.maxWidth * (end / max);
              final selectionWidth = (endX - startX).clamp(
                20.0,
                constraints.maxWidth,
              );
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (d) =>
                    updateFromDx(d.localPosition.dx, constraints.maxWidth),
                onTapDown: (d) =>
                    updateFromDx(d.localPosition.dx, constraints.maxWidth),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Row(
                        children: List.generate(
                          18,
                          (i) => Expanded(
                            child: Container(
                              height: 52,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    scheme.surfaceContainerHighest,
                                    scheme.outlineVariant,
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white.withValues(alpha: 0.20),
                                size: i.isEven ? 18 : 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Row(
                        children: [
                          SizedBox(
                            width: startX.clamp(0, constraints.maxWidth),
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: 0.48),
                            ),
                          ),
                          SizedBox(width: selectionWidth),
                          Expanded(
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: 0.48),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: startX.clamp(0, constraints.maxWidth).toDouble(),
                      width: selectionWidth,
                      child: Container(
                        height: 58,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (startX - 11)
                          .clamp(0, constraints.maxWidth - 22)
                          .toDouble(),
                      child: const _TrimHandle(),
                    ),
                    Positioned(
                      left: (endX - 11)
                          .clamp(0, constraints.maxWidth - 22)
                          .toDouble(),
                      child: const _TrimHandle(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'البداية ${_fmt(start)} • النهاية ${_fmt(end)} • المدة ${_fmt(selected)}',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _TrimHandle extends StatelessWidget {
  const _TrimHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

class _DraftPropertyPreviewCard extends StatelessWidget {
  const _DraftPropertyPreviewCard({
    required this.title,
    required this.category,
    required this.purpose,
    required this.governorate,
    required this.address,
    required this.price,
    required this.description,
    required this.imagePaths,
    this.area,
  });

  final String title;
  final String category;
  final String purpose;
  final String governorate;
  final String address;
  final String price;
  final String? area;
  final String description;
  final List<String> imagePaths;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = [
      governorate.trim(),
      address.trim(),
    ].where((e) => e.isNotEmpty).join(' • ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1.52,
            child: imagePaths.isEmpty
                ? ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.image_outlined,
                      size: 46,
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                : PageView.builder(
                    itemCount: imagePaths.length,
                    itemBuilder: (context, i) => Image.file(
                      File(imagePaths[i]),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: scheme.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(category)),
                    Chip(label: Text(purpose)),
                    if (area != null) Chip(label: Text(area!)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (loc.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    loc,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  price,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (description.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(description.trim()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
