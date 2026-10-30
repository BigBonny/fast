import 'package:fast_resto_bigbonney/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseAmount accepts French comma decimals and currency noise', () {
    expect(parseAmount('12,50'), 12.5);
    expect(parseAmount('12.50'), 12.5);
    expect(parseAmount('  12,50 € '), 12.5);
    expect(parseAmount('9'), 9.0);
    expect(parseAmount(''), isNull);
    expect(parseAmount('abc'), isNull);
    expect(parseAmount('12,50,30'), isNull);
  });

  test('dietary apiValue matches the backend enum exactly', () {
    expect(
      DietaryPreference.values.map((d) => d.apiValue),
      containsAll([
        'VEGAN',
        'VEGETARIAN',
        'GLUTEN_FREE',
        'HALAL',
        'KETO',
        'DAIRY_FREE',
      ]),
    );
  });

  test('dietary tags round-trip: apiValue parses back to the same tag', () {
    for (final tag in DietaryPreference.values) {
      expect(DietaryPreference.fromString(tag.apiValue), tag);
    }
  });
}
