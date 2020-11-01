import 'dart:async';

import 'package:test/test.dart';

import 'package:singleton/singleton.dart';

class TestObject {
  final int instanceId;

  TestObject() : instanceId = _nextInstanceId++;

  static int _nextInstanceId = 0;

  static int get nextInstanceId => _nextInstanceId;
}

Future breath() async {}

void main() {
  group("Singleton", () {
    final value = TestObject();
    Singleton<TestObject> singleton;

    group("register value", () {
      setUpAll(() {
        singleton = Singleton<TestObject>.register(value);
      });

      tearDownAll(() {
        Singleton.resetAllForTest();
      });

      test("complain on register again", () {
        expect(() => Singleton<TestObject>.register(value), throwsStateError);
      });

      test("get value", () {
        expect(singleton.value, same(value));
      });

      test("recreate singleton", () {
        final recreated = Singleton<TestObject>();

        expect(recreated, same(singleton));
        expect(recreated.value, same(value));
      });

      test("ensure value", () {
        expect(singleton.ensureValue(), same(value));
      });

      test("reset value not supported", () {
        expect(() => singleton.resetValue(), throwsUnsupportedError);
      });
    });

    group("register future", () {
      Completer<TestObject> completer;

      setUp(() {
        completer = Completer();
        singleton = Singleton.register(completer.future);
      });

      tearDown(() {
        Singleton.resetAllForTest();
      });

      test("complain on register again", () {
        expect(() => Singleton<TestObject>.register(value), throwsStateError);
      });

      test("get value", () async {
        completer.complete(value);

        await breath();
        expect(singleton.value, same(value));
      });

      test("throw state error before future is resolved", () {
        expect(() => singleton.value, throwsStateError);
      });

      test("rethrow error on get value", () async {
        final exception = Exception("testException");

        completer.completeError(exception);
        await breath();

        expect(() => singleton.value, throwsA(same(exception)));
      });

      test("recreate singleton", () async {
        final recreated = Singleton<TestObject>();
        expect(recreated, same(singleton));

        completer.complete(value);
        await breath();

        expect(recreated.value, same(value));
      });

      test("ensure value", () async {
        expect(singleton.ensureValue(), isA<Future<TestObject>>());

        completer.complete(value);

        expect(await singleton.ensureValue(), same(value));
      });

      test("reset value not supported", () {
        expect(() => singleton.resetValue(), throwsUnsupportedError);
      });
    });

    group("lazy", () {
      setUp(() {
        singleton = Singleton.lazy(() => TestObject());
      });

      tearDown(() {
        Singleton.resetAllForTest();
      });

      test("get value", () {
        expect(singleton.value, isA<TestObject>());
      });

      test("create on demand", () {
        final base = TestObject.nextInstanceId;
        expect(singleton.value, isA<TestObject>());
        final after1st = TestObject.nextInstanceId;
        expect(singleton.value, isA<TestObject>());
        final after2nd = TestObject.nextInstanceId;
        singleton.resetValue();
        expect(singleton.value, isA<TestObject>());
        final after3nd = TestObject.nextInstanceId;

        expect(after1st, base + 1);
        expect(after2nd, base + 1);
        expect(after3nd, base + 2);
      });

      test("recreate singleton", () {
        final recreated = Singleton<TestObject>();

        expect(recreated, same(singleton));
        expect(recreated.value, same(singleton.value));
      });

      test("re-register won't complain", () {
        final recreated = Singleton.lazy(() => TestObject());

        expect(recreated, same(singleton));
        expect(recreated.value, same(singleton.value));
      });

      test("ensure value", () {
        expect(singleton.ensureValue(), isA<TestObject>());
      });

      test(" reset value", () {
        final first = singleton.value;
        final second = singleton.value;
        singleton.resetValue();
        final third = singleton.value;

        expect([first, second, third], everyElement(isA<TestObject>()));

        expect(first, same(second));
        expect(third, isNot(same(second)));
      });
    });

    group("unknown", () {
      setUp(() {
        singleton = Singleton<TestObject>();
      });

      test("get value", () {
        expect(() => singleton.value, throwsUnimplementedError);
      });

      test("ensure value", () {
        expect(() => singleton.ensureValue(), throwsUnimplementedError);
      });

      test("reset value not supported", () {
        expect(() => singleton.resetValue(), throwsUnimplementedError);
      });

      test("won't register itself", () {
        expect(() => Singleton.register(TestObject()), returnsNormally);
      });
    });
  });
}
