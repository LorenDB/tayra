import 'package:flutter_test/flutter_test.dart';
import 'package:tayra/core/api/models.dart';

void main() {
  group('GlobalPreference.fromJson', () {
    test('parses boolean preference', () {
      final pref = GlobalPreference.fromJson({
        'section': 'instance',
        'name': 'nodeinfo_stats_enabled',
        'identifier': 'instance__nodeinfo_stats_enabled',
        'default': true,
        'value': false,
        'verbose_name': 'Enable usage and library stats',
        'help_text': 'Share usage stats in nodeinfo',
        'additional_data': {},
        'field': {
          'class': 'BooleanField',
          'widget': {'class': 'CheckboxInput'},
          'input_type': 'checkbox',
        },
      });
      expect(pref.fieldKind, GlobalPreferenceFieldKind.boolean);
      expect(pref.boolValue, isFalse);
      expect(pref.isEditable, isTrue);
      expect(pref.displayName, 'Enable usage and library stats');
      expect(pref.identifier, 'instance__nodeinfo_stats_enabled');
    });

    test('parses string preference', () {
      final pref = GlobalPreference.fromJson({
        'section': 'instance',
        'name': 'name',
        'identifier': 'instance__name',
        'default': '',
        'value': 'My Pod',
        'verbose_name': 'Public name',
        'help_text': 'Displayed on about page',
        'additional_data': {},
        'field': {
          'class': 'CharField',
          'widget': {'class': 'TextInput'},
          'input_type': 'text',
        },
      });
      expect(pref.fieldKind, GlobalPreferenceFieldKind.string);
      expect(pref.stringValue, 'My Pod');
      expect(pref.isEditable, isTrue);
    });

    test('parses integer preference', () {
      final pref = GlobalPreference.fromJson({
        'section': 'users',
        'name': 'upload_quota',
        'identifier': 'users__upload_quota',
        'default': 1000,
        'value': 2048,
        'verbose_name': 'Upload quota',
        'help_text': 'MB',
        'additional_data': {},
        'field': {
          'class': 'IntegerField',
          'widget': {'class': 'NumberInput'},
          'input_type': 'number',
        },
      });
      expect(pref.fieldKind, GlobalPreferenceFieldKind.integer);
      expect(pref.intValue, 2048);
    });

    test('parses choice preference with additional_data.choices', () {
      final pref = GlobalPreference.fromJson({
        'section': 'instance',
        'name': 'location',
        'identifier': 'instance__location',
        'default': '',
        'value': 'US',
        'verbose_name': 'Server Location',
        'help_text': 'Country code',
        'additional_data': {
          'choices': [
            ['US', 'United States'],
            ['FR', 'France'],
            ['', '——'],
          ],
        },
        'field': {
          'class': 'ChoiceField',
          'widget': {'class': 'Select'},
          'input_type': null,
        },
      });
      expect(pref.fieldKind, GlobalPreferenceFieldKind.choice);
      expect(pref.choices.length, 3);
      expect(pref.choices[0].value, 'US');
      expect(pref.choices[0].label, 'United States');
      expect(pref.labelForChoice('FR'), 'France');
      expect(pref.labelForChoice('XX'), 'XX');
    });

    test('parses multi-choice preference', () {
      final pref = GlobalPreference.fromJson({
        'section': 'users',
        'name': 'default_permissions',
        'identifier': 'users__default_permissions',
        'default': <String>[],
        'value': ['library', 'moderation'],
        'verbose_name': 'Default permissions',
        'help_text': '',
        'additional_data': {
          'choices': [
            ['library', 'Library'],
            ['moderation', 'Moderation'],
            ['settings', 'Settings'],
          ],
        },
        'field': {
          'class': 'MultipleChoiceField',
          'widget': {'class': 'SelectMultiple'},
          'input_type': 'select',
        },
      });
      expect(pref.fieldKind, GlobalPreferenceFieldKind.multiChoice);
      expect(pref.multiValues, ['library', 'moderation']);
      expect(pref.isEditable, isTrue);
    });

    test('parses multi-choice from comma-separated string', () {
      final pref = GlobalPreference.fromJson({
        'section': 'moderation',
        'name': 'languages',
        'identifier': 'moderation__languages',
        'default': '',
        'value': 'en,fr',
        'verbose_name': 'Languages',
        'help_text': '',
        'additional_data': {
          'choices': [
            ['en', 'English'],
            ['fr', 'French'],
          ],
        },
        'field': {
          'class': 'MultipleChoiceField',
          'widget': {'class': 'CheckboxSelectMultiple'},
          'input_type': 'checkbox',
        },
      });
      expect(pref.multiValues, ['en', 'fr']);
    });

    test('marks file preference as non-editable', () {
      final pref = GlobalPreference.fromJson({
        'section': 'instance',
        'name': 'banner',
        'identifier': 'instance__banner',
        'default': null,
        'value': '/media/banner.png',
        'verbose_name': 'Banner image',
        'help_text': 'At least 600x100px',
        'additional_data': {},
        'field': {
          'class': 'FileField',
          'widget': {'class': 'ClearableFileInput'},
          'input_type': 'file',
        },
      });
      expect(pref.fieldKind, GlobalPreferenceFieldKind.file);
      expect(pref.isEditable, isFalse);
      expect(pref.stringValue, '/media/banner.png');
    });

    test('marks JSON / complex field as non-editable', () {
      final pref = GlobalPreference.fromJson({
        'section': 'common',
        'name': 'example_json',
        'identifier': 'common__example_json',
        'default': {'fields': []},
        'value': {
          'fields': [
            {'label': 'Why?', 'required': true, 'input_type': 'long_text'},
          ],
        },
        'verbose_name': 'Example JSON',
        'help_text': '',
        'additional_data': {},
        'field': {
          'class': 'JSONField',
          'widget': {'class': 'Textarea'},
          'input_type': null,
        },
      });
      expect(pref.fieldKind, GlobalPreferenceFieldKind.complex);
      expect(pref.isEditable, isFalse);
    });

    test('builds identifier from section and name when missing', () {
      final pref = GlobalPreference.fromJson({
        'section': 'instance',
        'name': 'terms',
        'default': '',
        'value': 'Be nice',
        'verbose_name': 'Terms of service',
        'help_text': '',
        'additional_data': {},
        'field': {
          'class': 'CharField',
          'widget': {'class': 'Textarea'},
          'input_type': 'text',
        },
      });
      expect(pref.identifier, 'instance__terms');
    });

    test('copyWith updates value and clearValue nulls it', () {
      final pref = GlobalPreference.fromJson({
        'section': 'instance',
        'name': 'name',
        'identifier': 'instance__name',
        'default': '',
        'value': 'A',
        'verbose_name': 'Public name',
        'help_text': '',
        'additional_data': {},
        'field': {
          'class': 'CharField',
          'widget': {'class': 'TextInput'},
          'input_type': 'text',
        },
      });
      expect(pref.copyWith(value: 'B').value, 'B');
      expect(pref.copyWith(value: false).value, false);
      expect(pref.copyWith(clearValue: true).value, isNull);
    });
  });

  group('MeUser.canManageSettings', () {
    test('true when permissions.settings is true', () {
      final me = MeUser.fromJson({
        'id': 1,
        'username': 'admin',
        'permissions': {'settings': true, 'library': false},
        'is_superuser': false,
      });
      expect(me.canManageSettings, isTrue);
      expect(me.canManageLibrary, isFalse);
    });

    test('true for superuser even without settings flag', () {
      final me = MeUser.fromJson({
        'id': 1,
        'username': 'root',
        'permissions': {},
        'is_superuser': true,
      });
      expect(me.canManageSettings, isTrue);
      expect(me.permissions['settings'], isTrue);
    });

    test('false without permission', () {
      final me = MeUser.fromJson({
        'id': 2,
        'username': 'user',
        'permissions': {'library': true},
        'is_superuser': false,
      });
      expect(me.canManageSettings, isFalse);
    });
  });
}
