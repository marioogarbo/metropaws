import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/theme_storage.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit(super.initialMode);

  void setMode(ThemeMode mode) {
    emit(mode);
    ThemeStorage.saveThemeMode(mode);
  }
}
