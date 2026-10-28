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
                    childAspectRatio: 0.62,
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
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Day ${i + 1}'),
                              Icon(
                                DailyRewardEngine.dashRefillsByDay[i] > 0
                                    ? Icons.bolt
                                    : Icons.monetization_on,
                                color: Colors.amber,
                              ),
                              Text(
                                _rewardLabel(i),
                                textAlign: TextAlign.center,
                              ),
                              if (i < claimedThrough)
                                const Icon(Icons.check, size: 16),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                FilledButton(
                  key: TestIds.dailyClaim,
                  onPressed: available
                      ? () async {
                          final coins = await profile.claimDailyReward();
                          if (coins != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('+$coins coins')),
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

String _rewardLabel(int day) {
  final parts = <String>[
    if (DailyRewardEngine.coinsByDay[day] > 0)
      '${DailyRewardEngine.coinsByDay[day]}',
    if (DailyRewardEngine.dashRefillsByDay[day] > 0) 'Dash Refill',
    if (DailyRewardEngine.streakFreezesByDay[day] > 0) '+ Freeze',
  ];
  return parts.join('\n');
}
