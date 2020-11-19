# singleton

[![Star this Repo](https://img.shields.io/github/stars/timnew/singleton.dart.svg?style=flat-square)](https://github.com/timnew/singleton.dart)
[![Pub Package](https://img.shields.io/pub/v/singleton.svg?style=flat-square)](https://pub.dev/packages/singleton)
[![Build Status](https://img.shields.io/github/workflow/status/timnew/singleton.dart/Run-Test)](https://github.com/timnew/singleton.dart/actions?query=workflow%3ARun-Test)

## Why create this library

Singleton is useful pattern, it can help to:

* instantiate objects lazily to speed up app loading
* instantiate objects on demand, so it reduce memory wasted on unused objects
* object is either complicated or expensive to instantiate, but it is used across the app, so having a singleton is economic option
* object depends on asynchronous resources, but need to be used in synchronous way. So it has been to created before hand.

But sometimes, singleton could be a hassle to use, because:

* Implement lazy pattern every time used is painful and could be avoided.
* Singleton are very unfriendly to unit test, as it lives through the test, could cause unexpected test failure.
* Singleton depends on asynchronous resource could be complicated to manage.

`Singleton` library is designed to make those scenario less hassle, enable developer to use Singletons in dart elegantly.

## What this library can do

This library majorly supports 3 different singleton usage:

* Lazy Singleton: Type is created lazily and on demand. It behaves similar to [Kotlin lazy delegated property](https://kotlinlang.org/docs/reference/delegated-properties.html#lazy).
* Eager Singleton: Type is complicated to create, or creation depends on resources only available in some cases. So eagerly creating an instance could be good idea. [Kotlin object declaration](https://kotlinlang.org/docs/reference/object-declarations.html#object-declarations)
* Future Singleton: Type depends on async resource to instantiate, but needs to be used in synchronous-enforced environment, such as depends on `SharedPreferences`'s value in Widget `build` method.
* Allow to reset all registered singleton for test, so across test pollution can be mitigated.

This library is designed with `Flutter` in mind, but it doesn't depends on any flutter specific code, so it can be used anywhere dart works.

## Lazy Singleton

### Implement lazy singleton manually

You might write following code a thousand times:

```dart
class MyLazyService {
  static MyLazyService _instance;
  static MyLazyService get instance {
    if (_instance == null) {
      _instance = MyLazyService._();
    }

    return _instance;
  }

  /// Private constructor
  MyLazyService._() {
  }

  /// do something
  void doSomething(){

  }
}

MyLazyService.instance.doSomething();
```
It is working but boring to write, and it has some issues, such as pollutes test.

### Lazy singleton with `Singleton`

```dart
class MyLazyService {
  /// Factory method that reuse same instance automatically
  factory MyLazyService() => Singleton.lazy(() => MyLazyService._()).instance;

  /// Private constructor
  MyLazyService._() {}

  /// do something
  void doSomething() {}
}

MyLazyService().doSomething() // Look like a new instance but it is a singleton.
```

## Eager Singleton

```dart
class MyEagerService {
  /// Factory method that reuse same instance automatically
  factory MyEagerService() => Singleton<MyEagerService>().instance;

  final MyApi api;

  /// Constructor create and register new instance
  MyEagerService.initialize(this.api) {
    // Register current instance
    Singleton.register(this);
  }

  /// do something
  void doSomething() {}
}

void main() {
  final appSettings = getAppSettings();
  final httpClient = createHttpClient(appSetting);
  final api = createApi(httpClient);

  MyEagerService.initialize(api) // Create and register the the singleton
                .doSomething();  // Use the instance
}

MyEagerService().doSomething(); // Use the singleton instance
```

## Future Singleton

It could be tricky to deal with the singleton which depends on async resource. Unfortunately in Flutter/Dart, async resources is everywhere.

Here is a close-to-real example how to deal with this case with Singleton library:

Some background types declaration:

```dart
class AppSettings {
  static Future<AppSettings> loadAppSettings() {
    // load app settings from somewhere asynchronously
  }
}

class HttpClient {
  final AppSettings appSettings;

  HttpClient(this.appSettings);
}
```

Type uses Future singleton

```dart
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
```

Register future singleton. `Singleton.register` understands `Future`, which resolves `Future` and registered the value of `Future` as singleton.

```dart
void main() {
  // Register AppSettings settings as a future singleton
  Singleton.register(AppSettings.loadAppSettings());

  // Create and register the the MyService as singleton
  Singleton.register(MyFutureService.createInstance());

  runApp();
}
```

### Use Future Singleton

Future singleton can be used as other types of singleton,

```dart
MyFutureService().doSomething();
```

But as the singleton is parsed from future, singleton is used before the future resolves, an `StateError` says "ingleton is being used before being resolved" would be thrown.

The error can be omit by ensure the instance execute ensure instance creation at check point convenient:

```dart
await Singleton.ensureInstanceFor(MyFutureService);

```
Multiple types can be checked together:

```dart
await Singleton.ensureInstanceFor([MyFutureService, AppSettings]);
```

### Errors

If error is thrown by the future, the error won't lost, it is rethron when `Singleton.ensureInstanceFor` or `Singleton.instance` is called.

## Support Unit Test

Singleton could cause unexpected test failure due to they lives across the test boundary. Singletons created by `Singleton` library can be cleared via apis that only visible in tests.

```dart
setUp((){
  // Reset singleton registry before setup environment to avoid potentially pollution
  Singleton.resetAllForTest();

  Singleton.register(....) //
});

tearDown(() {
  Singleton.resetAllForTest(); // Reset singleton registry to avoid singleton pollution
});
```

## Find out what is registered

Sometimes you might want to check the singleton status for diagnosis purpose. you can achieve it by:

```dart
Singleton.debugPrintAll();
```

Or you only cares about a certain types

```dart
Singleton.debugPrintAll(MySingleton);

Singleton.debugPrintAll(Singleton<MySingleton>());

Singleton.debugPrintAll([MySingleton, AnotherSingleton]);

Singleton.debugPrintAll([Singleton<MySingleton>(), Singleton<AnotherSingleton>()]);

Singleton.debugPrintAll([Singleton<MySingleton>(), AnotherSingleton]);
```

## Remove singleton

This suppose to be rare, but in some extreme case, if you want to get rid of your singleton. It is possible:

```dart
Singleton<MySingleton>().deregister();
```

## License

The MIT License (MIT)