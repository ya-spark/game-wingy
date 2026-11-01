import 'package:flutter/material.dart';

import '../core/config/products.dart';
import '../core/profile/profile_store.dart';
import '../core/retention/streaks.dart';
import '../core/services.dart';
import 'test_ids.dart';
import 'widgets.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
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
            final products = s.purchases.products;
            final p = s.profile;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
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
                const Divider(),
                if (!s.purchases.available || products.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      key: TestIds.shopUnavailable,
                      child: Text('Store unavailable right now.'),
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
                                onPressed: () => s.purchases.buy(pr.def.id),
                                child: Text(pr.price),
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

  bool _owned(Services s, ProductDef d) =>
      d.grants == ProductDef.removeAdsGrant && s.profile.data.adsRemoved;
}
