import 'package:flutter/material.dart';

import '../ads/ads_service.dart';
import '../i18n/i18n.dart';
import '../rewards.dart';
import '../ui/ui.dart';

/// Shared "go back" offer used by every game with an Undo button:
/// 1 step = 1 ad, 2 steps = 2 ads, 3 steps (the maximum) = 3 ads, every time.
/// Coins work too ([pricePerStep] each). Ad-free players go back for free.
class UndoOffer {
  UndoOffer._();

  static const maxSteps = 3;
  static const pricePerStep = 10;

  /// Asks how many steps to go back (up to [available], max 3) and collects
  /// the ads / coins. Returns the number of steps the game should undo (0 =
  /// cancelled or not paid).
  static Future<int> ask(BuildContext context, {required int available}) async {
    final can = available.clamp(0, maxSteps);
    if (can <= 0) return 0;
    if (AdsService.adFree) return _pickFree(context, can);
    final r = await showGeneralDialog<int>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'undo',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (_, a, _, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
          child: child,
        ),
      ),
      pageBuilder: (_, _, _) => _UndoDialog(available: can, paid: true),
    );
    return r ?? 0;
  }

  static Future<int> _pickFree(BuildContext context, int can) async {
    if (can == 1) return 1;
    final r = await showGeneralDialog<int>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'undo',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      pageBuilder: (_, _, _) => _UndoDialog(available: can, paid: false),
    );
    return r ?? 0;
  }
}

class _UndoDialog extends StatefulWidget {
  const _UndoDialog({required this.available, required this.paid});
  final int available;

  /// False for ad-free players: steps are free.
  final bool paid;

  @override
  State<_UndoDialog> createState() => _UndoDialogState();
}

class _UndoDialogState extends State<_UndoDialog> {
  bool _busy = false;
  String? _error;
  int _watched = 0;
  int _target = 0;

  /// Plays [steps] rewarded ads in a row; grants the steps only when all of
  /// them were watched.
  Future<void> _ads(int steps) async {
    setState(() {
      _busy = true;
      _error = null;
      _target = steps;
      _watched = 0;
    });
    for (var k = 0; k < steps; k++) {
      final ok = await AdsService.showRewarded(reason: 'undo');
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _busy = false;
          _error = tr('shop.no_ad');
        });
        return;
      }
      setState(() => _watched = k + 1);
    }
    Navigator.of(context).pop(steps);
  }

  Future<void> _coins(int steps) async {
    setState(() => _busy = true);
    final ok = await Rewards.spend(
      steps * UndoOffer.pricePerStep,
      reason: 'undo',
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(steps);
    } else {
      setState(() {
        _busy = false;
        _error = tr('offer.not_enough');
      });
    }
  }

  Widget _row(int steps) {
    final arrows = '↩' * steps;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$arrows  ${tr(steps == 1 ? 'undo.step_one' : 'undo.steps', {'n': steps})}',
              style: const TextStyle(
                color: Pal.text,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          if (!widget.paid)
            PremiumButton(
              key: ValueKey('undo_free_$steps'),
              label: tr('undo.go'),
              compact: true,
              onTap: () => Navigator.of(context).pop(steps),
            )
          else ...[
            if (AdsService.featuresOn)
              PremiumButton(
                key: ValueKey('undo_ads_$steps'),
                label: tr(steps == 1 ? 'undo.ad_one' : 'undo.ads', {'n': steps}),
                icon: Icons.ondemand_video_rounded,
                compact: true,
                color: const Color(0xFF4DA8FF),
                onTap: _busy ? null : () => _ads(steps),
              ),
            const SizedBox(width: 6),
            PremiumButton(
              key: ValueKey('undo_coins_$steps'),
              label: '${steps * UndoOffer.pricePerStep} 🪙',
              compact: true,
              onTap: _busy || Rewards.balance < steps * UndoOffer.pricePerStep
                  ? null
                  : () => _coins(steps),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Material(
          color: Colors.transparent,
          child: GlassCard(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
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
                  const Text('↩️', style: TextStyle(fontSize: 44)),
                  const SizedBox(height: 6),
                  Text(
                    tr('undo.title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Pal.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr(widget.paid ? 'undo.msg' : 'undo.msg_free'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Pal.textDim, fontSize: 14),
                  ),
                  for (var s = 1; s <= widget.available; s++) _row(s),
                  if (_busy && _target > 1) ...[
                    const SizedBox(height: 10),
                    Text(
                      tr('undo.progress', {'done': _watched, 'n': _target}),
                      style: const TextStyle(color: Pal.gold, fontSize: 13),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Pal.danger, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(0),
                    child: Text(
                      tr('common.cancel'),
                      style: const TextStyle(
                        color: Pal.textDim,
                        fontWeight: FontWeight.w700,
                      ),
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
