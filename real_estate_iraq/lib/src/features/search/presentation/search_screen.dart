import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:vewo_shared/vewo_shared.dart' show Iraq;
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_brand_mark.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/governorates/governorates_provider.dart';
import '../../../routing/app_routes.dart';
import '../../properties/data/properties_providers.dart';
import '../../properties/domain/property.dart';
import '../../properties/domain/property_category.dart';
import '../../properties/domain/property_segment.dart';
import '../../properties/presentation/property_card.dart';
import '../../properties/data/property_api_mapper.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  PropertyCategory? _category;
  String? _governorate;
  String? _districtId;
  String? _districtName;
  String? _purpose;
  int? _priceMin;
  int? _priceMax;
  int? _areaMin;
  int? _areaMax;
  final _searchQuery = TextEditingController();
  bool _parcelOnly = false;
  String? _routeSig;
  Timer? _searchDebounce;
  bool _serverSearching = false;
  List<Property> _serverMatches = const [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sig = GoRouterState.of(context).uri.toString();
    if (_routeSig != sig) {
      _routeSig = sig;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncRouteParams();
      });
    }
  }

  void _syncRouteParams() {
    final q = GoRouterState.of(context).uri.queryParameters;
    final catName = q['cat'];
    final qText = q['q'];
    final seg = q['segment'];
    final purpose = q['purpose'];
    final openFilter = q['filter'] == '1';
    PropertyCategory? cat;
    if (catName != null) {
      for (final c in PropertyCategory.values) {
        if (c.name == catName) {
          cat = c;
          break;
        }
      }
    }
    setState(() {
      _category = cat;
      _parcelOnly = seg == 'parcel';
      _purpose = (purpose == 'sale' || purpose == 'rent') ? purpose : null;
      if (qText != null && qText.isNotEmpty) {
        _searchQuery.text = Uri.decodeComponent(qText);
        _searchQuery.selection = TextSelection.collapsed(
          offset: _searchQuery.text.length,
        );
      }
    });
    if (openFilter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openFilterSheet();
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchQuery.dispose();
    super.dispose();
  }

  bool _shouldServerSearch(String value) {
    final clean = value.trim().replaceFirst(RegExp(r'^#+'), '');
    return clean.length >= 2;
  }

  void _queueServerSearch(String value) {
    _searchDebounce?.cancel();
    if (!_shouldServerSearch(value)) {
      if (_serverMatches.isNotEmpty || _serverSearching) {
        setState(() {
          _serverMatches = const [];
          _serverSearching = false;
        });
      }
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _runServerSearch(value);
    });
  }

  Future<void> _runServerSearch(String value) async {
    if (!_shouldServerSearch(value)) return;
    setState(() => _serverSearching = true);
    try {
      final data = await ref
          .read(vewoApiClientProvider)
          .getJson(
            'properties/list',
            query: {'q': value.trim(), 'limit': '50'},
          );
      final raw = data['items'];
      final found = <Property>[];
      if (raw is List) {
        for (final e in raw) {
          final row = e is Map<String, dynamic>
              ? e
              : e is Map
              ? Map<String, dynamic>.from(e)
              : null;
          if (row == null) continue;
          final p = propertyFromApiRow(row);
          if (p != null) found.add(p);
        }
      }
      if (!mounted) return;
      setState(() {
        _serverMatches = found;
        _serverSearching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _serverSearching = false);
    }
  }

  void _executeSearch() {
    final q = _searchQuery.text.trim();
    _searchDebounce?.cancel();
    setState(() {});
    if (_shouldServerSearch(q)) {
      _runServerSearch(q);
    } else {
      setState(() {
        _serverMatches = const [];
        _serverSearching = false;
      });
    }
  }

  List<Property> _applyFilters(List<Property> list) {
    final q = _searchQuery.text.trim().toLowerCase();
    final qNo = q.replaceFirst('#', '');
    return list.where((p) {
      if (q.isNotEmpty) {
        final publicNo = p.publicNo?.toString() ?? '';
        final hay =
            '${p.title} ${p.addressLine} ${p.governorate} $publicNo #$publicNo'
                .toLowerCase();
        if (!hay.contains(q)) return false;
        if (RegExp(r'^#?\d+$').hasMatch(q) && publicNo != qNo) return false;
      }
      if (_category != null && p.category != _category) return false;
      if (_governorate != null && p.governorate != _governorate) return false;
      if (_purpose != null && p.purpose != _purpose) return false;
      if (_districtId != null && _districtId!.trim().isNotEmpty) {
        final d = p.detailsJson;
        final did = d?['district_id']?.toString().trim();
        final dname = d?['district_name']?.toString().trim().toLowerCase();
        final selectedName = _districtName?.trim().toLowerCase();
        final byId = did != null && did == _districtId;
        final byName =
            selectedName != null &&
            selectedName.isNotEmpty &&
            (dname == selectedName ||
                p.addressLine.toLowerCase().contains(selectedName));
        if (!byId && !byName) return false;
      }
      if (_priceMin != null && p.priceIqd < _priceMin!) return false;
      if (_priceMax != null && p.priceIqd > _priceMax!) return false;
      if (_areaMin != null && p.areaSqm < _areaMin!) return false;
      if (_areaMax != null && p.areaSqm > _areaMax!) return false;
      if (_parcelOnly && p.segment != PropertySegment.parcel) return false;
      return true;
    }).toList();
  }

  Future<void> _openFilterSheet() async {
    final minPrice = TextEditingController(text: _priceMin?.toString() ?? '');
    final maxPrice = TextEditingController(text: _priceMax?.toString() ?? '');
    final minArea = TextEditingController(text: _areaMin?.toString() ?? '');
    final maxArea = TextEditingController(text: _areaMax?.toString() ?? '');
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (ctx) => Consumer(
          builder: (ctx, ref, _) {
            final govs =
                ref.watch(governoratesProvider).valueOrNull ??
                Iraq.governorates;
            final govsWithId =
                ref.watch(governoratesWithIdProvider).valueOrNull ?? const [];
            String? selectedGovId;
            for (final g in govsWithId) {
              if (g.name == _governorate) {
                selectedGovId = g.id;
                break;
              }
            }
            final districts = selectedGovId == null
                ? const <({String id, String name})>[]
                : (ref
                          .watch(districtsForGovernorateProvider(selectedGovId))
                          .valueOrNull ??
                      const <({String id, String name})>[]);
            return StatefulBuilder(
              builder: (ctx, setLocal) => Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  MediaQuery.viewInsetsOf(ctx).bottom +
                      MediaQuery.paddingOf(ctx).bottom +
                      96,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Text(
                      'الفلاتر',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('الكل')),
                        ButtonSegment(value: 'sale', label: Text('بيع')),
                        ButtonSegment(value: 'rent', label: Text('إيجار')),
                      ],
                      selected: {_purpose ?? 'all'},
                      onSelectionChanged: (s) {
                        setState(
                          () => _purpose = s.first == 'all' ? null : s.first,
                        );
                        setLocal(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<PropertyCategory?>(
                      initialValue: _category,
                      decoration: const InputDecoration(
                        labelText: 'نوع العقار',
                      ),
                      items: [
                        const DropdownMenuItem<PropertyCategory?>(
                          value: null,
                          child: Text('الكل'),
                        ),
                        ...PropertyCategory.values.map(
                          (c) => DropdownMenuItem<PropertyCategory?>(
                            value: c,
                            child: Text(c.labelAr),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() => _category = v);
                        setLocal(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: _governorate,
                      decoration: const InputDecoration(labelText: 'المحافظة'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('الكل'),
                        ),
                        ...govs.map(
                          (g) => DropdownMenuItem<String?>(
                            value: g,
                            child: Text(g),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _governorate = v;
                          _districtId = null;
                          _districtName = null;
                        });
                        setLocal(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue:
                          _districtId != null &&
                              districts.any((d) => d.id == _districtId)
                          ? _districtId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'القضاء / الناحية',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('الكل'),
                        ),
                        ...districts.map(
                          (d) => DropdownMenuItem<String?>(
                            value: d.id,
                            child: Text(d.name),
                          ),
                        ),
                      ],
                      onChanged: selectedGovId == null
                          ? null
                          : (v) {
                              String? name;
                              for (final d in districts) {
                                if (d.id == v) name = d.name;
                              }
                              setState(() {
                                _districtId = v;
                                _districtName = name;
                              });
                              setLocal(() {});
                            },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minPrice,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'أقل سعر',
                            ),
                            onChanged: (s) => setState(
                              () => _priceMin = int.tryParse(
                                s.replaceAll(',', ''),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: maxPrice,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'أعلى سعر',
                            ),
                            onChanged: (s) => setState(
                              () => _priceMax = int.tryParse(
                                s.replaceAll(',', ''),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minArea,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'من مساحة',
                            ),
                            onChanged: (s) =>
                                setState(() => _areaMin = int.tryParse(s)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: maxArea,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'إلى مساحة',
                            ),
                            onChanged: (s) =>
                                setState(() => _areaMax = int.tryParse(s)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _executeSearch();
                      },
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('بحث'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } finally {
      minPrice.dispose();
      maxPrice.dispose();
      minArea.dispose();
      maxArea.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final all = ref.watch(allPropertiesProvider);
    final propertiesLoading = ref.watch(propertyListingsLoadingProvider);
    final merged = <Property>[
      ..._serverMatches,
      for (final p in all)
        if (!_serverMatches.any((s) => s.id == p.id)) p,
    ];
    final filtered = _applyFilters(merged);
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: NestedScrollView(
        headerSliverBuilder: (context, inner) => [
          SliverAppBar.large(
            pinned: true,
            backgroundColor: AppColors.headerTop,
            foregroundColor: AppColors.onBrand,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.headerTop, AppColors.headerBottom],
                ),
              ),
            ),
            title: const SliverAppBarBrandHeading(screenTitle: 'بحث'),
          ),
        ],
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Material(
                elevation: 0.5,
                borderRadius: BorderRadius.circular(16),
                color: scheme.surface,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _searchQuery,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) {},
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'ابحث عن موقع أو اسم العقار',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: AppColors.mapPin,
                          ),
                          suffixIcon: _searchQuery.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'مسح',
                                  onPressed: () {
                                    _searchQuery.clear();
                                    _queueServerSearch('');
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.borderLight,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.borderLight,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.mapPin,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _serverSearching
                                  ? 'جاري البحث...'
                                  : 'النتائج: ${filtered.length}',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'الفلاتر',
                            onPressed: _openFilterSheet,
                            icon: const Icon(Icons.tune_rounded, size: 20),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            height: 44,
                            child: FilledButton.icon(
                              onPressed: _executeSearch,
                              icon: const Icon(Icons.search_rounded, size: 22),
                              label: const Text('بحث'),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton.filled(
                            tooltip: 'الخريطة',
                            onPressed: () =>
                                context.push(AppRoutes.propertiesMap),
                            icon: const Icon(Icons.map_outlined, size: 20),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: propertiesLoading && filtered.isEmpty && !_serverSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _SearchMapAndResults(items: filtered),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchMapAndResults extends StatelessWidget {
  const _SearchMapAndResults({required this.items});

  final List<Property> items;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        for (final p in items.take(12))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PropertyCard(
              property: p,
              onTap: () => context.push('${AppRoutes.propertyDetails}/${p.id}'),
            ),
          ),
      ],
    );
  }
}
