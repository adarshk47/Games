import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../rewards.dart';
import '../ui/ui.dart';
import 'account_service.dart';

const int kPinLength = 4;

/// Shows onboarding, lock screen or [home] depending on account state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.home});
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AccountService.I,
      builder: (context, _) {
        final a = AccountService.I;
        if (a.loggedIn) return home;
        return a.hasAccount ? const LockScreen() : const RegisterScreen();
      },
    );
  }
}

/// 4-dot PIN entry with a glossy keypad.
class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.pin,
    required this.onChanged,
    this.error = false,
    this.extraKey,
  });
  final String pin;
  final ValueChanged<String> onChanged;
  final bool error;

  /// Optional widget for the bottom-left key (e.g. a fingerprint button).
  final Widget? extraKey;

  @override
  Widget build(BuildContext context) {
    Widget key(Widget child, VoidCallback? onTap) => SizedBox(
      width: 76,
      height: 64,
      child: onTap == null
          ? Center(child: child)
          : Pressable(
              onTap: onTap,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0x33FFFFFF), Color(0x0FFFFFFF)],
                  ),
                  border: Border.all(color: Pal.glassBorder),
                ),
                child: child,
              ),
            ),
    );

    Widget digit(String d) => key(
      Text(
        d,
        style: const TextStyle(
          color: Pal.text,
          fontSize: 26,
          fontWeight: FontWeight.w700,
        ),
      ),
      () {
        if (pin.length < kPinLength) onChanged(pin + d);
      },
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < kPinLength; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.symmetric(horizontal: 9),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < pin.length
                          ? (error ? Pal.danger : Pal.gold)
                          : Colors.transparent,
                      border: Border.all(
                        color: error ? Pal.danger : Pal.textDim,
                        width: 2,
                      ),
                      boxShadow: i < pin.length
                          ? [
                              BoxShadow(
                                color: (error ? Pal.danger : Pal.gold)
                                    .withValues(alpha: 0.6),
                                blurRadius: 12,
                              ),
                            ]
                          : null,
                    ),
                  ),
              ],
            )
            .animate(target: error ? 1 : 0)
            .shakeX(hz: 5, amount: 8, duration: 400.ms),
        const SizedBox(height: 26),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final d in row)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: digit(d),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: key(extraKey ?? const SizedBox(), null),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: digit('0'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: key(
                  const Icon(Icons.backspace_outlined, color: Pal.text),
                  () {
                    if (pin.isNotEmpty) {
                      onChanged(pin.substring(0, pin.length - 1));
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  bool _error = false;

  @override
  void initState() {
    super.initState();
    if (AccountService.I.biometricEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bio());
    }
  }

  Future<void> _bio() async {
    if (await AccountService.I.loginWithBiometric()) Rewards.reload();
  }

  void _change(String v) {
    setState(() {
      _pin = v;
      _error = false;
    });
    if (v.length == kPinLength) {
      if (AccountService.I.loginWithPin(v)) {
        Rewards.reload();
      } else {
        setState(() => _error = true);
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) {
            setState(() {
              _pin = '';
              _error = false;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = AccountService.I.name;
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🧩', style: TextStyle(fontSize: 56))
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .moveY(
                        begin: -5,
                        end: 5,
                        duration: 1400.ms,
                        curve: Curves.easeInOut,
                      ),
                  const SizedBox(height: 10),
                  const Text(
                    'Welcome back,',
                    style: TextStyle(color: Pal.textDim, fontSize: 18),
                  ).animate().fadeIn(),
                  ShaderMask(
                    shaderCallback: (r) => const LinearGradient(
                      colors: [Pal.gold, Color(0xFFFF8FB8)],
                    ).createShader(r),
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ).animate(delay: 150.ms).fadeIn().slideY(begin: 0.3, end: 0),
                  const SizedBox(height: 8),
                  Text(
                    _error
                        ? 'Galat PIN, dobara try karein'
                        : 'Apna PIN daalein',
                    style: TextStyle(
                      color: _error ? Pal.danger : Pal.textDim,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 22),
                  PinPad(
                    pin: _pin,
                    error: _error,
                    onChanged: _change,
                    extraKey: AccountService.I.biometricEnabled
                        ? Pressable(
                            onTap: _bio,
                            child: const Icon(
                              Icons.fingerprint_rounded,
                              color: Pal.gold,
                              size: 38,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () async {
                      await AccountService.I.loginWithoutPin(name);
                      Rewards.reload();
                    },
                    icon: const Icon(Icons.flash_on_rounded, color: Pal.gold, size: 20),
                    label: const Text(
                      'Play Without PIN',
                      style: TextStyle(
                        color: Pal.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
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

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  int _step = 0; // 0 name, 1 pin, 2 confirm pin
  String _pin = '';
  String _first = '';
  bool _bio = false;
  bool _bioAvail = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    AccountService.I.biometricAvailable().then((v) {
      if (mounted) {
        setState(() {
          _bioAvail = v;
          _bio = v;
        });
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pinChanged(String v) async {
    setState(() {
      _pin = v;
      _msg = null;
    });
    if (v.length != kPinLength) return;
    if (_step == 1) {
      await Future.delayed(const Duration(milliseconds: 200));
      setState(() {
        _first = v;
        _pin = '';
        _step = 2;
      });
    } else if (_step == 2) {
      if (v == _first) {
        await AccountService.I.register(
          name: _name.text,
          pin: v,
          useBiometric: _bio,
        );
        Rewards.reload();
      } else {
        setState(() => _msg = 'PIN match nahi hua, dobara daalein');
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) {
          setState(() {
            _pin = '';
            _first = '';
            _step = 1;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      0 => 'Welcome! 👋',
      1 => 'PIN banayein',
      _ => 'PIN confirm karein',
    };
    final sub = switch (_step) {
      0 => 'Apna naam batayein, hum aapka sab kuch is phone mein hi save rakhenge.',
      1 => 'Hello ${_name.text.trim()}! 4 ank ka PIN chunein.',
      _ => 'Wahi PIN dobara daalein.',
    };
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AnimatedBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🧩', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Pal.text,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sub,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Pal.textDim,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_step == 0) ...[
                    GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 4,
                      ),
                      child: TextField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 20,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          color: Pal.text,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Aapka naam',
                          hintStyle: TextStyle(color: Pal.textDim),
                          border: InputBorder.none,
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    PremiumButton(
                      label: 'Aage badhein',
                      icon: Icons.arrow_forward_rounded,
                      onTap: _name.text.trim().length >= 2
                          ? () => setState(() => _step = 1)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () async {
                        await AccountService.I.loginWithoutPin(
                          _name.text.trim().isEmpty ? 'Player' : _name.text.trim(),
                        );
                        Rewards.reload();
                      },
                      icon: const Icon(Icons.play_arrow_rounded, color: Pal.gold, size: 22),
                      label: const Text(
                        'Skip PIN & Play Directly',
                        style: TextStyle(
                          color: Pal.gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ] else ...[
                    if (_step == 1 && _bioAvail)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: GlassCard(
                          blur: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: const Icon(
                              Icons.fingerprint_rounded,
                              color: Pal.gold,
                              size: 32,
                            ),
                            title: const Text(
                              'Fingerprint se unlock',
                              style: TextStyle(
                                color: Pal.text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            value: _bio,
                            activeThumbColor: Pal.gold,
                            onChanged: (v) => setState(() => _bio = v),
                          ),
                        ),
                      ),
                    PinPad(
                      pin: _pin,
                      error: _msg != null,
                      onChanged: _pinChanged,
                    ),
                    if (_msg != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _msg!,
                          style: const TextStyle(color: Pal.danger),
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () async {
                        await AccountService.I.loginWithoutPin(
                          _name.text.trim().isEmpty ? 'Player' : _name.text.trim(),
                        );
                        Rewards.reload();
                      },
                      icon: const Icon(Icons.play_arrow_rounded, color: Pal.gold, size: 22),
                      label: const Text(
                        'Skip PIN & Play Directly',
                        style: TextStyle(
                          color: Pal.gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
