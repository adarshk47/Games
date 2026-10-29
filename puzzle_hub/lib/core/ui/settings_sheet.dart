import 'package:flutter/material.dart';

import '../audio.dart';
import '../daily/reminder_tile.dart';
import '../i18n/i18n.dart';
import '../i18n/language_picker.dart';
import '../rewards.dart';
import 'app_layout.dart';
import 'app_theme.dart';
import 'festive/festive_painters.dart';
import 'glass_card.dart';
import 'palette.dart';
import '../cheer.dart';
import '../../home/game_chakra.dart' show ChakraPreviewPainter;

/// Bottom sheet with Sound / Music / Vibration switches, the theme picker and
/// the daily reminder row. Opened from the home screen and from the speaker
/// button in every GameScaffold.
Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    Widget row(
      IconData icon,
      String title,
      String sub,
      ValueNotifier<bool> n,
      Future<void> Function(bool) set,
    ) {
      return ValueListenableBuilder<bool>(
        valueListenable: n,
        builder: (_, on, _) => SwitchListTile(
          secondary: Icon(icon, color: on ? Pal.gold : Pal.textDim, size: 28),
          title: Text(
            title,
            style: const TextStyle(
              color: Pal.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            sub,
            style: const TextStyle(color: Pal.textDim, fontSize: 12),
          ),
          value: on,
          activeThumbColor: Pal.gold,
          onChanged: (v) {
            set(v);
            if (v) AppAudio.play(Sound.tap);
          },
        ),
      );
    }

    final mq = MediaQuery.of(context);
    return ListenableBuilder(
      // Rebuild on theme and language changes (language can be switched here).
      listenable: Listenable.merge([AppThemeController.current, I18n.lang]),
      builder: (_, _) {
        final t = AppThemeController.theme;
        return Padding(
          padding: EdgeInsets.fromLTRB(14, 0, 14, 20 + mq.padding.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: mq.size.height * 0.85,
              maxWidth: 560,
            ),
            child: GlassCard(
              radius: 28,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              gradient: LinearGradient(
                colors: [
                  Color.lerp(t.bg1, t.orb, 0.35)!.withValues(alpha: 0.97),
                  t.bg0.withValues(alpha: 0.97),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              tr('common.settings'),
                              style: const TextStyle(
                                color: Pal.text,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const CoinPill(),
                        ],
                      ),
                    ),
                    row(
                      Icons.volume_up_rounded,
                      tr('home.settings.sound'),
                      tr('home.settings.sound_sub'),
                      AppAudio.soundOn,
                      AppAudio.setSound,
                    ),
                    row(
                      Icons.music_note_rounded,
                      tr('home.settings.music'),
                      tr('home.settings.music_sub'),
                      AppAudio.musicOn,
                      AppAudio.setMusicEnabled,
                    ),
                    row(
                      Icons.vibration_rounded,
                      tr('home.settings.vibration'),
                      tr('home.settings.vibration_sub'),
                      AppAudio.hapticsOn,
                      AppAudio.setHaptics,
                    ),
                    row(
                      Icons.celebration_rounded,
                      tr('cheer.setting'),
                      tr('cheer.setting_sub'),
                      Cheer.enabled,
                      Cheer.setEnabled,
                    ),
                    row(
                      Icons.record_voice_over_rounded,
                      tr('cheer.voice'),
                      tr('cheer.voice_sub'),
                      Cheer.voice,
                      Cheer.setVoice,
                    ),
                    const ReminderSettingsTile(),
                    ValueListenableBuilder<AppLang>(
                      valueListenable: I18n.lang,
                      builder: (ctx, l, _) => ListTile(
                        leading: const Icon(
                          Icons.translate_rounded,
                          color: Pal.gold,
                          size: 28,
                        ),
                        title: Text(
                          tr('common.language'),
                          style: const TextStyle(
                            color: Pal.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          '${l.nativeName}  •  ${l.englishName}',
                          style: const TextStyle(
                            color: Pal.textDim,
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: Pal.textDim,
                        ),
                        onTap: () => showModalBottomSheet(
                          context: ctx,
                          backgroundColor: const Color(0xFF1B1245),
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                          ),
                          builder: (sheet) => SafeArea(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                20,
                                16,
                                24,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    tr('common.choose_language'),
                                    style: const TextStyle(
                                      color: Pal.text,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  LanguagePicker(
                                    onPicked: (_) => Navigator.of(sheet).pop(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.palette_rounded,
                            color: Pal.gold,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            tr('home.settings.theme'),
                            style: const TextStyle(
                              color: Pal.text,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const ThemePicker(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.dashboard_customize_rounded,
                            color: Pal.gold,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr('home.settings.layout'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Pal.text,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  tr('home.settings.layout_sub'),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Pal.textDim,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const LayoutPicker(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Horizontal row of theme swatches. Tap an unlocked theme to apply it, a
/// locked one to buy it with coins.
class ThemePicker extends StatelessWidget {
  const ThemePicker({super.key});

  Future<void> _tap(BuildContext context, int i) async {
    if (AppThemeController.isUnlocked(i)) {
      await AppThemeController.select(i);
      return;
    }
    final th = AppThemeController.themes[i];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _BuyDialog(theme: th),
    );
    if (ok != true || !context.mounted) return;
    final r = await AppThemeController.buy(i);
    if (r == ThemeBuyResult.bought) AppAudio.play(Sound.coin);
    if (r == ThemeBuyResult.notEnoughCoins && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppThemeController.theme.bg1,
          title: Text(
            tr('home.theme.not_enough'),
            style: const TextStyle(
              color: Pal.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            tr('home.theme.needs', {'theme': th.name, 'coins': th.price}),
            style: const TextStyle(color: Pal.textDim),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('common.ok')),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppThemeController.unlocks,
      builder: (_, _, _) => ValueListenableBuilder<int>(
        valueListenable: AppThemeController.current,
        builder: (_, cur, _) => SizedBox(
          height: 124,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: AppThemeController.visibleIndices.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, k) {
              final i = AppThemeController.visibleIndices[k];
              return _Swatch(
                key: ValueKey(
                  'theme_swatch_${AppThemeController.themes[i].id}',
                ),
                theme: AppThemeController.themes[i],
                selected: i == cur,
                unlocked: AppThemeController.isUnlocked(i),
                onTap: () => _tap(context, i),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    required this.theme,
    required this.selected,
    required this.unlocked,
    required this.onTap,
  });
  final AppThemeData theme;
  final bool selected;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 62,
              height: 62,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? theme.highlight : Pal.glassBorder,
                  width: selected ? 2.5 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: theme.accent.withValues(alpha: 0.6),
                          blurRadius: 16,
                          spreadRadius: -2,
                        ),
                      ]
                    : null,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: theme.swatch,
                ),
                child: Center(
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 26,
                        )
                      : unlocked
                      ? null
                      : Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              theme.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Pal.text : Pal.textDim,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            if (!unlocked)
              Text(
                '🪙 ${theme.price}',
                style: const TextStyle(
                  color: Pal.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              )
            else
              Text(
                selected
                    ? tr('home.theme.active')
                    : (theme.free ? tr('common.free') : tr('home.theme.owned')),
                style: TextStyle(
                  color: selected ? theme.highlight : Pal.textDim,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Classic / Festive home layout selector with small painted previews.
class LayoutPicker extends StatelessWidget {
  const LayoutPicker({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLayout>(
      valueListenable: AppLayoutController.current,
      builder: (_, cur, _) => SizedBox(
        height: 112,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          children: [
            for (final l in AppLayout.values) ...[
              if (l.index > 0) const SizedBox(width: 8),
              SizedBox(
                width: 92,
                child: _LayoutOption(
                  key: ValueKey('layout_option_${l.name}'),
                  layout: l,
                  selected: l == cur,
                  onTap: () {
                    if (!l.available) {
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        SnackBar(
                          content: Text(
                            '${l.label} · ${tr('home.coming_soon')}',
                          ),
                        ),
                      );
                      return;
                    }
                    if (l != cur) AppLayoutController.select(l);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LayoutOption extends StatelessWidget {
  const _LayoutOption({
    super.key,
    required this.layout,
    required this.selected,
    required this.onTap,
  });
  final AppLayout layout;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeController.theme;
    return Semantics(
      button: true,
      selected: selected,
      label: layout.label,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.black.withValues(alpha: 0.18),
            border: Border.all(
              color: selected ? t.highlight : Pal.glassBorder,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: t.accent.withValues(alpha: 0.5),
                      blurRadius: 14,
                      spreadRadius: -4,
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: CustomPaint(
                    painter: layout.isNew
                        ? BentoPreviewPainter(
                            bg0: t.bg0,
                            bg1: t.bg1,
                            accent: t.accent,
                            style: layout.index - AppLayout.bento.index,
                          )
                        : layout == AppLayout.chakra
                        ? ChakraPreviewPainter(bg0: t.bg0, bg1: t.bg1)
                        : LayoutPreviewPainter(
                            festive: layout == AppLayout.festive,
                            bg0: t.bg0,
                            bg1: t.bg1,
                            accent: t.accent,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selected) ...[
                    Icon(
                      Icons.check_circle_rounded,
                      color: t.highlight,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      layout.available ? layout.label : '🔒 ${layout.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Pal.text : Pal.textDim,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuyDialog extends StatelessWidget {
  const _BuyDialog({required this.theme});
  final AppThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [theme.bg1, theme.bg0],
          ),
          border: Border.all(color: theme.accent.withValues(alpha: 0.6)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: theme.swatch,
                boxShadow: [
                  BoxShadow(
                    color: theme.accent.withValues(alpha: 0.6),
                    blurRadius: 22,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              theme.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Pal.text,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tr('home.theme.unlock_q', {'coins': theme.price}),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Pal.textDim),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      tr('common.cancel'),
                      style: const TextStyle(color: Pal.textDim),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('theme_buy_confirm'),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.accent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        tr('home.theme.unlock_btn', {'coins': theme.price}),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings thumbnail of the Bento home: tabs, two big tiles, small grid.
class BentoPreviewPainter extends CustomPainter {
  const BentoPreviewPainter({
    required this.bg0,
    required this.bg1,
    required this.accent,
    this.style = 0,
  });
  final Color bg0, bg1, accent;

  /// 0 Bento grid, 1 Spotlight card, 2 Journey list, 3 Mosaic, 4 A–Z, 5 Rooms.
  final int style;

  @override
  void paint(Canvas canvas, Size s) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & s,
      const Radius.circular(10),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..shader = LinearGradient(colors: [bg1, bg0])
            .createShader(Offset.zero & s),
    );
    final p = Paint();
    const colors = [
      Color(0xFFE53935),
      Color(0xFF43A047),
      Color(0xFF1E88E5),
      Color(0xFFFBC02D),
      Color(0xFF8E24AA),
      Color(0xFF00ACC1),
      Color(0xFFFF7043),
    ];
    if (style == 1) {
      // Big card, dots, play button, icon row.
      p.color = colors[0].withValues(alpha: 0.85);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s.width * 0.18, 6, s.width * 0.64, s.height * 0.5),
          const Radius.circular(6),
        ),
        p,
      );
      for (var i = 0; i < 4; i++) {
        p.color = Colors.white.withValues(alpha: i == 0 ? 0.9 : 0.35);
        canvas.drawCircle(
          Offset(s.width / 2 - 9 + i * 6, s.height * 0.62),
          1.6,
          p,
        );
      }
      p.color = accent;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s.width * 0.3, s.height * 0.68, s.width * 0.4, 7),
          const Radius.circular(4),
        ),
        p,
      );
      for (var i = 0; i < 4; i++) {
        p.color = colors[i + 1].withValues(alpha: 0.85);
        canvas.drawCircle(
          Offset(s.width * (0.2 + i * 0.2), s.height * 0.88),
          4,
          p,
        );
      }
      return;
    }
    if (style == 3) {
      // Two staggered columns of mixed-height cards.
      const hl = [0.42, 0.3, 0.36], hr = [0.3, 0.42, 0.3];
      final w = (s.width - 12) / 2;
      for (final (col, hs) in [(0, hl), (1, hr)]) {
        var y = col == 0 ? 4.0 : 9.0;
        for (final (i, h) in hs.indexed) {
          p.color = colors[col * 3 + i].withValues(alpha: 0.88);
          final hh = (s.height - 10) * h;
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(4 + col * (w + 4), y, w, hh - 3), const Radius.circular(4)),
            p,
          );
          y += hh;
        }
      }
      return;
    }
    if (style == 4) {
      // Search bar + list rows with play dots.
      p.color = Colors.white.withValues(alpha: 0.25);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(4, 4, s.width - 8, 8), const Radius.circular(4)),
        p,
      );
      for (var i = 0; i < 4; i++) {
        final y = 17 + i * (s.height - 20) / 4;
        p.color = colors[i].withValues(alpha: 0.9);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(5, y, 9, 9), const Radius.circular(2)), p);
        p.color = Colors.white.withValues(alpha: 0.35);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(18, y + 2, s.width - 40, 4), const Radius.circular(2)),
          p,
        );
        p.color = accent;
        canvas.drawCircle(Offset(s.width - 10, y + 4.5), 4, p);
      }
      return;
    }
    if (style == 5) {
      // Category doors, the first one open with small tiles.
      var y = 4.0;
      for (var i = 0; i < 3; i++) {
        p.color = colors[i + 3].withValues(alpha: 0.9);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(4, y, s.width - 8, 11), const Radius.circular(4)),
          p,
        );
        y += 14;
        if (i == 0) {
          final w = (s.width - 16) / 3;
          for (var k = 0; k < 3; k++) {
            p.color = Colors.white.withValues(alpha: 0.3);
            canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromLTWH(4 + k * (w + 4), y, w, 12), const Radius.circular(3)),
              p,
            );
          }
          y += 16;
        }
      }
      return;
    }
    if (style == 2) {
      // Rows with progress bars.
      for (var i = 0; i < 5; i++) {
        final y = 5 + i * (s.height - 8) / 5;
        p.color = colors[i].withValues(alpha: 0.9);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(5, y, 8, 8),
            const Radius.circular(2),
          ),
          p,
        );
        p.color = Colors.white.withValues(alpha: 0.2);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(17, y + 2, s.width - 24, 4),
            const Radius.circular(2),
          ),
          p,
        );
        p.color = accent;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(17, y + 2, (s.width - 24) * (0.85 - i * 0.15), 4),
            const Radius.circular(2),
          ),
          p,
        );
      }
      return;
    }
    // Tabs.
    for (var i = 0; i < 4; i++) {
      p.color = i == 0 ? accent : Colors.white.withValues(alpha: 0.25);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(4 + i * (s.width - 8) / 4, 4, (s.width - 8) / 4 - 3, 6),
          const Radius.circular(3),
        ),
        p,
      );
    }
    final w = (s.width - 8 - 6) / 3, h = (s.height - 16 - 6) / 3;
    var k = 0;
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 3; col++) {
        final wide = row == 0 && col == 0;
        if (row == 0 && col == 1) continue;
        p.color = colors[k++ % colors.length].withValues(alpha: 0.85);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              4 + col * (w + 3),
              14 + row * (h + 3),
              wide ? w * 2 + 3 : w,
              h,
            ),
            const Radius.circular(4),
          ),
          p,
        );
      }
    }
  }

  @override
  bool shouldRepaint(BentoPreviewPainter o) =>
      o.bg0 != bg0 || o.bg1 != bg1 || o.accent != accent || o.style != style;
}
