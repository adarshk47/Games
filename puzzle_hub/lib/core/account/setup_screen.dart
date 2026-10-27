import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../ui/app_logo.dart';
import '../ui/ui.dart';
import 'account_service.dart';
import 'countries.dart';
import 'country_select.dart';

/// First start, like setting up a new phone: pick the language (English by
/// default) and the country / region on one screen, then continue.
class FirstSetupScreen extends StatefulWidget {
  const FirstSetupScreen({super.key});

  @override
  State<FirstSetupScreen> createState() => _FirstSetupScreenState();
}

class _FirstSetupScreenState extends State<FirstSetupScreen> {
  late AppLang _lang = I18n.chosen ? I18n.lang.value : AppLang.en;
  late Country _country = _initialCountry();
  bool _busy = false;

  /// Saved country, else the phone's region, else India.
  static Country _initialCountry() {
    final saved = AccountService.I.country;
    final device = WidgetsBinding.instance.platformDispatcher.locale.countryCode?.toUpperCase();
    for (final code in [saved, device, 'IN']) {
      for (final c in countries) {
        if (c.code == code) return c;
      }
    }
    return countries.first;
  }

  @override
  void initState() {
    super.initState();
    // Show this screen in the selected language right away (saved on Continue).
    I18n.lang.value = _lang;
  }

  void _pickLang(AppLang l) {
    setState(() => _lang = l);
    I18n.lang.value = l;
  }

  Future<void> _pickCountry() async {
    final picked = await showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B1245),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheet) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheet).size.height * 0.8,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Column(children: [
              Text(tr('setup.country'), style: const TextStyle(color: Pal.text, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Expanded(
                child: CountryList(
                  selected: _country.code,
                  save: false,
                  onPicked: (c) => Navigator.of(sheet).pop(c),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _country = picked);
  }

  Future<void> _continue() async {
    if (_busy) return;
    setState(() => _busy = true);
    await AccountService.I.setCountry(_country.code);
    await I18n.set(_lang); // rebuilds AuthGate to the next step
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(children: [
              const AppLogo(size: 64),
              const SizedBox(height: 12),
              Text(tr('setup.title'),
                  textAlign: TextAlign.center, style: const TextStyle(color: Pal.text, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(tr('setup.sub'), textAlign: TextAlign.center, style: const TextStyle(color: Pal.textDim, fontSize: 13)),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(tr('setup.language'),
                    style: const TextStyle(color: Pal.textDim, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: GlassCard(
                  blur: 0,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ListView(children: [
                    for (final l in AppLang.values)
                      ListTile(
                        key: ValueKey('setup_lang_${l.code}'),
                        dense: true,
                        onTap: () => _pickLang(l),
                        title: Text(l.nativeName,
                            style: TextStyle(color: Pal.text, fontSize: 17, fontWeight: l == _lang ? FontWeight.w900 : FontWeight.w600)),
                        subtitle: l.nativeName == l.englishName ? null : Text(l.englishName, style: const TextStyle(color: Pal.textDim)),
                        trailing: Icon(l == _lang ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                            color: l == _lang ? Pal.gold : Pal.textDim),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(tr('setup.country'),
                    style: const TextStyle(color: Pal.textDim, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
              ),
              const SizedBox(height: 6),
              GlassCard(
                key: const ValueKey('setup_country'),
                blur: 0,
                onTap: _pickCountry,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Text(_country.flag, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_country.name, style: const TextStyle(color: Pal.text, fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Pal.textDim),
                ]),
              ),
              const SizedBox(height: 16),
              PremiumButton(
                key: const ValueKey('setup_continue'),
                label: tr('common.continue'),
                icon: Icons.arrow_forward_rounded,
                onTap: _continue,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
