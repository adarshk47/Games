import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../ui/app_logo.dart';
import '../ui/ui.dart';
import 'i18n.dart';
import '../account/account_service.dart';

/// Grid of language chips (native name + English name). Used in the first-run
/// screen and in the settings sheet.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key, this.onPicked});
  final ValueChanged<AppLang>? onPicked;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLang>(
      valueListenable: I18n.lang,
      builder: (_, cur, _) => Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: [
          for (final l in languagesFor(AccountService.I.country))
            Pressable(
              key: ValueKey('lang_${l.code}'),
              onTap: () async {
                await I18n.set(l);
                onPicked?.call(l);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 140,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: l == cur ? Pal.accent(const Color(0xFF7C5CFF)) : null,
                  color: l == cur ? null : Colors.white.withValues(alpha: 0.07),
                  border: Border.all(color: l == cur ? Pal.gold : Pal.glassBorder, width: l == cur ? 2 : 1),
                ),
                child: Column(children: [
                  Text(l.nativeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Pal.text, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(l.englishName, style: const TextStyle(color: Pal.textDim, fontSize: 12)),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shown once on first launch, before the welcome / login screens.
class LanguageSelectScreen extends StatelessWidget {
  const LanguageSelectScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const AppLogo(size: 84).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8)),
                const SizedBox(height: 18),
                // Shown in all languages so everyone recognises it.
                const Text('Choose your language', style: TextStyle(color: Pal.text, fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text('अपनी भाषा चुनें  •  భాషను ఎంచుకోండి  •  மொழியைத் தேர்ந்தெடுக்கவும்',
                    textAlign: TextAlign.center, style: TextStyle(color: Pal.textDim, fontSize: 13)),
                const SizedBox(height: 22),
                const LanguagePicker(),
                const SizedBox(height: 26),
                ValueListenableBuilder<AppLang>(
                  valueListenable: I18n.lang,
                  builder: (_, _, _) => PremiumButton(
                    label: tr('common.continue'),
                    icon: Icons.arrow_forward_rounded,
                    onTap: () async {
                      await I18n.set(I18n.lang.value);
                      onDone();
                    },
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
