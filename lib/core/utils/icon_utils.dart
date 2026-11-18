import 'package:flutter/material.dart';

class IconUtils {
  static const Map<String, IconData> groupIcons = {
    'code': Icons.terminal_rounded,
    'school': Icons.school_rounded,
    'fitness': Icons.fitness_center_rounded,
    'language': Icons.translate_rounded,
    'business': Icons.trending_up_rounded,
    'book': Icons.menu_book_rounded,
    'art': Icons.palette_rounded,
    'music': Icons.music_note_rounded,
    'target': Icons.track_changes_rounded,
    'star': Icons.star_rounded,
    'health': Icons.favorite_rounded,
    'brain': Icons.psychology_rounded,
  };

  static IconData getIcon(String iconName) {
    return groupIcons[iconName.toLowerCase()] ?? Icons.school_rounded;
  }

  static Color parseColor(String hexString, {Color fallback = const Color(0xFF10B981)}) {
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  static const List<String> availableColors = [
    '#10B981', // Emerald
    '#3B82F6', // Blue
    '#6366F1', // Indigo
    '#8B5CF6', // Purple
    '#EC4899', // Pink
    '#F59E0B', // Amber
    '#EF4444', // Red
    '#14B8A6', // Teal
    '#06B6D4', // Cyan
    '#84CC16', // Lime
  ];
}
