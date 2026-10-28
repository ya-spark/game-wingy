/// 7-day daily login reward cycle. Pure Dart.
class DailyRewardState {
  const DailyRewardState({this.nextDay = 0, this.lastClaimDay = -1});

  /// Index (0..6) of the reward the next claim gives.
  final int nextDay;

  /// Day index (see dayIndexOf) of the last claim, -1 if never.
  final int lastClaimDay;

  Map<String, Object?> toJson() => {
    'nextDay': nextDay,
    'lastClaimDay': lastClaimDay,
  };

  factory DailyRewardState.fromJson(Map<String, Object?>? j) => j == null
      ? const DailyRewardState()
      : DailyRewardState(
          nextDay: (j['nextDay'] as num?)?.toInt() ?? 0,
          lastClaimDay: (j['lastClaimDay'] as num?)?.toInt() ?? -1,
        );
}

/// What one day of the cycle gives.
class DailyRewardItem {
  const DailyRewardItem({this.coins = 0, this.refills = 0, this.freezes = 0});
  final int coins;

  /// Dash Refill stock items.
  final int refills;

  /// Streak freezes.
  final int freezes;
}

class DailyRewardClaim {
  const DailyRewardClaim(this.state, this.item, this.day);
  final DailyRewardState state;
  final DailyRewardItem item;
  int get coins => item.coins;
  int get refills => item.refills;
  int get freezes => item.freezes;

  /// Which cycle day (0..6) was claimed.
  final int day;
}

abstract final class DailyRewardEngine {
  /// Wingy's 7-day cycle: coins, Dash Refills on days 4 and 6, a streak freeze on day 7.
  static const List<DailyRewardItem> rewards = [
    DailyRewardItem(coins: 30),
    DailyRewardItem(coins: 40),
    DailyRewardItem(coins: 50),
    DailyRewardItem(refills: 1),
    DailyRewardItem(coins: 70),
    DailyRewardItem(refills: 1),
    DailyRewardItem(coins: 150, freezes: 1),
  ];
  static List<int> get coinsByDay => [for (final r in rewards) r.coins];
  static int get cycleLength => rewards.length;

  static bool canClaim(DailyRewardState s, int today) =>
      s.lastClaimDay != today;

  /// The cycle day that would be claimed today: the cycle restarts if a day was missed.
  static int dayToClaim(DailyRewardState s, int today) {
    if (s.lastClaimDay < 0) return 0;
    final gap = today - s.lastClaimDay;
    if (gap <= 1) {
      return s.nextDay % cycleLength; // next day in a row, or already claimed
    }
    return 0; // missed at least one day
  }

  /// Claims today's reward. Returns null if already claimed today.
  static DailyRewardClaim? claim(DailyRewardState s, int today) {
    if (!canClaim(s, today)) return null;
    final day = dayToClaim(s, today);
    return DailyRewardClaim(
      DailyRewardState(nextDay: (day + 1) % cycleLength, lastClaimDay: today),
      rewards[day],
      day,
    );
  }
}
