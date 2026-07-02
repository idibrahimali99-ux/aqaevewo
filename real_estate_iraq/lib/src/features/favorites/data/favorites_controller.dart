import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final favoritesControllerProvider =
    NotifierProvider<FavoritesController, Set<String>>(FavoritesController.new);

class FavoritesController extends Notifier<Set<String>> {
  static const _storageKey = 'vewo_saved_property_ids';

  @override
  Set<String> build() {
    Future.microtask(_restore);
    return <String>{};
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_storageKey) ?? const [];
    state = ids.where((e) => e.trim().isNotEmpty).toSet();
  }

  Future<void> _persist(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, ids.toList()..sort());
  }

  bool isFavorite(String id) => state.contains(id);

  Future<void> toggle(String id) async {
    final next = {...state};
    if (!next.add(id)) next.remove(id);
    state = next;
    await _persist(next);
  }
}
