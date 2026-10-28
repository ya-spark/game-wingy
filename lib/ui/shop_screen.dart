import 'package:flutter/material.dart';

import '../core/config/products.dart';
import '../core/retention/economy.dart';
import '../core/services.dart';
import 'test_ids.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        actions: [
          TextButton(
            key: TestIds.shopRestore,
            onPressed: s.purchases.restore,
            child: const Text('Restore'),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: s.profile,
        builder: (context, _) {
          final products = s.purchases.products;
          final p = s.profile;
          return ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.bolt, color: Colors.cyanAccent),
                title: const Text('Dash Refill'),
                subtitle: Text(
                  'Start a run with a full Glow Dash meter (you have ${p.dashRefills})',
                ),
                trailing: FilledButton(
                  key: TestIds.shopBuyRefill,
                  onPressed: p.data.coins >= Economy.dashRefillCost
                      ? p.buyDashRefill
                      : null,
                  child: Text('${Economy.dashRefillCost} coins'),
                ),
              ),
              if (s.config.retention.streaks)
                ListTile(
                  leading: const Icon(
                    Icons.ac_unit,
                    color: Colors.lightBlueAccent,
                  ),
                  title: const Text('Streak freeze'),
                  subtitle: Text(
                    'Covers one missed day (you have ${p.data.streak.freezes})',
                  ),
                  trailing: FilledButton(
                    key: TestIds.shopBuyFreeze,
                    onPressed: p.canBuyStreakFreeze ? p.buyStreakFreeze : null,
                    child: Text('${Economy.streakFreezeCost} coins'),
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
                ),
              for (final product in products)
                ListTile(
                  title: Text(product.def.title),
                  subtitle: Text(product.def.description),
                  trailing: _owned(s, product.def)
                      ? const Chip(label: Text('Owned'))
                      : FilledButton(
                          key: TestIds.shopBuy(product.def.id),
                          onPressed: () => s.purchases.buy(product.def.id),
                          child: Text(product.price),
                        ),
                ),
            ],
          );
        },
      ),
    );
  }

  bool _owned(Services s, ProductDef d) =>
      d.grants == ProductDef.removeAdsGrant && s.profile.data.adsRemoved;
}
