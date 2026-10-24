import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../account/account_service.dart';
import '../cloud/cloud_auth.dart';
import '../cloud/referral_service.dart';
import '../i18n/i18n.dart';
import '../ui/ui.dart';

/// "Challenge your friends": shows a score card and shares it as an image
/// (WhatsApp, Instagram, any app) with a challenge text and the Play Store
/// link (with the player's invite code when signed in).
class ScoreShare {
  ScoreShare._();

  /// Opens the card preview with a Share button.
  ///   [game] e.g. "Block Puzzle", [emoji] the game's emoji,
  ///   [value] the big number / text ("12 450", "21–24 yrs"),
  ///   [label] what it is ("Best score", "Brain age"), [color] accent.
  static Future<void> show(
    BuildContext context, {
    required String game,
    required String emoji,
    required String value,
    required String label,
    Color color = Pal.gold,
    String? extra,
  }) {
    final key = GlobalKey();
    var busy = false;
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            RepaintBoundary(
              key: key,
              child: ScoreCard(game: game, emoji: emoji, value: value, label: label, color: color, extra: extra),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: PremiumButton(
                  key: const ValueKey('score_share_go'),
                  label: busy ? '…' : tr('share.button'),
                  icon: Icons.share_rounded,
                  onTap: busy
                      ? null
                      : () async {
                          setS(() => busy = true);
                          await _share(key, game: game, value: value, label: label);
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(tr('common.cancel'), style: const TextStyle(color: Colors.white70)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  /// Shares a plain invite text (WhatsApp etc.) with the Play Store link.
  static Future<void> invite(String text) async {
    try {
      await SharePlus.instance.share(ShareParams(text: '$text\n${_link()}'));
    } catch (e) {
      debugPrint('invite share: $e');
    }
  }

  static String _link() {
    final uid = CloudAuth.I.user.value?.uid;
    return uid == null ? 'https://play.google.com/store/apps/details?id=${ReferralService.packageId}' : ReferralService.inviteLink(uid);
  }

  static Future<void> _share(GlobalKey key, {required String game, required String value, required String label}) async {
    final text = tr('share.text', {'game': game, 'label': label, 'value': value, 'link': _link()});
    try {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await boundary.toImage(pixelRatio: 3);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      await SharePlus.instance.share(ShareParams(
        text: text,
        files: [XFile.fromData(bytes!.buffer.asUint8List(), mimeType: 'image/png', name: 'master_g_score.png')],
      ));
    } catch (e) {
      debugPrint('score share: $e');
      // Fall back to text only.
      await SharePlus.instance.share(ShareParams(text: text));
    }
  }
}

/// The shareable card (also what the screenshot shows).
class ScoreCard extends StatelessWidget {
  const ScoreCard({super.key, required this.game, required this.emoji, required this.value, required this.label, this.color = Pal.gold, this.extra});
  final String game, emoji, value, label;
  final Color color;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    final name = AccountService.I.name.trim();
    return Container(
      width: 320,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF2A1F63), Color.lerp(const Color(0xFF140E38), color, 0.25)!],
        ),
        border: Border.all(color: color.withValues(alpha: 0.8), width: 2),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 24)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Text('Master G', style: TextStyle(color: Pal.gold, fontWeight: FontWeight.w900, fontSize: 18)),
          const Spacer(),
          Text(tr('share.challenge_badge'), style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 14),
        Text(emoji, style: const TextStyle(fontSize: 54)),
        const SizedBox(height: 4),
        Text(game, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)),
        FittedBox(
          child: Text(value, style: TextStyle(color: color, fontSize: 46, fontWeight: FontWeight.w900, height: 1.1)),
        ),
        if (extra != null) ...[
          const SizedBox(height: 4),
          Text(extra!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
        ],
        const SizedBox(height: 14),
        Text(
          name.isEmpty ? tr('share.can_you_beat') : tr('share.can_you_beat_name', {'name': name}),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(tr('share.get_app'), style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ]),
    );
  }
}
