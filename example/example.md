# Singleton Examples

## Lazy Singleton

### Define Lazy Singleton

```dart
class MyLazyService {
  /// Factory method that reuse same instance automatically
  factory MyLazyService() => Singleton.lazy(() => MyLazyService._()).instance;

  /// Private constructor
  MyLazyService._() {}

  /// do something
  void doSomething() {}
}
```

### Use Lazy Singleton

```dart
MyLazyService().doSomething() // Use the singleton instance
```

## Eager Singleton

### Define Eager Singleton

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
```

### Initialize eagerly

```dart
void main() {
  final appSettings = getAppSettings();
  final httpClient = createHttpClient(appSetting);
  final api = createMyApi(httpClient);

  MyEagerService.initialize(api) // Create and register the the singleton
                .doSomething();  // Use the instance
}
```

### Use Eager Singleton

```dart
MyEagerService().doSomething(); // Use the singleton instance
```

## Future Singleton

### Define the type

Given some other dependants declarations

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

### Register future as singleton

`Singleton.register` understands future, it register value of future as singleton rather than register future itself

```dart
void main() {
  // Register AppSettings settings as a future singleton
  Singleton.register(AppSettings.loadAppSettings());

  // Create and register the the MyService as singleton
  Singleton.register(MyFutureService.createInstance());

  runApp();
}
```

### Use future singleton

For sure you still can use this approach to consume future singleton.

```dart
MyFutureService().doSomething();
```

It is likely to be okay if when async resource although load asynchronously but will be available fast, such as `SharedPreferences`.
But you might encounter `StateError` says "singleton is being used before being resolved".

### Availability checkpoint

```dart
(await Singleton<MyService>().ensuredInstance()).doSomething();
```

This is a more reliable way, but it removes almost all the benefits to have a sync singleton.

So run following code before usage, such as in `main` after register all singleton types

```dart

void main() async {
  // Register AppSettings settings as a future singleton
  Singleton.register(AppSettings.loadAppSettings());

  // Create and register the the MyService as singleton
  Singleton.register(MyFutureService.createInstance());

  await Singleton.ensureInstanceFor([AppSettings, MyFutureService]); //  Ensure all singletons are properly initialized

  runApp();
}

```

Then use future singleton in normal way

```dart
MyService().doSomething();
```