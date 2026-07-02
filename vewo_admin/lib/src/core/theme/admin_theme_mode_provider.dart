import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kAdminThemePref = 'vewo_admin_theme_mode';

class AdminThemeModeController extends Notifier<ThemeMode> {
  bool _auto = true;

  @override
  ThemeMode build() {
    Future.microtask(_restore);
    return _modeForNow();
  }

  Future<void> _restore() async {
    final sp = await SharedPreferences.getInstance();
    final v = sp.getString(_kAdminThemePref) ?? 'auto';
    if (v == 'light') {
      _auto = false;
      state = ThemeMode.light;
    } else if (v == 'dark') {
      _auto = false;
      state = ThemeMode.dark;
    } else {
      _auto = true;
      state = _modeForNow();
    }
  }

  ThemeMode _modeForNow() {
    final hour = DateTime.now().hour;
    return hour >= 7 && hour < 18 ? ThemeMode.light : ThemeMode.dark;
  }

  bool get isAuto => _auto;

  String get label {
    if (_auto) return 'تلقائي حسب الوقت';
    return state == ThemeMode.dark ? 'داكن يدوي' : 'فاتح يدوي';
  }

  Future<void> toggle() async {
    _auto = false;
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      _kAdminThemePref,
      next == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  Future<void> setAuto() async {
    _auto = true;
    state = _modeForNow();
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kAdminThemePref, 'auto');
  }
}

final adminThemeModeProvider =
    NotifierProvider<AdminThemeModeController, ThemeMode>(
      AdminThemeModeController.new,
    );
