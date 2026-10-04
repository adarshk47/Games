import 'dart:async';

import 'package:flutter/material.dart';

import '../core/account/account_service.dart';
import '../core/account/auth_screens.dart';
import '../core/cloud/cloud_auth.dart';
import '../core/cloud/cloud_service.dart';
import '../core/cloud/leaderboard_screen.dart';
import '../core/cloud/referral_service.dart';
import '../core/cloud/sync_service.dart';
import '../core/rewards.dart';
import '../core/storage.dart';
import '../core/ui/ui.dart';
import '../games/registry.dart';

/// Account, cloud, coins and per-game records (pushed full screen).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => const GameScaffold(
        title: 'Profile',
        tint: Color(0xFFFF8FB8),
        body: _ProfileBody(),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('OK')),
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
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nahi')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(yes)),
          ],
        ),
      ) ==
      true;

  // ---------------------------------------------------------------- account

  Future<void> _changePin() async {
    final old = await _askPin('Purana PIN');
    if (old == null) return;
    if (!a.verifyPin(old)) return _snack('Galat PIN');
    final n1 = await _askPin('Naya PIN');
    if (n1 == null) return;
    final n2 = await _askPin('Naya PIN dobara');
    if (n2 != n1) return _snack('PIN match nahi hua');
    await a.changePin(old, n1);
    _snack('PIN badal gaya ✅');
  }

  Future<void> _setPin() async {
    final n1 = await _askPin('Naya PIN (app lock)');
    if (n1 == null) return;
    final n2 = await _askPin('Naya PIN dobara');
    if (n2 != n1) return _snack('PIN match nahi hua');
    await a.setPin(n1);
    _snack('PIN lock on ✅');
  }

  Future<void> _removePin() async {
    final pin = await _askPin('PIN se confirm karein');
    if (pin == null) return;
    if (!a.verifyPin(pin)) return _snack('Galat PIN');
    await a.removePin();
    _snack('PIN lock off');
  }

  Future<void> _rename() async {
    final v = await _askText('Naam badlein', initial: a.name, maxLength: 20);
    if (v != null && v.trim().length >= 2) {
      await a.rename(v);
      SyncService.I.schedule();
    }
  }

  Future<void> _delete() async {
    final cloud = CloudService.available && CloudAuth.I.user.value != null;
    final ok = await _confirm(
      'Account delete karein?',
      'Aapka naam, PIN, coins aur saare games ka record hamesha ke liye mit jayega.'
          '${cloud ? '\n\nCloud backup, leaderboard scores aur aapka online account bhi delete ho jayega.' : ''}'
          '${!cloud && a.cloudUid != null ? '\n\nCloud data delete karne ke liye pehle sign in karein.' : ''}',
      'Haan, delete',
    );
    if (ok != true) return;
    if (a.hasPin) {
      final pin = await _askPin('PIN se confirm karein');
      if (pin == null || !a.verifyPin(pin)) return _snack('Galat PIN');
    } else if (!await _confirm('Pakka?', 'Yeh wapas nahi hoga.', 'Delete')) {
      return;
    }
    if (cloud) {
      var out = await CloudAuth.I.deleteCloudAccount();
      if (out == DeleteOutcome.needsReauth) {
        String? password;
        if (!(CloudAuth.I.user.value?.isGoogle ?? false)) {
          password = await _askText('Password daalein', hint: 'Account password', obscure: true);
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
        return _snack('Cloud account delete nahi hua. Internet check karke dobara try karein.');
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
    _snack(err ?? 'Synced ✅');
  }

  Future<void> _signOut() async {
    if (!await _confirm('Sign out?', 'Progress is kept on this phone. Sign in again any time to sync.', 'Sign out')) return;
    await CloudAuth.I.signOut();
  }

  static String _ago(DateTime? t) {
    if (t == null) return 'never';
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  Widget _cloudCard() {
    if (!CloudService.available) {
      return const GlassCard(blur: 0, child: CloudPendingNote());
    }
    final u = CloudAuth.I.user.value;
    if (u == null) {
      return const GlassCard(
        blur: 0,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Back up your progress', style: TextStyle(color: Pal.text, fontSize: 17, fontWeight: FontWeight.w900)),
          SizedBox(height: 4),
          Text('Sign in to save coins & records in the cloud, play on any phone and join the leaderboards. Your local progress is kept.',
              style: TextStyle(color: Pal.textDim, fontSize: 13, height: 1.35)),
          SizedBox(height: 14),
          CloudSignInPanel(),
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
              Text(u.email ?? u.name ?? 'Signed in',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800, fontSize: 15)),
              Text('Last synced: ${_ago(SyncService.I.lastSynced.value)}', style: const TextStyle(color: Pal.textDim, fontSize: 12)),
            ]),
          ),
        ]),
        if (u.needsVerification) ...[
          const SizedBox(height: 10),
          Text('Email not verified yet.', style: TextStyle(color: Pal.gold.withValues(alpha: 0.9), fontSize: 13)),
          Wrap(spacing: 4, children: [
            TextButton(
              onPressed: () async => _snack(await CloudAuth.I.sendVerification() ?? 'Verification email sent'),
              child: const Text('Resend link', style: TextStyle(color: Pal.gold)),
            ),
            TextButton(
              onPressed: () async {
                await CloudAuth.I.reload();
                if (CloudAuth.I.user.value?.emailVerified ?? false) _snack('Email verified ✅');
              },
              child: const Text("I've verified", style: TextStyle(color: Pal.gold)),
            ),
          ]),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: PremiumButton(
              label: syncing ? 'Syncing...' : 'Sync now',
              icon: Icons.sync_rounded,
              compact: true,
              color: const Color(0xFF22B07D),
              onTap: syncing ? null : _syncNow,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PremiumButton(
              label: 'Sign out',
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
          child: const Column(children: [
            Text('🏆', style: TextStyle(fontSize: 28)),
            SizedBox(height: 4),
            Text('Leaderboard', style: TextStyle(color: Pal.text, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: GlassCard(
          blur: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          onTap: () {
            if (!CloudService.available) return _snack(CloudService.pendingMessage);
            if (!signedIn) return _snack('Sign in first to invite friends.');
            ReferralService.I.share();
          },
          child: Column(children: [
            const Text('🎁', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            const Text('Invite friends', style: TextStyle(color: Pal.text, fontWeight: FontWeight.w800)),
            Text('+${ReferralService.inviterBonus} 🪙 each', style: const TextStyle(color: Pal.gold, fontSize: 11)),
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
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 0, 14),
          child: Text('Profile', style: TextStyle(color: Pal.text, fontSize: 26, fontWeight: FontWeight.w900)),
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
              Text('$totalPlays games khele  •  $totalWins jeete', style: const TextStyle(color: Pal.textDim, fontSize: 13)),
            ]),
          ),
          const CoinPill(),
        ]),
      ),
      const SizedBox(height: 18),
      const _Head('Cloud account'),
      _cloudCard(),
      const SizedBox(height: 12),
      _actions(),
      const SizedBox(height: 18),
      const _Head('Games ka record'),
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
                    'Khele ${Rewards.plays(g.id)}  •  Jeete ${Rewards.wins(g.id)}  •  Levels ${Rewards.levels(g.id)}',
                    style: const TextStyle(color: Pal.textDim, fontSize: 12),
                  ),
                ]),
              ),
              if (Rewards.best(g.id) > 0)
                Column(children: [
                  const Text('BEST', style: TextStyle(color: Pal.textDim, fontSize: 9, letterSpacing: 1)),
                  Text('${Rewards.best(g.id)}', style: const TextStyle(color: Pal.gold, fontWeight: FontWeight.w900, fontSize: 18)),
                ]),
            ]),
          ),
        ),
      const SizedBox(height: 10),
      const _Head('Account'),
      GlassCard(
        blur: 0,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: [
          ListTile(
            leading: const Icon(Icons.person_rounded, color: Pal.text),
            title: const Text('Naam badlein', style: TextStyle(color: Pal.text)),
            subtitle: Text(a.name, style: const TextStyle(color: Pal.textDim)),
            onTap: _rename,
          ),
          if (a.hasPin) ...[
            FutureBuilder<bool>(
              future: a.biometricAvailable(),
              builder: (_, snap) => SwitchListTile(
                secondary: const Icon(Icons.fingerprint_rounded, color: Pal.gold),
                title: const Text('Fingerprint unlock', style: TextStyle(color: Pal.text)),
                subtitle: Text(snap.data == false ? 'Is phone mein fingerprint set nahi hai' : 'PIN ke saath fingerprint se bhi khulega',
                    style: const TextStyle(color: Pal.textDim, fontSize: 12)),
                value: a.biometricEnabled,
                activeThumbColor: Pal.gold,
                onChanged: snap.data == true ? (v) => a.setBiometric(v) : null,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.pin_rounded, color: Pal.text),
              title: const Text('PIN badlein', style: TextStyle(color: Pal.text)),
              onTap: _changePin,
            ),
            ListTile(
              leading: const Icon(Icons.lock_open_rounded, color: Pal.text),
              title: const Text('PIN lock hatayein', style: TextStyle(color: Pal.text)),
              onTap: _removePin,
            ),
            ListTile(
              leading: const Icon(Icons.lock_rounded, color: Pal.text),
              title: const Text('Lock karein', style: TextStyle(color: Pal.text)),
              onTap: () {
                SyncService.I.syncNow();
                Navigator.of(context).popUntil((r) => r.isFirst);
                a.lock();
              },
            ),
          ] else
            ListTile(
              leading: const Icon(Icons.pin_rounded, color: Pal.text),
              title: const Text('PIN lock lagayein', style: TextStyle(color: Pal.text)),
              subtitle: const Text('Optional: app kholne par PIN / fingerprint', style: TextStyle(color: Pal.textDim, fontSize: 12)),
              onTap: _setPin,
            ),
          ListTile(
            leading: const Icon(Icons.delete_forever_rounded, color: Pal.danger),
            title: const Text('Account delete karein', style: TextStyle(color: Pal.danger)),
            onTap: _delete,
          ),
        ]),
      ),
      const SizedBox(height: 14),
      Center(
        child: Text('Total coins kamaye: ${Storage.getInt('coins.earned')} 🪙', style: const TextStyle(color: Pal.textDim, fontSize: 12)),
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
