import 'package:flutter/material.dart';

import '../audio.dart';
import '../daily/reminder_tile.dart';
import '../i18n/i18n.dart';
import '../i18n/language_picker.dart';
import '../rewards.dart';
import 'app_theme.dart';
import 'glass_card.dart';
import 'palette.dart';

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
    return ValueListenableBuilder<int>(
      valueListenable: AppThemeController.current,
      builder: (_, _, _) {
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
                          const Expanded(
                            child: Text(
                              'Settings',
                              style: TextStyle(
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
                      'Sound effects',
                      'Tap, jeet, galti ki awaaz',
                      AppAudio.soundOn,
                      AppAudio.setSound,
                    ),
                    row(
                      Icons.music_note_rounded,
                      'Music',
                      'Background music',
                      AppAudio.musicOn,
                      AppAudio.setMusicEnabled,
                    ),
                    row(
                      Icons.vibration_rounded,
                      'Vibration',
                      'Halka haptic feedback',
                      AppAudio.hapticsOn,
                      AppAudio.setHaptics,
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
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.palette_rounded,
                            color: Pal.gold,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Theme',
                            style: TextStyle(
                              color: Pal.text,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const ThemePicker(),
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
          title: const Text(
            'Not enough coins',
            style: TextStyle(color: Pal.text, fontWeight: FontWeight.w900),
          ),
          content: Text(
            '${th.name} needs ${th.price} 🪙. Games khelo aur coins kamao!',
            style: const TextStyle(color: Pal.textDim),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
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
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: AppThemeController.themes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _Swatch(
              key: ValueKey('theme_swatch_${AppThemeController.themes[i].id}'),
              theme: AppThemeController.themes[i],
              selected: i == cur,
              unlocked: AppThemeController.isUnlocked(i),
              onTap: () => _tap(context, i),
            ),
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
                selected ? 'Active' : (theme.free ? 'Free' : 'Owned'),
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
              'Unlock this theme for ${theme.price} 🪙?',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Pal.textDim),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Pal.textDim),
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
                      child: Text('Unlock 🪙 ${theme.price}'),
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
