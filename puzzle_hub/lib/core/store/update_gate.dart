import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../ui/ui.dart';
import 'app_store.dart';

/// Covers the whole app while a mandatory Play update is pending.
class UpdateGate extends StatelessWidget {
  const UpdateGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: AppStore.updateRequired,
        builder: (context, required, _) => Stack(children: [
          child,
          if (required)
            Positioned.fill(
              child: Material(
                color: const Color(0xFF140E38),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Text('🚀', style: TextStyle(fontSize: 72)),
                      const SizedBox(height: 16),
                      Text(tr('update.title'), textAlign: TextAlign.center, style: const TextStyle(color: Pal.text, fontSize: 24, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      Text(tr('update.text'), textAlign: TextAlign.center, style: const TextStyle(color: Pal.textDim, fontSize: 15, height: 1.4)),
                      const SizedBox(height: 26),
                      PremiumButton(
                        key: const ValueKey('update_now'),
                        label: tr('update.button'),
                        icon: Icons.system_update_rounded,
                        onTap: AppStore.updateNow,
                      ),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      );
}
