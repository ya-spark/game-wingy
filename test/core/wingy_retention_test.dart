import 'package:flutter_test/flutter_test.dart';
import 'package:wingy/core/config/app_config.dart';
import 'package:wingy/core/profile/profile_store.dart';
import 'package:wingy/core/retention/achievements.dart';
import 'package:wingy/core/retention/daily_challenges.dart';
import 'package:wingy/core/retention/daily_reward.dart';
import 'package:wingy/core/retention/economy.dart';
import 'package:wingy/core/save/save_data.dart';
import 'package:wingy/core/save/save_service.dart';

void main() {
  late DateTime now;
  late MemorySaveService saves;

  ProfileStore make() => ProfileStore(
    saves: saves,
    retention: const RetentionConfig(),
    clock: () => now,
  );

  void nextDay() => now = now.add(const Duration(days: 1));

  setUp(() {
    now = DateTime(2026, 3, 1, 10);
    saves = MemorySaveService();
  });

  group('7-day daily reward', () {
    test('rewards match the spec', () {
      final r = DailyRewardEngine.rewards;
      expect(r.map((e) => e.coins), [30, 40, 50, 0, 70, 0, 150]);
      expect(r.map((e) => e.refills), [0, 0, 0, 1, 0, 1, 0]);
      expect(r.map((e) => e.freezes), [0, 0, 0, 0, 0, 0, 1]);
    });

    test(
      'a full cycle grants coins, two Dash Refills and one freeze',
      () async {
        final p = make();
        await p.init();
        for (var i = 0; i < 7; i++) {
          expect(p.dailyRewardAvailable, isTrue, reason: 'day ${i + 1}');
          await p.claimDailyReward();
          nextDay();
          await p.onAppOpened();
        }
        // 30+40+50+70+150 coins plus the 150 coin Daily Devotee achievement.
        expect(p.data.coins, 340 + 150);
        expect(p.dashRefills, 2);
        // Day 7 reward and the 7-day streak each grant a freeze (capped at 2).
        expect(p.data.streak.freezes, greaterThanOrEqualTo(1));
        expect(p.data.stats.bestStreak, greaterThanOrEqualTo(7));
      },
    );

    test(
      'a streak freeze covers one missed day for streak and rewards',
      () async {
        final p = make();
        await p.init();
        await p.claimDailyReward(); // day 1
        nextDay();
        await p.onAppOpened();
        await p.claimDailyReward(); // day 2
        // Earn a freeze, then skip a day.
        await p.addCoins(Economy.streakFreezeCost);
        expect(await p.buyStreakFreeze(), isTrue);
        now = now.add(const Duration(days: 2)); // one missed day
        await p.onAppOpened();
        expect(p.data.streak.freezes, 0);
        expect(p.displayStreak, 3);
        expect(p.dailyRewardDayToClaim, 2, reason: 'cycle continues at day 3');
      },
    );

    test('without a freeze a missed day restarts the cycle', () async {
      final p = make();
      await p.init();
      await p.claimDailyReward();
      nextDay();
      await p.onAppOpened();
      await p.claimDailyReward();
      now = now.add(const Duration(days: 2));
      await p.onAppOpened();
      expect(p.dailyRewardDayToClaim, 0);
      expect(p.displayStreak, 1);
    });
  });

  group('Dash Refills and freezes', () {
    test('buy a refill for 40 coins, only when affordable', () async {
      final p = make();
      await p.init();
      expect(await p.buyDashRefill(), isFalse);
      await p.addCoins(100);
      expect(await p.buyDashRefill(), isTrue);
      expect(p.data.coins, 60);
      expect(p.dashRefills, 1);
      expect(await p.consumeDashRefill(), isTrue);
      expect(await p.consumeDashRefill(), isFalse);
      expect(p.dashRefills, 0);
    });

    test(
      'ad refills are limited to 3 per day and reset the next day',
      () async {
        final p = make();
        await p.init();
        expect(p.adRefillsLeftToday, 3);
        for (var i = 0; i < 3; i++) {
          expect(await p.grantAdRefill(), isTrue);
        }
        expect(p.adRefillsLeftToday, 0);
        expect(await p.grantAdRefill(), isFalse);
        expect(p.dashRefills, 3);
        nextDay();
        await p.onAppOpened();
        expect(p.adRefillsLeftToday, 3);
        expect(await p.grantAdRefill(), isTrue);
      },
    );

    test('buy a streak freeze for 100 coins, capped at the maximum', () async {
      final p = make();
      await p.init();
      await p.addCoins(500);
      expect(await p.buyStreakFreeze(), isTrue);
      expect(await p.buyStreakFreeze(), isTrue);
      expect(await p.buyStreakFreeze(), isFalse, reason: 'max 2 freezes');
      expect(p.data.coins, 300);
      expect(p.data.streak.freezes, 2);
    });

    test('new save fields round trip through JSON', () {
      const d = SaveData(
        dashRefills: 2,
        adRefillDay: 5,
        adRefillsToday: 2,
        reduceMotion: true,
      );
      final r = SaveData.fromJson(d.toJson());
      expect(r.dashRefills, 2);
      expect(r.adRefillDay, 5);
      expect(r.adRefillsToday, 2);
      expect(r.reduceMotion, isTrue);
    });
  });

  group('daily challenges', () {
    test('eight templates cover the spec list and rewards are 25 to 60', () {
      final kinds = DailyChallengeEngine.templates.map((t) => t.kind).toSet();
      expect(kinds, ChallengeKind.values.toSet());
      for (final t in DailyChallengeEngine.templates) {
        expect(t.rewards.every((r) => r >= 25 && r <= 60), isTrue);
        expect(t.targets.length, t.rewards.length);
      }
    });

    test('three challenges are generated every day and always valid', () {
      for (var day = 0; day < 60; day++) {
        final s = DailyChallengeEngine.ensureToday(
          const DailyChallengesState(),
          day,
        );
        expect(s.challenges, hasLength(3));
        expect(s.challenges.map((c) => c.kind).toSet(), hasLength(3));
        expect(s.challenges.every((c) => c.target > 0), isTrue);
      }
    });

    test('record() accumulates totals and keeps maxima per kind', () {
      var s = DailyChallengesState(
        day: 1,
        challenges: [
          for (final k in ChallengeKind.values)
            Challenge(
              id: k.name,
              kind: k,
              description: '',
              target: 100,
              reward: 1,
            ),
        ],
      );
      for (final k in ChallengeKind.values) {
        s = DailyChallengeEngine.record(s, k, 5);
        s = DailyChallengeEngine.record(s, k, 3);
      }
      int progress(ChallengeKind k) =>
          s.challenges.firstWhere((c) => c.kind == k).progress;
      expect(progress(ChallengeKind.scoreInRun), 5);
      expect(progress(ChallengeKind.perfectRun), 5);
      expect(progress(ChallengeKind.passTotal), 8);
      expect(progress(ChallengeKind.orbsTotal), 8);
      expect(progress(ChallengeKind.dashUses), 8);
      expect(progress(ChallengeKind.dashShatters), 8);
      expect(progress(ChallengeKind.bloom), 8);
      expect(progress(ChallengeKind.playRuns), 8);
    });

    test('profile records a run into the matching challenges', () async {
      final p = make();
      await p.init();
      final kinds = p.challenges.map((c) => c.kind).toList();
      await p.recordGameFinished(
        const GameSummary(
          score: 60,
          passes: 200,
          maxPerfectStreak: 9,
          orbs: 30,
          dashUses: 3,
          dashShatters: 7,
          bloomHits: 2,
        ),
      );
      // Every generated challenge is at its tier-1 target or lower in this run.
      for (final c in p.challenges) {
        expect(c.progress, greaterThan(0), reason: '${c.kind}');
      }
      expect(kinds, hasLength(3));
    });
  });

  group('achievements', () {
    test('there are exactly the ten spec ids', () {
      expect(AchievementEngine.all.map((a) => a.id).toSet(), {
        'ach_first_flight',
        'ach_ten_gaps',
        'ach_gold_wings',
        'ach_prism_wings',
        'ach_perfectionist',
        'ach_orb_collector',
        'ach_dash_master',
        'ach_night_owl',
        'ach_regular',
        'ach_daily_devotee',
      });
    });

    void unlocksAt(String id, LifetimeStats ok, LifetimeStats notYet) {
      expect(
        AchievementEngine.newlyUnlocked(notYet, {}).map((a) => a.id),
        isNot(contains(id)),
        reason: '$id too early',
      );
      expect(
        AchievementEngine.newlyUnlocked(ok, {}).map((a) => a.id),
        contains(id),
        reason: id,
      );
    }

    test('each achievement unlocks on its condition', () {
      unlocksAt(
        'ach_first_flight',
        const LifetimeStats(bestScore: 1),
        const LifetimeStats(),
      );
      unlocksAt(
        'ach_ten_gaps',
        const LifetimeStats(bestScore: 10),
        const LifetimeStats(bestScore: 9),
      );
      unlocksAt(
        'ach_gold_wings',
        const LifetimeStats(bestScore: 50),
        const LifetimeStats(bestScore: 49),
      );
      unlocksAt(
        'ach_prism_wings',
        const LifetimeStats(bestScore: 100),
        const LifetimeStats(bestScore: 99),
      );
      unlocksAt(
        'ach_perfectionist',
        const LifetimeStats(maxPerfectStreak: 7),
        const LifetimeStats(maxPerfectStreak: 6),
      );
      unlocksAt(
        'ach_orb_collector',
        const LifetimeStats(totalOrbs: 50),
        const LifetimeStats(totalOrbs: 49),
      );
      unlocksAt(
        'ach_dash_master',
        const LifetimeStats(dashShatters: 20),
        const LifetimeStats(dashShatters: 19),
      );
      unlocksAt(
        'ach_night_owl',
        const LifetimeStats(bestScore: 60),
        const LifetimeStats(bestScore: 59),
      );
      unlocksAt(
        'ach_regular',
        const LifetimeStats(gamesPlayed: 50),
        const LifetimeStats(gamesPlayed: 49),
      );
      unlocksAt(
        'ach_daily_devotee',
        const LifetimeStats(bestStreak: 7),
        const LifetimeStats(bestStreak: 6),
      );
    });
  });
}
