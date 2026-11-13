import 'package:flutter_test/flutter_test.dart';
import 'package:nexusride/core/constants/app_constants.dart';

void main() {
  group('AppConstants.validateValues', () {
    const base = {
      'supabaseUrl': 'https://project.supabase.co',
      'supabasePublishableKey': 'public-test-key',
      'googleMapsKey': 'maps-test-key',
      'googleMapsKeyName': 'GOOGLE_MAPS_KEY_ANDROID',
    };

    test('accepts complete configuration', () {
      expect(
        () => AppConstants.validateValues(
          supabaseUrl: base['supabaseUrl']!,
          supabasePublishableKey: base['supabasePublishableKey']!,
          googleMapsKey: base['googleMapsKey']!,
          googleMapsKeyName: base['googleMapsKeyName']!,
        ),
        returnsNormally,
      );
    });

    test('rejects missing Supabase URL', () {
      expect(
        () => AppConstants.validateValues(
          supabaseUrl: '',
          supabasePublishableKey: base['supabasePublishableKey']!,
          googleMapsKey: base['googleMapsKey']!,
          googleMapsKeyName: base['googleMapsKeyName']!,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('SUPABASE_URL'),
          ),
        ),
      );
    });

    test('rejects malformed Supabase URL', () {
      expect(
        () => AppConstants.validateValues(
          supabaseUrl: 'project.supabase.co',
          supabasePublishableKey: base['supabasePublishableKey']!,
          googleMapsKey: base['googleMapsKey']!,
          googleMapsKeyName: base['googleMapsKeyName']!,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects missing anon key and platform Maps key', () {
      expect(
        () => AppConstants.validateValues(
          supabaseUrl: base['supabaseUrl']!,
          supabasePublishableKey: ' ',
          googleMapsKey: base['googleMapsKey']!,
          googleMapsKeyName: base['googleMapsKeyName']!,
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        () => AppConstants.validateValues(
          supabaseUrl: base['supabaseUrl']!,
          supabasePublishableKey: base['supabasePublishableKey']!,
          googleMapsKey: '',
          googleMapsKeyName: 'GOOGLE_MAPS_KEY_IOS',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('GOOGLE_MAPS_KEY_IOS'),
          ),
        ),
      );
    });
  });
}
