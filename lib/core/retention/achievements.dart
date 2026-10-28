/// Lifetime counters that achievements are derived from. Pure Dart.
class LifetimeStats {
  const LifetimeStats({
    this.gamesPlayed = 0,
    this.bestScore = 0,
    this.totalPasses = 0,
    this.totalOrbs = 0,
    this.dashShatters = 0,
    this.maxPerfectStreak = 0,
    this.bestStreak = 0,
  });

  /// Runs finished.
  final int gamesPlayed;
  final int bestScore;
  final int totalPasses;
  final int totalOrbs;

  /// Spire pairs shattered by Glow Dash, lifetime.
  final int dashShatters;
  final int maxPerfectStreak;
  final int bestStreak;

  LifetimeStats copyWith({
    int? gamesPlayed,
    int? bestScore,
    int? totalPasses,
    int? totalOrbs,
    int? dashShatters,
    int? maxPerfectStreak,
    int? bestStreak,
  }) => LifetimeStats(
    gamesPlayed: gamesPlayed ?? this.gamesPlayed,
    bestScore: bestScore ?? this.bestScore,
    totalPasses: totalPasses ?? this.totalPasses,
    totalOrbs: totalOrbs ?? this.totalOrbs,
    dashShatters: dashShatters ?? this.dashShatters,
    maxPerfectStreak: maxPerfectStreak ?? this.maxPerfectStreak,
    bestStreak: bestStreak ?? this.bestStreak,
  );

  Map<String, Object?> toJson() => {
    'gamesPlayed': gamesPlayed,
    'bestScore': bestScore,
    'totalPasses': totalPasses,
    'totalOrbs': totalOrbs,
    'dashShatters': dashShatters,
    'maxPerfectStreak': maxPerfectStreak,
    'bestStreak': bestStreak,
  };

  factory LifetimeStats.fromJson(Map<String, Object?>? j) => j == null
      ? const LifetimeStats()
      : LifetimeStats(
          gamesPlayed: (j['gamesPlayed'] as num?)?.toInt() ?? 0,
          bestScore: (j['bestScore'] as num?)?.toInt() ?? 0,
          totalPasses: (j['totalPasses'] as num?)?.toInt() ?? 0,
          totalOrbs: (j['totalOrbs'] as num?)?.toInt() ?? 0,
          dashShatters: (j['dashShatters'] as num?)?.toInt() ?? 0,
          maxPerfectStreak: (j['maxPerfectStreak'] as num?)?.toInt() ?? 0,
          bestStreak: (j['bestStreak'] as num?)?.toInt() ?? 0,
        );
}

enum AchievementMetric {
  gamesPlayed,
  bestScore,
  totalPasses,
  totalOrbs,
  dashShatters,
  maxPerfectStreak,
  bestStreak,
}

class AchievementDef {
  const AchievementDef(
    this.id,
    this.title,
    this.description,
    this.metric,
    this.target,
    this.reward,
  );

  /// Stable ID; also the key for the Play Games achievement mapping.
  final String id;
  final String title;
  final String description;
  final AchievementMetric metric;
  final int target;
  final int reward;

  int valueIn(LifetimeStats s) => switch (metric) {
    AchievementMetric.gamesPlayed => s.gamesPlayed,
    AchievementMetric.bestScore => s.bestScore,
    AchievementMetric.totalPasses => s.totalPasses,
    AchievementMetric.totalOrbs => s.totalOrbs,
    AchievementMetric.dashShatters => s.dashShatters,
    AchievementMetric.maxPerfectStreak => s.maxPerfectStreak,
    AchievementMetric.bestStreak => s.bestStreak,
  };
}

abstract final class AchievementEngine {
  /// The ten Wingy achievements. IDs are also the Play Games achievement keys.
  static const List<AchievementDef> all = [
    AchievementDef(
      'ach_first_flight',
      'First Flight',
      'Score 1 point',
      AchievementMetric.bestScore,
      1,
      10,
    ),
    AchievementDef(
      'ach_ten_gaps',
      'Ten Gaps',
      'Score 10 in one run',
      AchievementMetric.bestScore,
      10,
      25,
    ),
    AchievementDef(
      'ach_gold_wings',
      'Gold Wings',
      'Score 50 in one run',
      AchievementMetric.bestScore,
      50,
      100,
    ),
    AchievementDef(
      'ach_prism_wings',
      'Prism Wings',
      'Score 100 in one run',
      AchievementMetric.bestScore,
      100,
      250,
    ),
    AchievementDef(
      'ach_perfectionist',
      'Perfectionist',
      '7 Perfect passes in a row',
      AchievementMetric.maxPerfectStreak,
      7,
      100,
    ),
    AchievementDef(
      'ach_orb_collector',
      'Orb Collector',
      'Collect 50 glow orbs',
      AchievementMetric.totalOrbs,
      50,
      75,
    ),
    AchievementDef(
      'ach_dash_master',
      'Dash Master',
      'Shatter 20 spire pairs with Glow Dash',
      AchievementMetric.dashShatters,
      20,
      100,
    ),
    AchievementDef(
      'ach_night_owl',
      'Night Owl',
      'Reach the midnight sky (score 60)',
      AchievementMetric.bestScore,
      60,
      100,
    ),
    AchievementDef(
      'ach_regular',
      'Regular',
      'Play 50 runs',
      AchievementMetric.gamesPlayed,
      50,
      100,
    ),
    AchievementDef(
      'ach_daily_devotee',
      'Daily Devotee',
      'Reach a 7-day streak',
      AchievementMetric.bestStreak,
      7,
      150,
    ),
  ];

  /// Achievements newly reached by [stats] that are not yet in [unlocked].
  static List<AchievementDef> newlyUnlocked(
    LifetimeStats stats,
    Set<String> unlocked,
  ) => [
    for (final a in all)
      if (!unlocked.contains(a.id) && a.valueIn(stats) >= a.target) a,
  ];
}
