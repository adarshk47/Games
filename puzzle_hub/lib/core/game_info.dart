import 'package:flutter/material.dart';

import 'i18n/i18n.dart';

class GameInfo {
  const GameInfo({
    required this.id,
    required String title,
    required String subtitle,
    required this.icon,
    required this.color,
    required this.builder,
    this.emoji,
    this.featured = false,
    this.enabled = true,
  // Private fields cannot be named initializing formals.
  // ignore: prefer_initializing_formals
  })  : _title = title,
        // ignore: prefer_initializing_formals
        _subtitle = subtitle;

  final String id;
  final String _title;
  final String _subtitle;

  /// Localised via keys `game.<id>.title` / `game.<id>.subtitle`, falling back
  /// to the text given in the registry.
  String get title => tr('game.$id.title', const {}, _title);
  String get subtitle => tr('game.$id.subtitle', const {}, _subtitle);
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
