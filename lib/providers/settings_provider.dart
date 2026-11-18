import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final ThemeMode themeMode;
  final bool enableSound;
  final bool enableVibration;
  final int snoozeDurationMinutes;
  final int defaultReminderHour;
  final int defaultReminderMinute;
  final int weekStartDay; // 1 = Monday, 7 = Sunday
  final bool quietHoursEnabled;
  final int quietHoursStart; // 22 (10 PM)
  final int quietHoursEnd; // 7 (7 AM)

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.enableSound = true,
    this.enableVibration = true,
    this.snoozeDurationMinutes = 10,
    this.defaultReminderHour = 8,
    this.defaultReminderMinute = 0,
    this.weekStartDay = 1,
    this.quietHoursEnabled = false,
    this.quietHoursStart = 22,
    this.quietHoursEnd = 7,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    bool? enableSound,
    bool? enableVibration,
    int? snoozeDurationMinutes,
    int? defaultReminderHour,
    int? defaultReminderMinute,
    int? weekStartDay,
    bool? quietHoursEnabled,
    int? quietHoursStart,
    int? quietHoursEnd,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      enableSound: enableSound ?? this.enableSound,
      enableVibration: enableVibration ?? this.enableVibration,
      snoozeDurationMinutes: snoozeDurationMinutes ?? this.snoozeDurationMinutes,
      defaultReminderHour: defaultReminderHour ?? this.defaultReminderHour,
      defaultReminderMinute: defaultReminderMinute ?? this.defaultReminderMinute,
      weekStartDay: weekStartDay ?? this.weekStartDay,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
    );
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('theme_mode') ?? ThemeMode.system.index;
    state = state.copyWith(
      themeMode: ThemeMode.values[themeIndex],
      enableSound: prefs.getBool('enable_sound') ?? true,
      enableVibration: prefs.getBool('enable_vibration') ?? true,
      snoozeDurationMinutes: prefs.getInt('snooze_duration') ?? 10,
      weekStartDay: prefs.getInt('week_start_day') ?? 1,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
  }

  Future<void> setSound(bool enable) async {
    state = state.copyWith(enableSound: enable);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_sound', enable);
  }

  Future<void> setVibration(bool enable) async {
    state = state.copyWith(enableVibration: enable);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_vibration', enable);
  }

  Future<void> setSnoozeDuration(int minutes) async {
    state = state.copyWith(snoozeDurationMinutes: minutes);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('snooze_duration', minutes);
  }

  Future<void> setWeekStartDay(int day) async {
    state = state.copyWith(weekStartDay: day);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('week_start_day', day);
  }
}
