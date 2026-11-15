import 'package:cornerstone/ui/widgets/activity_package/activity_package_appearance.dart';
import 'package:cornerstone/ui/widgets/activity_package/activity_package_protocol.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'packages receive the active app palette and an authenticated update envelope',
    () {
      final light = ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
      );
      final dark = ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
      );
      final appearance = activityPackageAppearance(dark);
      expect(appearance['mode'], 'dark');
      expect(activityPackageAppearance(light)['mode'], 'light');
      final colors = appearance['colors'] as Map<String, dynamic>;
      expect(
        colors['primary'],
        '#${(dark.colorScheme.primary.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0')}',
      );
      expect(
        colors.values.every(
          (value) => RegExp(r'^#[0-9a-f]{6}$').hasMatch(value as String),
        ),
        isTrue,
      );
      final protocol = ActivityPackageProtocol(
        onCheck: (_, _) async => {},
        onComplete: (_, _) async => {},
      );
      expect(
        protocol.initialize({}, appearance: appearance)['appearance'],
        appearance,
      );
      final update = protocol.appearance(appearance);
      expect(update['type'], 'appearance');
      expect(update['channel'], protocol.channel);
      expect(update.containsKey('payload'), isFalse);
      expect(update.containsKey('responses'), isFalse);
    },
  );
}
