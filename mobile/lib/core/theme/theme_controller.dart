import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'app_theme.dart';

/// Persists and exposes the selected ThemeMode.
class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final mode = ref.watch(prefsStoreProvider).themeMode;
    return AppTheme.themeModeFromString(mode);
  }

  Future<void> toggle() async {
    final next =
        state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await ref
        .read(prefsStoreProvider)
        .setThemeMode(next == ThemeMode.dark ? 'dark' : 'light');
    state = next;
  }
}

final themeModeProvider =
    NotifierProvider<ThemeController, ThemeMode>(ThemeController.new);
