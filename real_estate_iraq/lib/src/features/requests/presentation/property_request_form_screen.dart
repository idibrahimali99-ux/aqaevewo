import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/governorates/governorates_provider.dart';
import '../../../core/layout/app_responsive.dart';
import '../../../core/widgets/app_brand_mark.dart';
import '../../auth/data/auth_controller.dart';
import '../data/property_requests_provider.dart';

class PropertyRequestFormScreen extends ConsumerStatefulWidget {
  const PropertyRequestFormScreen({super.key});

  @override
  ConsumerState<PropertyRequestFormScreen> createState() =>
      _PropertyRequestFormScreenState();
}

class _PropertyRequestFormScreenState
    extends ConsumerState<PropertyRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _areaMin = TextEditingController();
  final _areaMax = TextEditingController();
  final _priceMin = TextEditingController();
  final _priceMax = TextEditingController();
  final _phone = TextEditingController();
  final _description = TextEditingController();
  String _purpose = 'sale';
  String _category = 'land';
  String? _governorate;
  bool _saving = false;

  static const _categories = [
    ('land', 'أراضي'),
    ('parcel', 'مقاطعات'),
    ('house', 'بيوت'),
    ('apartment', 'شقق'),
    ('shop', 'محلات'),
    ('villa', 'فلل'),
    ('compound', 'مجمع سكني'),
  ];

  @override
  void initState() {
    super.initState();
    _phone.text = ref.read(authControllerProvider).phone;
  }

  @override
  void dispose() {
    _areaMin.dispose();
    _areaMax.dispose();
    _priceMin.dispose();
    _priceMax.dispose();
    _phone.dispose();
    _description.dispose();
    super.dispose();
  }

  int? _num(TextEditingController c) {
    final raw = c.text.replaceAll(',', '').trim();
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final res = await ref.read(propertyRequestSubmitterProvider).submit({
      'purpose': _purpose,
      'category': _category,
      'area_min': _num(_areaMin),
      'area_max': _num(_areaMax),
      'price_min': _num(_priceMin),
      'price_max': _num(_priceMax),
      'governorate': _governorate,
      'phone': _phone.text.trim(),
      'description': _description.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (res.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(res.error!)));
      return;
    }
    ref.invalidate(myPropertyRequestsProvider);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تم إرسال طلبك بنجاح'),
        content: Text(
          res.requestNo == null
              ? 'سنراجع الطلب ونتواصل معك.'
              : 'رقم طلبك: #${res.requestNo}\nيمكنك متابعة الحالة من قسم طلباتي.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('تم'),
          ),
        ],
      ),
    );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final govs = ref.watch(governoratesProvider);
    return Scaffold(
      appBar: AppBar(title: const AppBarBrandTitle('اطلب عقارك')),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: AppResponsive.pagePadding(context, accountForShellNav: true),
          children: [
            ResponsiveCenter(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'املأ تفاصيل العقار المطلوب',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'sale', label: Text('شراء')),
                          ButtonSegment(value: 'rent', label: Text('إيجار')),
                        ],
                        selected: {_purpose},
                        onSelectionChanged: (v) =>
                            setState(() => _purpose = v.first),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'القسم',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: [
                          for (final c in _categories)
                            DropdownMenuItem(value: c.$1, child: Text(c.$2)),
                        ],
                        onChanged: (v) =>
                            setState(() => _category = v ?? 'land'),
                      ),
                      const SizedBox(height: 14),
                      _ResponsiveFieldPair(
                        first: _numberField(_areaMin, 'المساحة من'),
                        second: _numberField(_areaMax, 'إلى'),
                      ),
                      const SizedBox(height: 14),
                      _ResponsiveFieldPair(
                        first: _numberField(_priceMin, 'السعر من'),
                        second: _numberField(_priceMax, 'إلى'),
                      ),
                      const SizedBox(height: 14),
                      govs.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (items) => DropdownButtonFormField<String>(
                          initialValue: _governorate,
                          decoration: const InputDecoration(
                            labelText: 'المحافظة',
                            prefixIcon: Icon(Icons.location_city_outlined),
                          ),
                          items: [
                            for (final g in items)
                              DropdownMenuItem(value: g, child: Text(g)),
                          ],
                          validator: (v) =>
                              v == null || v.isEmpty ? 'اختر المحافظة' : null,
                          onChanged: (v) => setState(() => _governorate = v),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'رقم الموبايل',
                          hintText: '07XXXXXXXXX',
                          prefixIcon: Icon(Icons.phone_iphone_rounded),
                        ),
                        validator: (v) {
                          final s = v?.trim() ?? '';
                          return RegExp(r'^07[0-9]{9}$').hasMatch(s)
                              ? null
                              : 'رقم عراقي صحيح مطلوب';
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _description,
                        minLines: 4,
                        maxLines: 8,
                        maxLength: 7000,
                        decoration: const InputDecoration(
                          labelText: 'وصف الطلب',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _saving ? null : _submit,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        label: const Text('إرسال الطلب'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField(TextEditingController c, String label) {
    return TextFormField(
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _ResponsiveFieldPair extends StatelessWidget {
  const _ResponsiveFieldPair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(children: [first, const SizedBox(height: 12), second]);
        }
        return Row(
          children: [
            Expanded(child: first),
            const SizedBox(width: 10),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}
