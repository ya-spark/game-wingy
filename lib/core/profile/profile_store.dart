import 'dart:math';

import 'package:flutter/foundation.dart';

import '../clock.dart';
import '../config/app_config.dart';
import '../config/products.dart';
import '../purchase/purchase_service.dart';
import '../retention/achievements.dart';
import '../retention/daily_challenges.dart';
import '../retention/daily_reward.dart';
import '../retention/streaks.dart';
import '../save/save_data.dart';
import '../save/save_service.dart';

/// Result of one finished run, fed into stats / challenges / achievements.
class GameSummary {
  const GameSummary({
    required this.score,
    this.pairsPassed = 0,
    this.perfectStreak = 0,
    this.orbs = 0,
    this.dashUses = 0,
    this.dashShattered = 0,
    this.bloomHits = 0,
    this.coins = 0,
  });
  final int score;
  final int pairsPassed;

  /// Longest run of consecutive Perfect passes.
  final int perfectStreak;
  final int orbs;
  final int dashUses;
  final int dashShattered;

  /// Perfect passes that earned a Bloom bonus of +3 or more.
  final int bloomHits;

  /// Coins earned in the run (orbs plus score coins); credited by [ProfileStore].
  final int coins;
}

/// Holds the player's [SaveData], applies the retention engines and persists every change.
/// UI listens to it; game rules never touch it.
class ProfileStore extends ChangeNotifier {
  ProfileStore({required this._saves, required this.retention, Clock? clock})
    : _clock = clock ?? DateTime.now;

  final SaveService _saves;
  final RetentionConfig retention;
  final Clock _clock;
  static const ClockGuard _guard = ClockGuard();

  SaveData _data = const SaveData();
  SaveData get data => _data;

  /// Device clock is behind the latest time we saw (the player moved it back).
  bool clockTampered = false;

  /// Time used for all date logic: never earlier than the latest time ever seen.
  DateTime get trustedNow => _guard.trusted(_clock(), _data.lastSeenMs);
  int get today => dayIndexOf(trustedNow);

  Future<void> init() async {
    _data = await _saves.load();
    await _tick();
  }

  /// Re-reads the save (local vs cloud, newer wins). Call after the player signs in to Play Games.
  Future<void> reload() async {
    _data = await _saves.load();
    await _tick();
  }

  /// Call on app start and on resume: refreshes the day, streak and today's challenges.
  Future<void> onAppOpened() => _tick();

  Future<void> _tick() async {
    final raw = _clock();
    clockTampered = _guard.isTampered(raw, _data.lastSeenMs);
    final now = _guard.trusted(raw, _data.lastSeenMs);
    final day = dayIndexOf(now);
    var d = _data.copyWith(lastSeenMs: now.millisecondsSinceEpoch);
    if (retention.streaks) {
      final u = StreakEngine.recordActivity(d.streak, day);
      d = d.copyWith(
        streak: u.state,
        stats: d.stats.copyWith(
          bestStreak: u.state.best > d.stats.bestStreak ? u.state.best : null,
        ),
      );
    }
    if (retention.dailyChallenges) {
      d = d.copyWith(
        challenges: DailyChallengeEngine.ensureToday(d.challenges, day),
      );
    }
    d = _unlockAchievements(d).data;
    await _commit(d);
  }

  Future<void> _commit(SaveData d) async {
    _data = d;
    notifyListeners();
    await _saves.save(d);
  }

  // ---- daily reward -------------------------------------------------------

  bool get dailyRewardAvailable =>
      retention.dailyReward &&
      DailyRewardEngine.canClaim(_data.dailyReward, today);

  int get dailyRewardDayToClaim =>
      DailyRewardEngine.dayToClaim(_data.dailyReward, today);

  /// Claims today's reward; returns coins granted or null if unavailable.
  Future<int?> claimDailyReward() async {
    if (!retention.dailyReward) return null;
    final c = DailyRewardEngine.claim(_data.dailyReward, today);
    if (c == null) return null;
    var d = _data.copyWith(
      dailyReward: c.state,
      coins: _data.coins + c.coins,
      dashRefills: _data.dashRefills + c.dashRefills,
    );
    if (c.streakFreezes > 0) {
      d = d.copyWith(
        streak: d.streak.copyWith(
          freezes: min(
            StreakEngine.maxFreezes,
            d.streak.freezes + c.streakFreezes,
          ),
        ),
      );
    }
    await _commit(d);
    return c.coins;
  }

  // ---- streak -------------------------------------------------------------

  int get displayStreak => StreakEngine.displayStreak(_data.streak, today);

  // ---- challenges ---------------------------------------------------------

  List<Challenge> get challenges =>
      retention.dailyChallenges ? _data.challenges.challenges : const [];

  Future<int?> claimChallenge(String id) async {
    final r = DailyChallengeEngine.claim(_data.challenges, id);
    if (r == null) return null;
    await _commit(
      _data.copyWith(challenges: r.state, coins: _data.coins + r.coins),
    );
    return r.coins;
  }

  // ---- gameplay -----------------------------------------------------------

  /// Records a finished run. Returns achievements unlocked by it.
  Future<List<AchievementDef>> recordGameFinished(GameSummary g) async {
    var d = _data;
    final stats = d.stats.copyWith(
      gamesPlayed: d.stats.gamesPlayed + 1,
      totalPairs: d.stats.totalPairs + g.pairsPassed,
      totalOrbs: d.stats.totalOrbs + g.orbs,
      totalShattered: d.stats.totalShattered + g.dashShattered,
      totalDashUses: d.stats.totalDashUses + g.dashUses,
      bestScore: g.score > d.stats.bestScore ? g.score : null,
      maxPerfectStreak: g.perfectStreak > d.stats.maxPerfectStreak
          ? g.perfectStreak
          : null,
    );
    d = d.copyWith(
      stats: stats,
      coins: d.coins + g.coins,
      bestScore: g.score > d.bestScore ? g.score : null,
    );
    if (retention.dailyChallenges) {
      var c = DailyChallengeEngine.ensureToday(d.challenges, today);
      c = DailyChallengeEngine.record(c, ChallengeKind.playGames, 1);
      c = DailyChallengeEngine.record(c, ChallengeKind.scorePoints, g.score);
      c = DailyChallengeEngine.record(
        c,
        ChallengeKind.passPairs,
        g.pairsPassed,
      );
      c = DailyChallengeEngine.record(
        c,
        ChallengeKind.perfectStreak,
        g.perfectStreak,
      );
      c = DailyChallengeEngine.record(c, ChallengeKind.collectOrbs, g.orbs);
      c = DailyChallengeEngine.record(c, ChallengeKind.useDash, g.dashUses);
      c = DailyChallengeEngine.record(
        c,
        ChallengeKind.dashShatter,
        g.dashShattered,
      );
      c = DailyChallengeEngine.record(c, ChallengeKind.bloomBonus, g.bloomHits);
      d = d.copyWith(challenges: c);
    }
    final r = _unlockAchievements(d);
    await _commit(r.data);
    return r.unlocked;
  }

  ({SaveData data, List<AchievementDef> unlocked}) _unlockAchievements(
    SaveData d,
  ) {
    if (!retention.achievements) return (data: d, unlocked: const []);
    final fresh = AchievementEngine.newlyUnlocked(
      d.stats,
      d.unlockedAchievements,
    );
    if (fresh.isEmpty) return (data: d, unlocked: const []);
    return (
      data: d.copyWith(
        unlockedAchievements: {
          ...d.unlockedAchievements,
          for (final a in fresh) a.id,
        },
        coins: d.coins + fresh.fold<int>(0, (s, a) => s + a.reward),
      ),
      unlocked: fresh,
    );
  }

  // ---- coins / settings ---------------------------------------------------

  Future<void> addCoins(int n) =>
      _commit(_data.copyWith(coins: _data.coins + n));

  Future<bool> spendCoins(int n) async {
    if (_data.coins < n) return false;
    await _commit(_data.copyWith(coins: _data.coins - n));
    return true;
  }

  // ---- Dash Refill / streak freeze ---------------------------------------

  static const int dashRefillCoinCost = 40;
  static const int streakFreezeCoinCost = 100;
  static const int maxAdRefillsPerDay = 3;

  int get dashRefills => _data.dashRefills;

  /// Rewarded-ad refills still available today.
  int get adRefillsLeft => _data.adRefillDay == today
      ? maxAdRefillsPerDay - _data.adRefillsToday
      : maxAdRefillsPerDay;

  /// Uses one Dash Refill from stock (the next run starts with a full meter).
  Future<bool> consumeDashRefill() async {
    if (_data.dashRefills <= 0) return false;
    await _commit(_data.copyWith(dashRefills: _data.dashRefills - 1));
    return true;
  }

  Future<bool> buyDashRefillWithCoins() async {
    if (_data.coins < dashRefillCoinCost) return false;
    await _commit(
      _data.copyWith(
        coins: _data.coins - dashRefillCoinCost,
        dashRefills: _data.dashRefills + 1,
      ),
    );
    return true;
  }

  /// Grants a Dash Refill earned by a rewarded ad. False when today's cap is used up.
  Future<bool> grantAdDashRefill() async {
    if (adRefillsLeft <= 0) return false;
    final used = _data.adRefillDay == today ? _data.adRefillsToday : 0;
    await _commit(
      _data.copyWith(
        dashRefills: _data.dashRefills + 1,
        adRefillDay: today,
        adRefillsToday: used + 1,
      ),
    );
    return true;
  }

  Future<bool> buyStreakFreeze() async {
    if (_data.coins < streakFreezeCoinCost ||
        _data.streak.freezes >= StreakEngine.maxFreezes) {
      return false;
    }
    await _commit(
      _data.copyWith(
        coins: _data.coins - streakFreezeCoinCost,
        streak: _data.streak.copyWith(freezes: _data.streak.freezes + 1),
      ),
    );
    return true;
  }

  Future<void> setReduceMotion(bool v) =>
      _commit(_data.copyWith(reduceMotion: v));

  Future<void> setSound(bool v) => _commit(_data.copyWith(soundOn: v));
  Future<void> setVibration(bool v) => _commit(_data.copyWith(vibrationOn: v));
  Future<void> setReminders(bool v) => _commit(_data.copyWith(remindersOn: v));

  // ---- purchases ----------------------------------------------------------

  /// Delivers a purchase/restore once. Replays of the same purchaseId are ignored;
  /// restores of non-consumables are idempotent by nature.
  Future<void> deliverPurchase(PurchaseUpdate u, ProductCatalog catalog) async {
    if (u.status != PurchaseStatus.purchased &&
        u.status != PurchaseStatus.restored) {
      return;
    }
    final def = catalog.byId(u.productId);
    if (def == null) return;
    var d = _data;
    if (def.type == ProductType.consumable) {
      final key = u.purchaseId;
      if (u.status == PurchaseStatus.restored) {
        return; // consumables are never restored
      }
      if (key != null && d.processedPurchases.contains(key)) {
        return;
      }
      d = d.copyWith(
        coins: d.coins + def.coins,
        processedPurchases: key == null ? null : {...d.processedPurchases, key},
      );
    } else if (def.grants == ProductDef.removeAdsGrant) {
      d = d.copyWith(adsRemoved: true);
    }
    await _commit(d);
  }
}
