import 'package:flutter_test/flutter_test.dart';
import 'package:texcut/models/expansion_settings.dart';
import 'package:texcut/models/snippet.dart';

void main() {
  group('Snippet', () {
    test('round-trips through JSON', () {
      final s = Snippet(
        id: 'abc',
        shortcut: ';br',
        expansion: 'Best regards',
        label: 'Sign-off',
        group: 'Email',
        usageCount: 4,
      );
      final restored = Snippet.fromJson(s.toJson());
      expect(restored.id, s.id);
      expect(restored.shortcut, s.shortcut);
      expect(restored.expansion, s.expansion);
      expect(restored.label, s.label);
      expect(restored.group, s.group);
      expect(restored.usageCount, 4);
    });

    test('displayTitle falls back to shortcut', () {
      final s = Snippet(id: '1', shortcut: ';x', expansion: 'y');
      expect(s.displayTitle, ';x');
      expect(s.copyWith(label: 'Hi').displayTitle, 'Hi');
    });

    test('newId produces unique ids', () {
      final ids = {for (var i = 0; i < 1000; i++) Snippet.newId()};
      expect(ids.length, 1000);
    });
  });

  group('ExpansionSettings', () {
    test('round-trips through JSON', () {
      const s = ExpansionSettings(
        serviceEnabled: false,
        triggerMode: TriggerMode.instant,
        caseSensitive: false,
        dateFormat: 'dd/MM/yyyy',
      );
      final restored = ExpansionSettings.fromJson(s.toJson());
      expect(restored.serviceEnabled, false);
      expect(restored.triggerMode, TriggerMode.instant);
      expect(restored.caseSensitive, false);
      expect(restored.dateFormat, 'dd/MM/yyyy');
    });

    test('defaults are sensible', () {
      const s = ExpansionSettings();
      expect(s.serviceEnabled, true);
      expect(s.triggerMode, TriggerMode.onDelimiter);
      expect(s.requireWordBoundary, true);
    });
  });
}
