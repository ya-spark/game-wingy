import 'package:flutter/material.dart';

import '../core/retention/daily_reward.dart';
import '../core/services.dart';
import 'test_ids.dart';

class DailyRewardScreen extends StatelessWidget {
  const DailyRewardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final profile = s.profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Daily reward')),
      body: ListenableBuilder(
        listenable: profile,
        builder: (context, _) {
          final today = profile.dailyRewardDayToClaim;
          final available = profile.dailyRewardAvailable;
          // Days before `today` in the cycle are done if the reward was claimed on that streak.
          final claimedThrough = available
              ? today
              : (today == 0 ? DailyRewardEngine.cycleLength : today);
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (s.config.retention.streaks)
                  Text(
                    'Streak: ${profile.displayStreak} days  •  Freezes: ${profile.data.streak.freezes}',
                    key: TestIds.dailyStreak,
                  ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 4,
                    childAspectRatio: 0.7,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      for (var i = 0; i < DailyRewardEngine.cycleLength; i++)
                        Card(
                          key: TestIds.dailyDay(i),
                          color: i < claimedThrough
                              ? Theme.of(context).colorScheme.primaryContainer
                              : (i == today && available
                                    ? Theme.of(context)
                                          .colorScheme
                                          .tertiaryContainer
                                    : null),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Day ${i + 1}'),
                                  ..._rewardLabel(DailyRewardEngine.rewards[i]),
                                  if (i < claimedThrough)
                                    const Icon(Icons.check, size: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                FilledButton(
                  key: TestIds.dailyClaim,
                  onPressed: available
                      ? () async {
                          final day = profile.dailyRewardDayToClaim;
                          final coins = await profile.claimDailyReward();
                          if (coins != null && context.mounted) {
                            final item = profile.rewardForDay(day);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(_describe(item))),
                            );
                          }
                        }
                      : null,
                  child: Text(available ? 'Claim' : 'Come back tomorrow'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

List<Widget> _rewardLabel(DailyRewardItem r) => [
  if (r.coins > 0) ...[
    const Icon(Icons.monetization_on, color: Colors.amber),
    Text('${r.coins}'),
  ],
  if (r.refills > 0) ...[
    const Icon(Icons.bolt, color: Colors.cyanAccent),
    Text('Refill x${r.refills}'),
  ],
  if (r.freezes > 0) ...[
    const Icon(Icons.ac_unit, color: Colors.lightBlueAccent, size: 18),
    Text('+${r.freezes} freeze'),
  ],
];

String _describe(DailyRewardItem r) => [
  if (r.coins > 0) '+${r.coins} coins',
  if (r.refills > 0) '+${r.refills} Dash Refill',
  if (r.freezes > 0) '+${r.freezes} streak freeze',
].join(', ');
