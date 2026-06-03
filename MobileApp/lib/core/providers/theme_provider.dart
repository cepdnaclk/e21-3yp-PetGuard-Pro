import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'theme_mode';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

final themePreferencesProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final storedTheme = prefs.getString(_themeModeKey);
  ref.read(themeModeProvider.notifier).state =
      storedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
});

Future<void> setThemeMode(WidgetRef ref, ThemeMode mode) async {
  ref.read(themeModeProvider.notifier).state = mode;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
      _themeModeKey, mode == ThemeMode.dark ? 'dark' : 'light');
}
