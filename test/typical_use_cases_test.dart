import 'package:singleton/singleton.dart';
import 'package:test/test.dart';

class MyLazyService {
  /// Factory method that reuse same instance automatically
  factory MyLazyService() => Singleton.lazy(() => MyLazyService._());

  /// Private constructor
  MyLazyService._() {}

  /// do something
  void doSomething() {}
}

class MyApi {}

class MyEagerService {
  /// Factory method that reuse same instance automatically
  factory MyEagerService() => Singleton.get<MyEagerService>();

  final MyApi api;

  /// Constructor create and register new instance
  MyEagerService.initialize(this.api) {
    // Register current instance
    Singleton.register(this);
  }

  /// do something
  void doSomething() {}
}

class AppSettings {
  static Future<AppSettings> loadAppSettings() => Future.value(AppSettings());
}

class HttpClient {
  final AppSettings appSettings;

  HttpClient(this.appSettings);
}

class MyFutureService {
  /// Factory method that reuse same instance automatically
  factory MyFutureService() => Singleton<MyFutureService>().instance;

  static Future<MyFutureService> createInstance() async {
    final appSettings = await Singleton<AppSettings>().ensuredInstance();

    final httpClient = HttpClient(appSettings);

    return MyFutureService._(httpClient);
  }

  final HttpClient httpClient;

  MyFutureService._(this.httpClient);

  /// Some method
  void doSomething() {}
}

void main() {
  group('typical use cases', () {
    group("MyLazyService", () {
      tearDown(() {
        Singleton.resetAllForTest();
      });

      test("it creates instance", () {
        expect(MyLazyService(), isA<MyLazyService>());
      });

      test("it is singleton", () {
        expect(MyLazyService(), same(MyLazyService()));
      });

      test("it does something", () {
        expect(() => MyLazyService().doSomething(), returnsNormally);
      });
    });

    group("MyObjectService", () {
      final objectApi = MyApi();

      setUpAll(() {
        MyEagerService.initialize(objectApi);
      });

      tearDownAll(() {
        Singleton.resetAllForTest();
      });

      test("it creates instance", () {
        expect(MyEagerService(), isA<MyEagerService>());
      });

      test("it is singleton", () {
        expect(MyEagerService(), same(MyEagerService()));
      });

      test("it has properties", () {
        expect(MyEagerService().api, same(objectApi));
      });

      test("it does something", () {
        expect(() => MyEagerService().doSomething(), returnsNormally);
      });
    });

    group("FutureSingleton", () {
      setUp(() async {
        // Register AppSettings settings as a future singleton
        Singleton.register(AppSettings.loadAppSettings());

        // Create and register the the MyService as singleton
        Singleton.register(MyFutureService.createInstance());

        Singleton.ensureInstanceFor([AppSettings, MyFutureService]);
      });

      tearDown(() {
        Singleton.resetAllForTest();
      });

      test("it creates instance", () {
        expect(MyFutureService(), isA<MyFutureService>());
      });

      test("it is singleton", () {
        expect(MyFutureService(), same(MyFutureService()));
      });

      test("it has properties", () {
        expect(MyFutureService().httpClient, isA<HttpClient>());
        expect(MyFutureService().httpClient.appSettings,
            same(Singleton<AppSettings>().instance));
      });

      test("it does something", () {
        expect(() => MyFutureService().doSomething(), returnsNormally);
      });
    });
  });
}
