import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../ui/app_logo.dart';
import '../ui/ui.dart';
import 'account_service.dart';
import 'countries.dart';

/// Searchable country list (India first). Used before sign-in and from Profile.
class CountryList extends StatefulWidget {
  const CountryList({super.key, required this.onPicked, this.shrinkWrap = false});
  final ValueChanged<Country> onPicked;
  final bool shrinkWrap;

  @override
  State<CountryList> createState() => _CountryListState();
}

class _CountryListState extends State<CountryList> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final cur = AccountService.I.country;
    final list = countries.where((c) => c.name.toLowerCase().contains(_q.toLowerCase())).toList();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      GlassCard(
        blur: 0,
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: TextField(
          onChanged: (v) => setState(() => _q = v),
          style: const TextStyle(color: Pal.text),
          decoration: InputDecoration(
            icon: const Icon(Icons.search_rounded, color: Pal.textDim),
            hintText: tr('account.country.search'),
            hintStyle: const TextStyle(color: Pal.textDim),
            border: InputBorder.none,
          ),
        ),
      ),
      const SizedBox(height: 10),
      Flexible(
        child: ListView.builder(
          shrinkWrap: widget.shrinkWrap,
          itemCount: list.length,
          itemBuilder: (_, i) {
            final c = list[i];
            final sel = c.code == cur;
            return ListTile(
              key: ValueKey('country_${c.code}'),
              leading: Text(c.flag, style: const TextStyle(fontSize: 26)),
              title: Text(c.name, style: TextStyle(color: Pal.text, fontWeight: sel ? FontWeight.w900 : FontWeight.w500)),
              trailing: sel ? const Icon(Icons.check_circle_rounded, color: Pal.gold) : null,
              onTap: () async {
                await AccountService.I.setCountry(c.code);
                widget.onPicked(c);
              },
            );
          },
        ),
      ),
    ]);
  }
}

/// Required step before the welcome / lock screen when no country is set.
class CountrySelectScreen extends StatelessWidget {
  const CountrySelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
            child: Column(children: [
              const AppLogo(size: 64),
              const SizedBox(height: 14),
              Text(tr('account.country.title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Pal.text, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(tr('account.country.sub'),
                  textAlign: TextAlign.center, style: const TextStyle(color: Pal.textDim, fontSize: 13)),
              const SizedBox(height: 14),
              Expanded(child: CountryList(onPicked: (_) {})),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet to change the country later (Profile).
Future<void> showCountrySheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B1245),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheet) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheet).size.height * 0.75,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Column(children: [
              Text(tr('account.country.label'),
                  style: const TextStyle(color: Pal.text, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Expanded(child: CountryList(onPicked: (_) => Navigator.of(sheet).pop())),
            ]),
          ),
        ),
      ),
    );
