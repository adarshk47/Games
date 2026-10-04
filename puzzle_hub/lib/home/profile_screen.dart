import 'dart:async';

import 'package:flutter/material.dart';

import '../core/account/account_service.dart';
import '../core/account/auth_screens.dart';
import '../core/cloud/cloud_auth.dart';
import '../core/cloud/cloud_service.dart';
import '../core/cloud/leaderboard_screen.dart';
import '../core/cloud/referral_service.dart';
import '../core/cloud/sync_service.dart';
import '../core/i18n/i18n.dart';
import '../core/rewards.dart';
import '../core/storage.dart';
import '../core/ui/ui.dart';
import '../games/registry.dart';

/// Account, cloud, coins and per-game records (pushed full screen).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => GameScaffold(
        title: tr('home.nav.profile'),
        tint: const Color(0xFFFF8FB8),
        body: const _ProfileBody(),
      );
}

/// Same content as [ProfileScreen] for the bottom-navigation tab: body only,
/// no Scaffold / back button.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) => const _ProfileBody(showTitle: true);
}

class _ProfileBody extends StatefulWidget {
  const _ProfileBody({this.showTitle = false});
  final bool showTitle;

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  final a = AccountService.I;
  StreamSubscription<RewardEvent>? _sub;
  late final Listenable _changes = Listenable.merge([
    a,
    Rewards.coins,
    CloudAuth.I.user,
    SyncService.I.lastSynced,
    SyncService.I.syncing,
  ]);

  @override
  void initState() {
    super.initState();
    // Records change while this tab stays alive in the home IndexedStack.
    _sub = Rewards.events.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<String?> _askPin(String title) async {
    var pin = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Dialog(
          backgroundColor: const Color(0xFF1B1245),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: const TextStyle(color: Pal.text, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              PinPad(
                pin: pin,
                onChanged: (v) {
                  set(() => pin = v);
                  if (v.length == kPinLength) Navigator.of(ctx).pop(v);
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<String?> _askText(String title, {String initial = '', String? hint, bool obscure = false, int? maxLength}) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          maxLength: maxLength,
          autofocus: true,
          obscureText: obscure,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('common.cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(tr('common.ok'))),
        ],
      ),
    );
  }

  Future<bool> _confirm(String title, String text, String yes) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('common.no'))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(yes)),
          ],
        ),
      ) ==
      true;

  // ---------------------------------------------------------------- account

  Future<void> _changePin() async {
    final old = await _askPin(tr('home.pin.old'));
    if (old == null) return;
    if (!a.verifyPin(old)) return _snack(tr('home.pin.wrong'));
    final n1 = await _askPin(tr('home.pin.new'));
    if (n1 == null) return;
    final n2 = await _askPin(tr('home.pin.new_again'));
    if (n2 != n1) return _snack(tr('home.pin.mismatch'));
    await a.changePin(old, n1);
    _snack(tr('home.pin.changed'));
  }

  Future<void> _setPin() async {
    final n1 = await _askPin(tr('home.pin.new_lock'));
    if (n1 == null) return;
    final n2 = await _askPin(tr('home.pin.new_again'));
    if (n2 != n1) return _snack(tr('home.pin.mismatch'));
    await a.setPin(n1);
    _snack(tr('home.pin.lock_on'));
  }

  Future<void> _removePin() async {
    final pin = await _askPin(tr('home.pin.confirm'));
    if (pin == null) return;
    if (!a.verifyPin(pin)) return _snack(tr('home.pin.wrong'));
    await a.removePin();
    _snack(tr('home.pin.lock_off'));
  }

  Future<void> _rename() async {
    final v = await _askText(tr('home.rename'), initial: a.name, maxLength: 20);
    if (v != null && v.trim().length >= 2) {
      await a.rename(v);
      SyncService.I.schedule();
    }
  }

  Future<void> _delete() async {
    final cloud = CloudService.available && CloudAuth.I.user.value != null;
    final ok = await _confirm(
      tr('home.delete.title'),
      '${tr('home.delete.body')}'
          '${cloud ? '\n\n${tr('home.delete.body_cloud')}' : ''}'
          '${!cloud && a.cloudUid != null ? '\n\n${tr('home.delete.body_signin')}' : ''}',
      tr('home.delete.yes'),
    );
    if (ok != true) return;
    if (a.hasPin) {
      final pin = await _askPin(tr('home.pin.confirm'));
      if (pin == null || !a.verifyPin(pin)) return _snack(tr('home.pin.wrong'));
    } else if (!await _confirm(tr('home.delete.sure'), tr('home.delete.cant_undo'), tr('home.delete.btn'))) {
      return;
    }
    if (cloud) {
      var out = await CloudAuth.I.deleteCloudAccount();
      if (out == DeleteOutcome.needsReauth) {
        String? password;
        if (!(CloudAuth.I.user.value?.isGoogle ?? false)) {
          password = await _askText(tr('home.password.title'), hint: tr('home.password.hint'), obscure: true);
          if (password == null) return;
        }
        final err = await CloudAuth.I.reauthenticate(password: password);
        if (err != null) {
          if (err.isNotEmpty) _snack(err);
          return;
        }
        out = await CloudAuth.I.deleteCloudAccount();
      }
      if (out != DeleteOutcome.done) {
        return _snack(tr('home.delete.cloud_failed'));
      }
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    await a.deleteAccount();
    Rewards.coins.value = 0;
  }

  // ------------------------------------------------------------------ cloud

  Future<void> _syncNow() async {
    await SyncService.I.syncNow();
    if (!mounted) return;
    final err = SyncService.I.lastError.value;
    _snack(err ?? tr('home.synced'));
  }

  Future<void> _signOut() async {
    if (!await _confirm(tr('home.signout.title'), tr('home.signout.body'), tr('home.signout.btn'))) return;
    await CloudAuth.I.signOut();
  }

  static String _ago(DateTime? t) {
    if (t == null) return tr('home.ago.never');
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return tr('home.ago.just_now');
    if (d.inMinutes < 60) return tr('home.ago.min', {'n': d.inMinutes});
    if (d.inHours < 24) return tr('home.ago.hours', {'n': d.inHours});
    return tr('home.ago.days', {'n': d.inDays});
  }

  Widget _cloudCard() {
    if (!CloudService.available) {
      return const GlassCard(blur: 0, child: CloudPendingNote());
    }
    final u = CloudAuth.I.user.value;
    if (u == null) {
      return GlassCard(
        blur: 0,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('home.cloud.backup_title'), style: const TextStyle(color: Pal.text, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(tr('home.cloud.backup_body'),
              style: const TextStyle(color: Pal.textDim, fontSize: 13, height: 1.35)),
          const SizedBox(height: 14),
          const CloudSignInPanel(),
        ]),
      );
    }
    final syncing = SyncService.I.syncing.value;
    return GlassCard(
      blur: 0,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(u.isGoogle ? Icons.g_mobiledata_rounded : Icons.email_rounded, color: Pal.success, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.email ?? u.name ?? tr('home.cloud.signed_in'),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800, fontSize: 15)),
              Text(tr('home.cloud.last_synced', {'time': _ago(SyncService.I.lastSynced.value)}), style: const TextStyle(color: Pal.textDim, fontSize: 12)),
            ]),
          ),
        ]),
        if (u.needsVerification) ...[
          const SizedBox(height: 10),
          Text(tr('home.cloud.not_verified'), style: TextStyle(color: Pal.gold.withValues(alpha: 0.9), fontSize: 13)),
          Wrap(spacing: 4, children: [
            TextButton(
              onPressed: () async => _snack(await CloudAuth.I.sendVerification() ?? tr('home.cloud.verification_sent')),
              child: Text(tr('home.cloud.resend'), style: const TextStyle(color: Pal.gold)),
            ),
            TextButton(
              onPressed: () async {
                await CloudAuth.I.reload();
                if (CloudAuth.I.user.value?.emailVerified ?? false) _snack(tr('home.cloud.verified'));
              },
              child: Text(tr('home.cloud.i_verified'), style: const TextStyle(color: Pal.gold)),
            ),
          ]),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: PremiumButton(
              label: syncing ? tr('home.cloud.syncing') : tr('home.cloud.sync_now'),
              icon: Icons.sync_rounded,
              compact: true,
              color: const Color(0xFF22B07D),
              onTap: syncing ? null : _syncNow,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PremiumButton(
              label: tr('home.signout.btn'),
              icon: Icons.logout_rounded,
              compact: true,
              color: const Color(0xFF7C5CFF),
              onTap: _signOut,
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _actions() {
    final signedIn = CloudService.available && CloudAuth.I.user.value != null;
    return Row(children: [
      Expanded(
        child: GlassCard(
          blur: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
          child: Column(children: [
            const Text('🏆', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(tr('home.leaderboard'), style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: GlassCard(
          blur: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          onTap: () {
            if (!CloudService.available) return _snack(tr('account.cloud_pending'));
            if (!signedIn) return _snack(tr('home.invite.signin_first'));
            ReferralService.I.share();
          },
          child: Column(children: [
            const Text('🎁', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(tr('home.invite.title'), style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800)),
            Text(tr('home.invite.bonus', {'coins': ReferralService.inviterBonus}), style: const TextStyle(color: Pal.gold, fontSize: 11)),
          ]),
        ),
      ),
    ]);
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: _changes, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final totalWins = games.fold<int>(0, (s, g) => s + Rewards.wins(g.id));
    final totalPlays = games.fold<int>(0, (s, g) => s + Rewards.plays(g.id));
    return ListView(padding: EdgeInsets.fromLTRB(18, widget.showTitle ? 14 : 8, 18, 28), children: [
      if (widget.showTitle)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 0, 14),
          child: Text(tr('home.nav.profile'), style: const TextStyle(color: Pal.text, fontSize: 26, fontWeight: FontWeight.w900)),
        ),
      GlassCard(
        glow: Pal.gold,
        child: Row(children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Pal.goldDeep,
            child: Text(a.name.isEmpty ? '?' : a.name[0].toUpperCase(),
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.name, style: const TextStyle(color: Pal.text, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(tr('home.profile.summary', {'plays': totalPlays, 'wins': totalWins}), style: const TextStyle(color: Pal.textDim, fontSize: 13)),
            ]),
          ),
          const CoinPill(),
        ]),
      ),
      const SizedBox(height: 18),
      _Head(tr('home.profile.cloud_account')),
      _cloudCard(),
      const SizedBox(height: 12),
      _actions(),
      const SizedBox(height: 18),
      _Head(tr('home.profile.records')),
      for (final g in games)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            blur: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Text(g.emoji ?? '🎮', style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(g.title, style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(
                    tr('home.profile.record_line',
                        {'plays': Rewards.plays(g.id), 'wins': Rewards.wins(g.id), 'levels': Rewards.levels(g.id)}),
                    style: const TextStyle(color: Pal.textDim, fontSize: 12),
                  ),
                ]),
              ),
              if (Rewards.best(g.id) > 0)
                Column(children: [
                  Text(tr('common.best').toUpperCase(), style: const TextStyle(color: Pal.textDim, fontSize: 9, letterSpacing: 1)),
                  Text('${Rewards.best(g.id)}', style: const TextStyle(color: Pal.gold, fontWeight: FontWeight.w900, fontSize: 18)),
                ]),
            ]),
          ),
        ),
      const SizedBox(height: 10),
      _Head(tr('home.profile.account')),
      GlassCard(
        blur: 0,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: [
          ListTile(
            leading: const Icon(Icons.person_rounded, color: Pal.text),
            title: Text(tr('home.rename'), style: const TextStyle(color: Pal.text)),
            subtitle: Text(a.name, style: const TextStyle(color: Pal.textDim)),
            onTap: _rename,
          ),
          if (a.hasPin) ...[
            FutureBuilder<bool>(
              future: a.biometricAvailable(),
              builder: (_, snap) => SwitchListTile(
                secondary: const Icon(Icons.fingerprint_rounded, color: Pal.gold),
                title: Text(tr('home.fingerprint.title'), style: const TextStyle(color: Pal.text)),
                subtitle: Text(snap.data == false ? tr('home.fingerprint.unavailable') : tr('home.fingerprint.on'),
                    style: const TextStyle(color: Pal.textDim, fontSize: 12)),
                value: a.biometricEnabled,
                activeThumbColor: Pal.gold,
                onChanged: snap.data == true ? (v) => a.setBiometric(v) : null,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.pin_rounded, color: Pal.text),
              title: Text(tr('home.pin.change'), style: const TextStyle(color: Pal.text)),
              onTap: _changePin,
            ),
            ListTile(
              leading: const Icon(Icons.lock_open_rounded, color: Pal.text),
              title: Text(tr('home.pin.remove'), style: const TextStyle(color: Pal.text)),
              onTap: _removePin,
            ),
            ListTile(
              leading: const Icon(Icons.lock_rounded, color: Pal.text),
              title: Text(tr('home.lock_now'), style: const TextStyle(color: Pal.text)),
              onTap: () {
                SyncService.I.syncNow();
                Navigator.of(context).popUntil((r) => r.isFirst);
                a.lock();
              },
            ),
          ] else
            ListTile(
              leading: const Icon(Icons.pin_rounded, color: Pal.text),
              title: Text(tr('home.pin.set'), style: const TextStyle(color: Pal.text)),
              subtitle: Text(tr('home.pin.set_sub'), style: const TextStyle(color: Pal.textDim, fontSize: 12)),
              onTap: _setPin,
            ),
          ListTile(
            leading: const Icon(Icons.delete_forever_rounded, color: Pal.danger),
            title: Text(tr('home.delete.menu'), style: const TextStyle(color: Pal.danger)),
            onTap: _delete,
          ),
        ]),
      ),
      const SizedBox(height: 14),
      Center(
        child: Text(tr('home.profile.coins_earned', {'coins': Storage.getInt('coins.earned')}), style: const TextStyle(color: Pal.textDim, fontSize: 12)),
      ),
    ]);
  }
}

class _Head extends StatelessWidget {
  const _Head(this.t);
  final String t;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
        child: Text(t, style: const TextStyle(color: Pal.textDim, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1)),
      );
}
