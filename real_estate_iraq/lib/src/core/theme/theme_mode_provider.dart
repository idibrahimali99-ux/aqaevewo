import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemePref = 'vewo_app_theme_mode';

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    Future.microtask(_restore);
    return ThemeMode.light;
  }

  Future<void> _restore() async {
    final sp = await SharedPreferences.getInstance();
    final v = sp.getString(_kThemePref);
    if (v == 'dark') {
      state = ThemeMode.dark;
    } else if (v == 'light') {
      state = ThemeMode.light;
    }
  }

  Future<void> toggle() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      _kThemePref,
      next == ThemeMode.dark ? 'dark' : 'light',
    );
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
