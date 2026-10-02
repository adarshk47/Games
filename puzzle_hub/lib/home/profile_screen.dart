import 'package:flutter/material.dart';

import '../core/account/account_service.dart';
import '../core/account/auth_screens.dart';
import '../core/rewards.dart';
import '../core/storage.dart';
import '../core/ui/ui.dart';
import '../games/registry.dart';

/// Account, coins and per-game records of the signed-in user.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final a = AccountService.I;

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

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

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

  Future<void> _rename() async {
    final c = TextEditingController(text: a.name);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Naam badlein'),
        content: TextField(controller: c, maxLength: 20, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Save')),
        ],
      ),
    );
    if (v != null && v.trim().length >= 2) await a.rename(v);
    if (mounted) setState(() {});
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Account delete karein?'),
        content: const Text('Aapka naam, PIN, coins aur saare games ka record hamesha ke liye mit jayega.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nahi')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Haan, delete')),
        ],
      ),
    );
    if (ok != true) return;
    final pin = await _askPin('PIN se confirm karein');
    if (pin == null || !a.verifyPin(pin)) return _snack('Galat PIN');
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    await a.deleteAccount();
    Rewards.coins.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    final totalWins = games.fold<int>(0, (s, g) => s + Rewards.wins(g.id));
    final totalPlays = games.fold<int>(0, (s, g) => s + Rewards.plays(g.id));
    return GameScaffold(
      title: 'Profile',
      tint: const Color(0xFFFF8FB8),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 28), children: [
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
            FutureBuilder<bool>(
              future: a.biometricAvailable(),
              builder: (_, snap) => SwitchListTile(
                secondary: const Icon(Icons.fingerprint_rounded, color: Pal.gold),
                title: const Text('Fingerprint unlock', style: TextStyle(color: Pal.text)),
                subtitle: Text(snap.data == false ? 'Is phone mein fingerprint set nahi hai' : 'PIN ke saath fingerprint se bhi khulega',
                    style: const TextStyle(color: Pal.textDim, fontSize: 12)),
                value: a.biometricEnabled,
                activeThumbColor: Pal.gold,
                onChanged: snap.data == true
                    ? (v) async {
                        await a.setBiometric(v);
                        setState(() {});
                      }
                    : null,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.pin_rounded, color: Pal.text),
              title: const Text('PIN badlein', style: TextStyle(color: Pal.text)),
              onTap: _changePin,
            ),
            ListTile(
              leading: const Icon(Icons.lock_rounded, color: Pal.text),
              title: const Text('Lock karein', style: TextStyle(color: Pal.text)),
              onTap: () {
                Navigator.of(context).popUntil((r) => r.isFirst);
                a.lock();
              },
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
          child: Text('Total coins kamaye: ${Storage.getInt('coins.earned')} 🪙',
              style: const TextStyle(color: Pal.textDim, fontSize: 12)),
        ),
      ]),
    );
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
