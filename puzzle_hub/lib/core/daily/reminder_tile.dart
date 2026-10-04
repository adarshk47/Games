import 'package:flutter/material.dart';

import '../ui/palette.dart';
import 'reminder_service.dart';

/// Settings row for the daily reminder: on/off switch + time picker.
class ReminderSettingsTile extends StatelessWidget {
  const ReminderSettingsTile({super.key});

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: ReminderService.time.value,
      helpText: 'Reminder time',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: Pal.gold, onPrimary: Colors.black, surface: Pal.bg1),
        ),
        child: child!,
      ),
    );
    if (picked != null) await ReminderService.setTime(picked);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ReminderService.enabled,
      builder: (context, on, _) => ValueListenableBuilder<TimeOfDay>(
        valueListenable: ReminderService.time,
        builder: (context, t, _) => Column(mainAxisSize: MainAxisSize.min, children: [
          SwitchListTile(
            secondary: Icon(Icons.notifications_active_rounded, color: on ? Pal.gold : Pal.textDim, size: 28),
            title: const Text('Daily reminder', style: TextStyle(color: Pal.text, fontWeight: FontWeight.w700)),
            subtitle: Text(on ? 'Roz ${t.format(context)} par yaad dilayenge' : 'Off',
                style: const TextStyle(color: Pal.textDim, fontSize: 12)),
            value: on,
            activeThumbColor: Pal.gold,
            onChanged: (v) async {
              final res = await ReminderService.setEnabled(v);
              if (v && !res && context.mounted) {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  const SnackBar(content: Text('Notifications ki permission settings se allow karein')),
                );
              }
            },
          ),
          if (on)
            ListTile(
              leading: const SizedBox(width: 28, child: Icon(Icons.schedule_rounded, color: Pal.textDim)),
              title: const Text('Reminder time', style: TextStyle(color: Pal.text, fontWeight: FontWeight.w600)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Pal.gold.withValues(alpha: 0.7)),
                ),
                child: Text(t.format(context), style: const TextStyle(color: Pal.gold, fontWeight: FontWeight.w800)),
              ),
              onTap: () => _pickTime(context),
            ),
        ]),
      ),
    );
  }
}
