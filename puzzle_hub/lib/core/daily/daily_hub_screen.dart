import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../achievements/achievements.dart';
import '../achievements/achievements_screen.dart';
import '../rewards.dart';
import '../ui/ui.dart';
import 'daily_quests.dart';
import 'daily_reward.dart';
import 'reminder_service.dart';

/// Daily tab body (no Scaffold): login reward, streaks, today's quests,
/// all-done bonus and the achievements entry.
class DailyHubScreen extends StatefulWidget {
  const DailyHubScreen({super.key});

  @override
  State<DailyHubScreen> createState() => _DailyHubScreenState();
}

class _DailyHubScreenState extends State<DailyHubScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ReminderService.ensurePermissionPrompt();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The calendar day may have changed while the app was in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: dailyChanged,
      builder: (context, tick, _) {
        final quests = DailyQuests.today();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            const _Header(),
            const SizedBox(height: 16),
            _LoginRewardCard(tick: tick),
            const SizedBox(height: 14),
            _StreakRow(tick: tick),
            const SizedBox(height: 22),
            _SectionTitle(
              title: "Today's Quests",
              trailing: '${quests.where((q) => q.completed).length}/${quests.length}',
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < quests.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _QuestCard(q: quests[i], color: Pal.accents[(i * 3 + 2) % Pal.accents.length])
                    .animate()
                    .fadeIn(delay: (120 + 80 * i).ms, duration: 350.ms)
                    .slideX(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
              ),
            const SizedBox(height: 4),
            _BonusCard(tick: tick),
            const SizedBox(height: 22),
            const _SectionTitle(title: 'Achievements'),
            const SizedBox(height: 10),
            _AchievementsEntry(tick: tick),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Daily', style: TextStyle(color: Pal.text, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 0.3)),
          Text('Roz khelo, coins jeeto 🪙', style: TextStyle(color: Pal.textDim.withValues(alpha: 0.9), fontSize: 13)),
        ]),
      ),
      const CoinPill(),
    ]).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2, end: 0);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Row(children: [
        Text(title, style: const TextStyle(color: Pal.text, fontSize: 19, fontWeight: FontWeight.w800)),
        const Spacer(),
        if (trailing != null)
          Text(trailing!, style: const TextStyle(color: Pal.gold, fontSize: 15, fontWeight: FontWeight.w800)),
      ]);
}

// ---------------------------------------------------------------- login reward

class _LoginRewardCard extends StatefulWidget {
  const _LoginRewardCard({required this.tick});
  final int tick;

  @override
  State<_LoginRewardCard> createState() => _LoginRewardCardState();
}

class _LoginRewardCardState extends State<_LoginRewardCard> {
  bool _burst = false;
  bool _claiming = false;

  Future<void> _claim() async {
    if (_claiming) return;
    setState(() => _claiming = true);
    final paid = await DailyReward.claim();
    if (!mounted) return;
    setState(() {
      _claiming = false;
      _burst = paid > 0;
    });
    if (paid > 0) ReminderService.reschedule();
  }

  @override
  Widget build(BuildContext context) {
    final can = DailyReward.canClaim;
    final day = DailyReward.todayCycleDay;
    final reward = DailyReward.todayReward;
    final broken = can && DailyReward.streakBroken;
    return GlassCard(
      glow: can ? Pal.gold : null,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Pal.goldDeep.withValues(alpha: can ? 0.30 : 0.14), const Color(0x0DFFFFFF)],
      ),
      child: Column(children: [
        Row(children: [
          _Chest(open: !can, burst: _burst),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(can ? 'Daily Reward' : 'Reward claimed!',
                  style: const TextStyle(color: Pal.text, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                can
                    ? (broken ? 'Koi baat nahi! Naya streak shuru karte hain. Day $day: $reward coins' : 'Day $day of 7 · $reward coins')
                    : 'Kal phir aana, Day ${DailyReward.cycleDay(DailyReward.streak + 1)} ka reward: ${DailyReward.rewardFor(DailyReward.streak + 1)} 🪙',
                style: const TextStyle(color: Pal.textDim, fontSize: 13, height: 1.3),
              ),
              const SizedBox(height: 10),
              if (can)
                PremiumButton(label: 'Claim $reward 🪙', compact: true, onTap: _claiming ? null : _claim)
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 800.ms),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        _WeekStrip(currentDay: day, claimedToday: !can),
      ]),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.currentDay, required this.claimedToday});
  final int currentDay;
  final bool claimedToday;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (var d = 1; d <= 7; d++)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5),
            child: _dayPill(d),
          ),
        ),
    ]);
  }

  Widget _dayPill(int d) {
    final done = d < currentDay || (d == currentDay && claimedToday);
    final today = d == currentDay;
    final big = d == 7;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: done
            ? Pal.accent(Pal.success)
            : today
                ? Pal.accent(Pal.goldDeep)
                : null,
        color: done || today ? null : Colors.black.withValues(alpha: 0.25),
        border: Border.all(color: today ? Colors.white.withValues(alpha: 0.7) : Pal.glassBorder),
        boxShadow: today && !claimedToday ? [BoxShadow(color: Pal.gold.withValues(alpha: 0.5), blurRadius: 12)] : null,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('D$d', style: TextStyle(color: done || today ? Colors.white : Pal.textDim, fontSize: 11, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        done
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 17)
            : Text(big ? '🎁' : '🪙', style: const TextStyle(fontSize: 14)),
        FittedBox(
          child: Text('${DailyReward.rewards[d - 1]}',
              style: TextStyle(color: done || today ? Colors.white : Pal.gold, fontSize: 12, fontWeight: FontWeight.w900)),
        ),
      ]),
    );
  }
}

/// Treasure chest: wobbles + glows while claimable, pops open with coins.
class _Chest extends StatelessWidget {
  const _Chest({required this.open, required this.burst});
  final bool open;
  final bool burst;

  @override
  Widget build(BuildContext context) {
    Widget chest = Container(
      width: 78,
      height: 78,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [
          Pal.gold.withValues(alpha: open ? 0.25 : 0.55),
          Pal.goldDeep.withValues(alpha: 0.0),
        ]),
      ),
      child: Text(open ? '🪙' : '🎁', style: const TextStyle(fontSize: 46)),
    );
    if (!open) {
      chest = chest
          .animate(onPlay: (c) => c.repeat())
          .rotate(begin: -0.02, end: 0.02, duration: 180.ms, curve: Curves.easeInOut)
          .then()
          .rotate(begin: 0.02, end: -0.02, duration: 180.ms)
          .then(delay: 1400.ms);
    } else if (burst) {
      chest = chest.animate().scale(begin: const Offset(0.4, 0.4), end: const Offset(1, 1), curve: Curves.elasticOut, duration: 900.ms);
    }
    return SizedBox(
      width: 86,
      height: 86,
      child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
        chest,
        if (burst)
          for (var i = 0; i < 8; i++)
            Text('🪙', style: const TextStyle(fontSize: 16))
                .animate()
                .move(
                  begin: Offset.zero,
                  end: Offset(math.cos(i * math.pi / 4) * 52, math.sin(i * math.pi / 4) * 52),
                  duration: 650.ms,
                  curve: Curves.easeOutCubic,
                )
                .fadeOut(delay: 400.ms, duration: 400.ms),
      ]),
    );
  }
}

// ---------------------------------------------------------------- streaks

class _StreakRow extends StatelessWidget {
  const _StreakRow({required this.tick});
  final int tick;

  @override
  Widget build(BuildContext context) {
    Widget tile(String emoji, String value, String label, Color c) => Expanded(
          child: GlassCard(
            blur: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(value, style: TextStyle(color: c, fontSize: 20, fontWeight: FontWeight.w900)),
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Pal.textDim, fontSize: 11)),
                ]),
              ),
            ]),
          ),
        );
    final s = DailyReward.streak;
    final c = DailyQuests.challengeStreak;
    return Row(children: [
      tile('🔥', '$s day${s == 1 ? '' : 's'}', 'Login streak · best ${DailyReward.bestStreak}', const Color(0xFFFB923C)),
      const SizedBox(width: 10),
      tile('🏆', '$c day${c == 1 ? '' : 's'}', 'Daily Challenge · best ${DailyQuests.challengeBest}', Pal.gold),
    ]).animate().fadeIn(delay: 80.ms, duration: 300.ms);
  }
}

// ---------------------------------------------------------------- quests

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.q, required this.color});
  final DailyQuest q;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = q.template;
    return GlassCard(
      blur: 0,
      glow: q.claimable ? color : null,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: q.claimed ? Pal.accent(Pal.success) : Pal.accent(color),
          ),
          child: q.claimed
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 28)
              : Text(t.emoji, style: const TextStyle(fontSize: 24)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.title,
                style: TextStyle(
                  color: q.claimed ? Pal.textDim : Pal.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  decoration: q.claimed ? TextDecoration.lineThrough : null,
                  decorationColor: Pal.textDim,
                )),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: ProgressBar(value: q.fraction, color: q.completed ? Pal.success : color, height: 7)),
              const SizedBox(width: 8),
              Text('${q.progress}/${t.target}',
                  style: const TextStyle(color: Pal.textDim, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
        const SizedBox(width: 10),
        if (q.claimable)
          PremiumButton(label: '+${t.reward}', icon: Icons.redeem_rounded, compact: true, onTap: () => DailyQuests.claim(t.id))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(begin: const Offset(1, 1), end: const Offset(1.06, 1.06), duration: 700.ms)
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Pal.gold.withValues(alpha: q.claimed ? 0.2 : 0.5)),
            ),
            child: Text(q.claimed ? 'Done' : '${t.reward} 🪙',
                style: TextStyle(color: q.claimed ? Pal.success : Pal.gold, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
      ]),
    );
  }
}

class _BonusCard extends StatelessWidget {
  const _BonusCard({required this.tick});
  final int tick;

  @override
  Widget build(BuildContext context) {
    final done = DailyQuests.allCompleted;
    final claimed = DailyQuests.bonusClaimed;
    return GlassCard(
      glow: done && !claimed ? Pal.gold : null,
      gradient: LinearGradient(
        colors: [const Color(0xFFB794FF).withValues(alpha: done ? 0.32 : 0.14), const Color(0x0DFFFFFF)],
      ),
      child: Row(children: [
        Text(claimed ? '🏆' : '🎯', style: const TextStyle(fontSize: 34)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Daily Challenge', style: TextStyle(color: Pal.text, fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 3),
            Text(
              claimed
                  ? 'Shabaash! Aaj ka challenge poora 🎉'
                  : done
                      ? 'Teeno quests poore! Bonus le lijiye'
                      : 'Teeno quests poore karo, +${DailyQuests.bonusCoins} bonus 🪙',
              style: const TextStyle(color: Pal.textDim, fontSize: 12.5),
            ),
          ]),
        ),
        if (done && !claimed)
          PremiumButton(label: '+${DailyQuests.bonusCoins}', compact: true, color: const Color(0xFFB794FF), onTap: DailyQuests.claimBonus)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .shimmer(duration: 1400.ms),
      ]),
    );
  }
}

// ---------------------------------------------------------------- achievements

class _AchievementsEntry extends StatelessWidget {
  const _AchievementsEntry({required this.tick});
  final int tick;

  @override
  Widget build(BuildContext context) {
    final total = Achievements.all().length;
    final have = Achievements.unlocked.length.clamp(0, total);
    return GlassCard(
      glow: Pal.gold,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AchievementsScreen())),
      child: Row(children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: Pal.accent(Pal.goldDeep)),
          child: const Text('🏅', style: TextStyle(fontSize: 30)),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .shimmer(duration: 2400.ms, color: Colors.white.withValues(alpha: 0.4)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Achievements', style: TextStyle(color: Pal.text, fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 4),
            Text('$have / $total badges unlocked', style: const TextStyle(color: Pal.textDim, fontSize: 12.5)),
            const SizedBox(height: 8),
            ProgressBar(value: total == 0 ? 0 : have / total, color: Pal.gold, height: 6),
          ]),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right_rounded, color: Pal.textDim, size: 28),
      ]),
    );
  }
}
