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
        expect(singleton.instance, same(value));
      });

      test("recreate singleton", () {
        final recreated = Singleton<TestObject>();

        expect(recreated, same(singleton));
        expect(recreated.instance, same(value));
      });

      test("ensure value", () async {
        expect(await singleton.ensuredInstance(), same(value));
      });

      test("deregister", () {
        singleton.deregister();
        expect(() => Singleton.register(TestObject()), returnsNormally);
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
        expect(singleton.instance, same(value));
      });

      test("throw state error before future is resolved", () {
        expect(() => singleton.instance, throwsStateError);
      });

      test("rethrow error on get value", () async {
        final exception = Exception("testException");

        completer.completeError(exception);
        await breath();

        expect(() => singleton.instance, throwsA(same(exception)));
      });

      test("recreate singleton", () async {
        final recreated = Singleton<TestObject>();
        expect(recreated, same(singleton));

        completer.complete(value);
        await breath();

        expect(recreated.instance, same(value));
      });

      test("ensure value", () async {
        expect(singleton.ensuredInstance(), isA<Future<TestObject>>());

        completer.complete(value);

        expect(await singleton.ensuredInstance(), same(value));
      });

      test("deregister", () {
        singleton.deregister();
        expect(() => Singleton.register(TestObject()), returnsNormally);
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
        expect(singleton.instance, isA<TestObject>());
      });

      test("create on demand", () {
        final base = TestObject.nextInstanceId;
        expect(singleton.instance, isA<TestObject>());
        final after1st = TestObject.nextInstanceId;
        expect(singleton.instance, isA<TestObject>());
        final after2nd = TestObject.nextInstanceId;
        singleton.deregister();
        expect(singleton.instance, isA<TestObject>());
        final after3nd = TestObject.nextInstanceId;

        expect(after1st, base + 1);
        expect(after2nd, base + 1);
        expect(after3nd, base + 2);
      });

      test("recreate singleton", () {
        final recreated = Singleton<TestObject>();

        expect(recreated, same(singleton));
        expect(recreated.instance, same(singleton.instance));
      });

      test("re-register won't complain", () {
        final recreated = Singleton.lazy(() => TestObject());

        expect(recreated, same(singleton));
        expect(recreated.instance, same(singleton.instance));
      });

      test("ensure value", () async {
        expect(await singleton.ensuredInstance(), isA<TestObject>());
      });

      test("deregister", () {
        final first = singleton.instance;
        final second = singleton.instance;
        singleton.deregister();
        final third = singleton.instance;

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
        expect(() => singleton.instance, throwsUnimplementedError);
      });

      test("ensure value", () {
        expect(() => singleton.ensuredInstance(), throwsUnimplementedError);
      });

      test("reset value works", () {
        expect(() => singleton.deregister(), returnsNormally);
      });

      test("won't register itself", () {
        expect(() => Singleton.register(TestObject()), returnsNormally);
      });
    });

    group("ensureInstanceFor", () {
      Completer<TestObject> completer;
      int timeCheckPoint;

      setUp(() {
        Singleton.resetAllForTest();

        timeCheckPoint = 0;
        completer = Completer();

        Singleton.lazy(() => "string");
        Singleton.register(Object());
        Singleton.register(completer.future);
      });

      tearDown(() {
        Singleton.resetAllForTest();
      });

      Future checkSingletons(int before, int after) async {
        expect(timeCheckPoint, before);
        expect(() => Singleton<TestObject>().instance, throwsStateError);

        await Singleton.ensureInstanceFor([String, Object, TestObject]);

        expect(Singleton<TestObject>().instance, isA<TestObject>());
        expect(timeCheckPoint, after);
      }

      test("it ensure time sequence", () async {
        final future = checkSingletons(0, 1);

        timeCheckPoint++;
        completer.complete(TestObject());

        await future;
      });

      test("it support type", () async {
        expect(() => Singleton<TestObject>().instance, throwsStateError);

        completer.complete(TestObject());
        await Singleton.ensureInstanceFor(TestObject);

        expect(Singleton<TestObject>().instance, isA<TestObject>());
      });

      test("it support singleton", () async {
        expect(() => Singleton<TestObject>().instance, throwsStateError);

        completer.complete(TestObject());
        await Singleton.ensureInstanceFor(Singleton<TestObject>());

        expect(Singleton<TestObject>().instance, isA<TestObject>());
      });

      test("it support type in list", () async {
        expect(() => Singleton<TestObject>().instance, throwsStateError);

        completer.complete(TestObject());
        await Singleton.ensureInstanceFor([TestObject]);

        expect(Singleton<TestObject>().instance, isA<TestObject>());
      });

      test("it support singleton in list", () async {
        expect(() => Singleton<TestObject>().instance, throwsStateError);

        completer.complete(TestObject());
        await Singleton.ensureInstanceFor([Singleton<TestObject>()]);

        expect(Singleton<TestObject>().instance, isA<TestObject>());
      });
    });
  });
}
