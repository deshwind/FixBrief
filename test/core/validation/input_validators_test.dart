import 'package:fixbrief/core/validation/input_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InputValidators', () {
    test('accepts a valid email and rejects malformed input', () {
      expect(InputValidators.email('alex@example.com'), isNull);
      expect(InputValidators.email('alex@localhost'), isNotNull);
      expect(InputValidators.email(''), 'Email is required.');
    });

    test('requires a long mixed password', () {
      expect(InputValidators.password('FixBriefDemo123'), isNull);
      expect(InputValidators.password('short'), isNotNull);
      expect(InputValidators.password('alllowercase123'), isNotNull);
    });

    test('validates phone length without storing a formatted value', () {
      expect(InputValidators.phone('+44 7700 900000'), isNull);
      expect(InputValidators.phone('123'), isNotNull);
    });
  });
}
