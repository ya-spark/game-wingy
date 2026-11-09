import 'dart:math';

import 'package:flutter/material.dart';

import '../core/config/products.dart';
import '../core/profile/profile_store.dart';
import '../core/purchase/purchase_service.dart';
import '../core/retention/streaks.dart';
import '../core/services.dart';
import '../core/skins/flyer_skins.dart';
import '../game/flame/wingy_painter.dart';
import 'parent_gate.dart';
import 'test_ids.dart';
import 'widgets.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  bool _loading = false;
  bool _requested = false;

  /// Billing may not have been ready at app start (or failed once), so every shop
  /// visit asks the store again and rebuilds when it answers.
  Future<void> _reload(Services s) async {
    if (_loading) return;
    setState(() => _loading = true);
    await s.purchases.initialize();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    if (!_requested) {
      _requested = true;
      if (!s.purchases.available || s.purchases.products.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _reload(s);
        });
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Shop',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: KidColors.ocean,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            key: TestIds.shopRestore,
            onPressed: s.purchases.restore,
            child: const Text('Restore'),
          ),
        ],
      ),
      body: KidPage(
        child: ListenableBuilder(
          listenable: s.profile,
          builder: (context, _) {
            final products = _ordered(s.purchases.products);
            final p = s.profile;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (!s.purchases.available || products.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      key: TestIds.shopUnavailable,
                      child: _loading
                          ? const CircularProgressIndicator()
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              spacing: 12,
                              children: [
                                Text(
                                  s.purchases.available
                                      ? 'These items are not on Google Play yet.'
                                      : 'Cannot reach Google Play. Check your '
                                            'connection and that the game was '
                                            'installed from Google Play.',
                                  textAlign: TextAlign.center,
                                ),
                                OutlinedButton(
                                  onPressed: () => _reload(s),
                                  child: const Text('Try again'),
                                ),
                              ],
                            ),
                    ),
                  )
                else
                  for (final pr in products)
                    KidPanel(
                      child: ListTile(
                        title: Text(pr.def.title),
                        subtitle: Text(pr.def.description),
                        trailing: _owned(s, pr.def)
                            ? const Chip(label: Text('Owned'))
                            : FilledButton(
                                key: TestIds.shopBuy(pr.def.id),
                                onPressed: () => _buy(context, s, pr.def.id),
                                child: Text(pr.price),
                              ),
                      ),
                    ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 12, 4, 4),
                  child: Text(
                    'Wings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: KidColors.ink,
                    ),
                  ),
                ),
                for (final skin in FlyerSkins.all)
                  _SkinCard(skin: skin, profile: p),
                const Divider(),
                KidPanel(
                  child: ListTile(
                    leading: const Icon(Icons.bolt),
                    title: const Text('Dash Refill'),
                    subtitle: Text(
                      'Start a run with a full Glow Dash (you have ${p.dashRefills})',
                    ),
                    trailing: FilledButton(
                      key: TestIds.shopBuyRefill,
                      onPressed: p.data.coins >= ProfileStore.dashRefillCoinCost
                          ? p.buyDashRefillWithCoins
                          : null,
                      child: const Text(
                        '${ProfileStore.dashRefillCoinCost} coins',
                      ),
                    ),
                  ),
                ),
                KidPanel(
                  child: ListTile(
                    leading: const Icon(Icons.ac_unit),
                    title: const Text('Streak freeze'),
                    subtitle: Text(
                      'Covers one missed day (you have ${p.data.streak.freezes})',
                    ),
                    trailing: FilledButton(
                      key: TestIds.shopBuyFreeze,
                      onPressed:
                          p.data.coins >= ProfileStore.streakFreezeCoinCost &&
                              p.data.streak.freezes < StreakEngine.maxFreezes
                          ? p.buyStreakFreeze
                          : null,
                      child: const Text(
                        '${ProfileStore.streakFreezeCoinCost} coins',
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Remove Ads first, then the coin packs in ascending size.
  static List<StoreProduct> _ordered(List<StoreProduct> all) {
    final removeAds = all.where((p) => p.def.coins == 0).toList();
    final packs = all.where((p) => p.def.coins > 0).toList()
      ..sort((a, b) => a.def.coins.compareTo(b.def.coins));
    return [...removeAds, ...packs];
  }

  /// Real-money purchases always go through the parent gate first.
  static Future<void> _buy(
    BuildContext context,
    Services s,
    String productId,
  ) async {
    final ok = await showParentGate(context, s.parentGate);
    if (ok) await s.purchases.buy(productId);
  }

  bool _owned(Services s, ProductDef d) =>
      d.grants == ProductDef.removeAdsGrant && s.profile.data.adsRemoved;
}

class _SkinCard extends StatelessWidget {
  const _SkinCard({required this.skin, required this.profile});
  final FlyerSkin skin;
  final ProfileStore profile;

  @override
  Widget build(BuildContext context) {
    final owned = profile.ownsSkin(skin.id);
    final equipped = profile.equippedSkin == skin.id;
    final Widget action;
    if (equipped) {
      action = const Chip(label: Text('Equipped'));
    } else if (owned) {
      action = FilledButton(
        key: TestIds.shopSkinEquip(skin.id),
        onPressed: () => profile.equipSkin(skin.id),
        child: const Text('Equip'),
      );
    } else {
      action = FilledButton(
        key: TestIds.shopSkinBuy(skin.id),
        onPressed: profile.data.coins >= skin.price
            ? () => profile.buySkin(skin.id)
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [const CoinIcon(size: 20), Text('${skin.price}')],
        ),
      );
    }
    return KidPanel(
      key: TestIds.shopSkin(skin.id),
      child: ListTile(
        leading: SizedBox(
          width: 72,
          height: 56,
          child: _SkinPreview(skin: skin, animate: !profile.data.reduceMotion),
        ),
        title: Text(skin.name),
        subtitle: owned ? const Text('Owned') : null,
        trailing: action,
      ),
    );
  }
}

/// Small animated preview of a skin: the flyer bobbing and flapping. Still on Reduce motion.
class _SkinPreview extends StatefulWidget {
  const _SkinPreview({required this.skin, required this.animate});
  final FlyerSkin skin;
  final bool animate;

  @override
  State<_SkinPreview> createState() => _SkinPreviewState();
}

class _SkinPreviewState extends State<_SkinPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  final WingyPainter _painter = WingyPainter();

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(_SkinPreview old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.animate && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _painter.skin = widget.skin;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1446),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        painter: _PreviewPainter(_painter, _c),
        size: Size.infinite,
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.painter, this.t) : super(repaint: t);
  final WingyPainter painter;
  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    painter.time = v * 3;
    final frame = (v * 3).floor() % 3;
    painter.drawMoth(
      canvas,
      size.width / 2,
      size.height / 2 + sin(v * 2 * pi) * 4,
      tilt: 0.1 * sin(v * 2 * pi),
      frame: frame,
    );
  }

  @override
  bool shouldRepaint(_PreviewPainter old) => old.painter != painter;
}
