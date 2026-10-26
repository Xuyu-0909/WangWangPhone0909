import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wangwang_phone/app/startup/startup_security_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Browser startup starts without a passcode', () async {
    final store = SharedPreferencesStartupSecurityStore();
    await store.initialize();

    expect(await store.readPasscode(), isNull);
    expect(await store.hasPasscode(), isFalse);
  });

  test('Browser startup restores a saved passcode in a new store', () async {
    final store = SharedPreferencesStartupSecurityStore();
    await store.initialize();
    await store.writePasscode('246810');

    final restoredStore = SharedPreferencesStartupSecurityStore();
    await restoredStore.initialize();
    expect(await restoredStore.readPasscode(), '246810');
    expect(await restoredStore.hasPasscode(), isTrue);

    await restoredStore.writePasscode('135790');
    expect(await store.readPasscode(), '135790');
  });

  test('Browser startup ignores an invalid saved passcode', () async {
    SharedPreferences.setMockInitialValues({startupPasscodeSettingKey: '123'});
    final store = SharedPreferencesStartupSecurityStore();

    expect(await store.hasPasscode(), isFalse);
  });
}
