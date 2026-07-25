import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemeStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: false),
  );
  static const _keyThemeMode = 'mp_theme_mode';

  static Future<ThemeMode> getThemeMode() async {
    final value = await _storage.read(key: _keyThemeMode);
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static Future<void> saveThemeMode(ThemeMode mode) =>
      _storage.write(key: _keyThemeMode, value: mode.name);
}
