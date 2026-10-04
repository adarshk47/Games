import 'package:flutter/material.dart';

class GameInfo {
  const GameInfo({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.builder,
    this.emoji,
    this.featured = false,
    this.enabled = true,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final WidgetBuilder builder;

  /// Optional emoji shown on the home card instead of [icon].
  final String? emoji;

  /// Featured games get a wide banner card at the top of the home screen.
  final bool featured;

  /// Disabled games are fully built but hidden from the hub (enable in a later release).
  final bool enabled;
}
