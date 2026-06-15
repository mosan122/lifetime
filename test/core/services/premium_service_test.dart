import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lifetime/core/services/premium_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('isPremium is false before init()', () {
    final service = PremiumService();
    expect(service.isPremium, isFalse);
  });

  test('init() loads false when no preference is stored', () async {
    final service = PremiumService();
    await service.init();
    expect(service.isPremium, isFalse);
  });

  test('init() loads true when preference was previously set to true', () async {
    SharedPreferences.setMockInitialValues({'is_premium': true});
    final service = PremiumService();
    await service.init();
    expect(service.isPremium, isTrue);
  });

  test('setPremium(true) updates getter immediately', () async {
    final service = PremiumService();
    await service.init();
    await service.setPremium(true);
    expect(service.isPremium, isTrue);
  });

  test('setPremium(false) reverts the getter', () async {
    SharedPreferences.setMockInitialValues({'is_premium': true});
    final service = PremiumService();
    await service.init();
    await service.setPremium(false);
    expect(service.isPremium, isFalse);
  });

  test('setPremium persists across instances', () async {
    final serviceA = PremiumService();
    await serviceA.init();
    await serviceA.setPremium(true);

    final serviceB = PremiumService();
    await serviceB.init();
    expect(serviceB.isPremium, isTrue);
  });
}
