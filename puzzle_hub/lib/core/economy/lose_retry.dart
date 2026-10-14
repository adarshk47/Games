import 'package:flutter/material.dart';

import '../ads/ads_service.dart';
import '../i18n/i18n.dart';
import '../ui/ui.dart';

/// "One more chance" after losing: watch an ad and go one step back to try
/// again. Each game offers it once per game – lose again and it is over.
/// Ad-free players get it without an ad; if no ad can be shown at all the
/// chance is given anyway. Returns true when the game should go back.
class LoseRetry {
  LoseRetry._();

  /// Test hook: answers the dialog without showing it.
  @visibleForTesting
  static Future<bool?> Function()? answerOverride;

  static Future<bool> offer(BuildContext context) async {
    final o = answerOverride;
    final bool? want;
    if (o != null) {
      want = await o();
    } else {
      want = await showGeneralDialog<bool>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'retry',
        barrierColor: Colors.black.withValues(alpha: 0.6),
        transitionDuration: const Duration(milliseconds: 280),
        transitionBuilder: (_, a, _, child) => FadeTransition(
          opacity: a,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
            child: child,
          ),
        ),
        pageBuilder: (ctx, _, _) => _RetryDialog(onAnswer: (v) => Navigator.of(ctx).pop(v)),
      );
    }
    if (want != true) return false;
    if (AdsService.adFree) return true;
    final ok = await AdsService.showRewarded(reason: 'retry');
    if (ok || AdsService.lastRewardedUnavailable) return true;
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(tr('undo.watch_full')), duration: const Duration(seconds: 2)),
      );
    }
    return false;
  }
}

class _RetryDialog extends StatelessWidget {
  const _RetryDialog({required this.onAnswer});
  final ValueChanged<bool> onAnswer;

  @override
  Widget build(BuildContext context) {
    final free = AdsService.adFree;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Material(
          color: Colors.transparent,
          child: GlassCard(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
            radius: 30,
            glow: Pal.gold,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF2A1F63).withValues(alpha: 0.96),
                const Color(0xFF140E38).withValues(alpha: 0.96),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔁', style: TextStyle(fontSize: 46)),
                  const SizedBox(height: 6),
                  Text(
                    tr('retry.title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Pal.text, fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr('retry.msg'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Pal.textDim, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  PremiumButton(
                    key: const ValueKey('retry_yes'),
                    label: tr(free ? 'retry.go_free' : 'retry.go'),
                    icon: free ? Icons.undo_rounded : Icons.ondemand_video_rounded,
                    color: const Color(0xFF4DA8FF),
                    onTap: () => onAnswer(true),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    key: const ValueKey('retry_no'),
                    onPressed: () => onAnswer(false),
                    child: Text(
                      tr('retry.no'),
                      style: const TextStyle(color: Pal.textDim, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
