import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../cloud/cloud_auth.dart';
import '../cloud/cloud_service.dart';
import '../rewards.dart';
import '../ui/app_logo.dart';
import '../ui/ui.dart';
import 'account_service.dart';

const int kPinLength = 4;

/// Shows the welcome screen (first run), lock screen or [home].
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
        return a.hasAccount ? const LockScreen() : const WelcomeScreen();
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
                  const AppLogo(size: 72)
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
                  if (!AccountService.I.hasPin) ...[
                    const SizedBox(height: 18),
                    PremiumButton(
                      label: 'Continue',
                      icon: Icons.play_arrow_rounded,
                      onTap: () async {
                        await AccountService.I.loginWithoutPin(name);
                        Rewards.reload();
                      },
                    ),
                  ] else ...[
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

  /// This screen is pushed from [WelcomeScreen]; once logged in, AuthGate
  /// shows home underneath, so close it.
  void _done() {
    if (mounted && Navigator.of(context).canPop()) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _guest() async {
    await AccountService.I.loginWithoutPin(_name.text.trim().isEmpty ? 'Player' : _name.text.trim());
    Rewards.reload();
    _done();
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
        _done();
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
      0 => 'Play on this phone',
      1 => 'Welcome, ${_name.text.trim()}!',
      _ => 'PIN confirm karein',
    };
    final sub = switch (_step) {
      0 => 'Apna naam batayein, hum aapka sab kuch is phone mein hi save rakhenge.',
      1 => '4 ank ka PIN chunein (optional app lock).',
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
                  const AppLogo(size: 72),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
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
                      onPressed: _guest,
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
                      onPressed: _guest,
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

/// First run: sign in with Google / Email (cloud backup) or play locally.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(size: 88)
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .moveY(begin: -5, end: 5, duration: 1400.ms, curve: Curves.easeInOut),
                  const SizedBox(height: 14),
                  const Text(
                    'Welcome to Master G',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Pal.text, fontSize: 30, fontWeight: FontWeight.w900),
                  ).animate().fadeIn(),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in to back up your progress and join the leaderboards, or just play on this phone.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Pal.textDim, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 28),
                  const CloudSignInPanel(),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(child: Divider(color: Pal.textDim.withValues(alpha: 0.3))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text('or', style: TextStyle(color: Pal.textDim)),
                    ),
                    Expanded(child: Divider(color: Pal.textDim.withValues(alpha: 0.3))),
                  ]),
                  const SizedBox(height: 18),
                  PremiumButton(
                    label: 'Play as guest / local',
                    icon: Icons.phone_android_rounded,
                    color: const Color(0xFF7C5CFF),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'You can sign in later from Profile. Local progress is kept.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Pal.textDim, fontSize: 12),
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

/// Small "Cloud setup pending" note shown when Firebase is not configured.
class CloudPendingNote extends StatelessWidget {
  const CloudPendingNote({super.key});

  @override
  Widget build(BuildContext context) => const Row(children: [
        Icon(Icons.cloud_off_rounded, color: Pal.textDim, size: 20),
        SizedBox(width: 10),
        Expanded(
          child: Text(CloudService.pendingMessage, style: TextStyle(color: Pal.textDim, fontSize: 13, height: 1.3)),
        ),
      ]);
}

/// "Continue with Google" + "Continue with Email". Disabled with a friendly
/// note while the cloud is not set up. Calls [onSignedIn] after success.
class CloudSignInPanel extends StatefulWidget {
  const CloudSignInPanel({super.key, this.onSignedIn});
  final VoidCallback? onSignedIn;

  @override
  State<CloudSignInPanel> createState() => _CloudSignInPanelState();
}

class _CloudSignInPanelState extends State<CloudSignInPanel> {
  bool _busy = false;

  Future<void> _google() async {
    setState(() => _busy = true);
    final err = await CloudAuth.I.signInWithGoogle();
    if (!mounted) return;
    setState(() => _busy = false);
    if (err == null) {
      widget.onSignedIn?.call();
    } else if (err.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _email() async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const EmailAuthScreen()));
    if (ok == true && mounted) widget.onSignedIn?.call();
  }

  @override
  Widget build(BuildContext context) {
    final on = CloudService.available && !_busy;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      PremiumButton(
        label: _busy ? 'Signing in...' : 'Continue with Google',
        icon: Icons.g_mobiledata_rounded,
        color: const Color(0xFF4285F4),
        onTap: on ? _google : null,
      ),
      const SizedBox(height: 12),
      PremiumButton(
        label: 'Continue with Email',
        icon: Icons.email_rounded,
        color: const Color(0xFF22B07D),
        onTap: on ? _email : null,
      ),
      if (!CloudService.available) ...[
        const SizedBox(height: 12),
        const CloudPendingNote(),
      ],
    ]);
  }
}

enum _EmailMode { signIn, signUp, reset }

/// Email/password sign in, sign up and password reset. Pops `true` on sign-in.
class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  _EmailMode _mode = _EmailMode.signIn;
  bool _busy = false;
  bool _hide = true;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    if (AccountService.I.hasAccount) _name.text = AccountService.I.name;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  void _setMode(_EmailMode m) => setState(() {
        _mode = m;
        _error = null;
      });

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!_emailRe.hasMatch(email)) return setState(() => _error = 'Enter a valid email address.');
    if (_mode != _EmailMode.reset && _pass.text.length < 6) {
      return setState(() => _error = 'Password must be at least 6 characters.');
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final mode = _mode;
    final err = switch (mode) {
      _EmailMode.signIn => await CloudAuth.I.signInWithEmail(email: email, password: _pass.text),
      _EmailMode.signUp => await CloudAuth.I.signUpWithEmail(email: email, password: _pass.text, name: _name.text),
      _EmailMode.reset => await CloudAuth.I.sendPasswordReset(email),
    };
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) return setState(() => _error = err.isEmpty ? null : err);
    if (mode == _EmailMode.reset) {
      setState(() {
        _info = 'Reset link sent to $email. Check your inbox, then sign in.';
        _mode = _EmailMode.signIn;
      });
      return;
    }
    if (mode == _EmailMode.signUp) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Welcome! We sent a verification link to $email.')),
      );
    }
    Navigator.of(context).pop(true);
  }

  Widget _field(TextEditingController c, String hint, IconData icon,
      {bool obscure = false, TextInputType? type, Widget? suffix, TextCapitalization cap = TextCapitalization.none}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        blur: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: TextField(
          controller: c,
          obscureText: obscure,
          keyboardType: type,
          textCapitalization: cap,
          autocorrect: false,
          style: const TextStyle(color: Pal.text, fontSize: 16),
          decoration: InputDecoration(
            icon: Icon(icon, color: Pal.textDim),
            hintText: hint,
            hintStyle: const TextStyle(color: Pal.textDim),
            border: InputBorder.none,
            suffixIcon: suffix,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_mode) {
      _EmailMode.signIn => 'Sign in',
      _EmailMode.signUp => 'Create account',
      _EmailMode.reset => 'Reset password',
    };
    return GameScaffold(
      title: title,
      tint: const Color(0xFF22B07D),
      body: ListView(padding: const EdgeInsets.fromLTRB(22, 12, 22, 28), children: [
        if (!CloudService.available) ...[
          const GlassCard(child: CloudPendingNote()),
          const SizedBox(height: 16),
        ],
        if (_mode == _EmailMode.signUp) _field(_name, 'Your name', Icons.person_rounded, cap: TextCapitalization.words),
        _field(_email, 'Email', Icons.email_rounded, type: TextInputType.emailAddress),
        if (_mode != _EmailMode.reset)
          _field(
            _pass,
            'Password',
            Icons.lock_rounded,
            obscure: _hide,
            suffix: IconButton(
              icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: Pal.textDim),
              onPressed: () => setState(() => _hide = !_hide),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: const TextStyle(color: Pal.danger)),
          ),
        if (_info != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_info!, style: const TextStyle(color: Pal.success)),
          ),
        const SizedBox(height: 6),
        PremiumButton(
          label: _busy ? 'Please wait...' : title,
          icon: Icons.arrow_forward_rounded,
          color: const Color(0xFF22B07D),
          onTap: _busy || !CloudService.available ? null : _submit,
        ),
        const SizedBox(height: 14),
        if (_mode == _EmailMode.signIn) ...[
          TextButton(
            onPressed: () => _setMode(_EmailMode.reset),
            child: const Text('Forgot password?', style: TextStyle(color: Pal.gold)),
          ),
          TextButton(
            onPressed: () => _setMode(_EmailMode.signUp),
            child: const Text('New here? Create an account', style: TextStyle(color: Pal.gold, fontWeight: FontWeight.bold)),
          ),
        ] else
          TextButton(
            onPressed: () => _setMode(_EmailMode.signIn),
            child: const Text('Already have an account? Sign in', style: TextStyle(color: Pal.gold, fontWeight: FontWeight.bold)),
          ),
      ]),
    );
  }
}
