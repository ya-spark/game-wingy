import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wingy/core/config/app_config.dart';
import 'package:wingy/core/share/share_service.dart';
import 'package:wingy/core/tips/tip_service.dart';
import 'package:wingy/game/tips.dart';

/// The real config with its `share:` section (the last one in the file) replaced.
AppConfig configWith(String shareYaml) {
  final real = File('app.config.yaml').readAsStringSync();
  final head = real.substring(0, real.indexOf('\nshare:'));
  return AppConfig.fromYamlString(
    shareYaml.isEmpty ? head : '$head\nshare:\n$shareYaml\n',
  );
}

void main() {
  group('tips', () {
    test('every tip is non-empty, at most 80 characters and unique', () {
      expect(gameTips.length, greaterThanOrEqualTo(15));
      for (final t in gameTips) {
        expect(t.trim(), isNotEmpty);
        expect(t.length, lessThanOrEqualTo(80), reason: t);
      }
      expect(gameTips.toSet().length, gameTips.length);
    });

    test('the same tip never appears twice in a row', () {
      for (var seed = 0; seed < 20; seed++) {
        final svc = TipService(random: Random(seed));
        String? last;
        for (var i = 0; i < gameTips.length * 6; i++) {
          final t = svc.next();
          expect(t, isNot(last), reason: 'seed $seed, draw $i');
          last = t;
        }
      }
    });

    test('a bag deals every tip once before repeating', () {
      final svc = TipService(random: Random(3));
      final bag = {for (var i = 0; i < gameTips.length; i++) svc.next()};
      expect(bag.length, gameTips.length);
    });

    test('tip of the day is stable per day and changes by day', () {
      final svc = TipService();
      expect(svc.tipOfTheDay(100), svc.tipOfTheDay(100));
      expect(svc.tipOfTheDay(100), isNot(svc.tipOfTheDay(101)));
    });
  });

  group('share texts', () {
    test(
      'without a link there is no link line and Share app is a no-op',
      () async {
        final f = FakeShareService();
        expect(f.hasLink, isFalse);
        await f.shareScore(score: 42);
        await f.shareAchievement(title: 'Sky High');
        await f.shareApp(bestScore: 42);
        expect(f.sent.map((e) => e.text), [
          'This is my high score in Wingy: 42. Can you beat it?',
          'I unlocked "Sky High" in Wingy! Can you beat it?',
        ]);
      },
    );

    test('with a link it follows the message on a new line', () async {
      final f = FakeShareService(link: 'https://example.com/x');
      await f.shareScore(score: 7);
      await f.shareAchievement(title: 'Sky High');
      await f.shareApp(bestScore: 9);
      await f.shareApp();
      expect(f.sent.map((e) => e.text), [
        'This is my high score in Wingy: 7. Can you beat it?\nhttps://example.com/x',
        'I unlocked "Sky High" in Wingy! Can you beat it?\nhttps://example.com/x',
        'This is my high score in Wingy: 9. Can you beat it?\nhttps://example.com/x',
        'Try Wingy!\nhttps://example.com/x',
      ]);
    });
  });

  group('share link config', () {
    const url = 'https://play.google.com/apps/internaltest/123';

    test('internal_test uses internal_test_url', () {
      final c = configWith(
        '  link_mode: internal_test\n  internal_test_url: "$url"',
      );
      expect(c.shareLink, url);
    });

    test('the shipped config uses internal_test with the owner URL', () {
      final c = AppConfig.fromYamlString(
        File('app.config.yaml').readAsStringSync(),
      );
      expect(c.share.linkMode, ShareLinkMode.internalTest);
      expect(
        c.shareLink,
        'https://play.google.com/apps/internaltest/4701195701671503239',
      );
    });

    test('store uses the Play Store page of the package', () {
      final c = configWith('  link_mode: store\n  internal_test_url: "$url"');
      expect(
        c.shareLink,
        'https://play.google.com/store/apps/details?id=${c.packageName}',
      );
    });

    test('off adds no link', () {
      final c = configWith('  link_mode: off\n  internal_test_url: "$url"');
      expect(c.shareLink, isNull);
    });

    test('internal_test with an empty URL behaves like off', () {
      expect(configWith('  link_mode: internal_test').shareLink, isNull);
      expect(
        configWith('  link_mode: internal_test\n  internal_test_url: ""')
            .shareLink,
        isNull,
      );
    });

    test('the default mode is internal_test', () {
      expect(configWith('').share.linkMode, ShareLinkMode.internalTest);
    });
  });
}
