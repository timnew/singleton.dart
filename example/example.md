# Singleton Examples

## Lazy Singleton

### Define lazy singleton

```dart
class MyService {
  /// Factory method that reuse same instance automatically
  factory MyService() => Singleton.lazy(() => MyService._()).instance;

  /// Private constructor
  MyService._() {
  }

  /// Some method
  void doSomething() {
  }
}
```

### Use lazy singleton

```dart
MyService().doSomething() // Use the singleton instance
```

## Singleton depends on explicit resource to create

Singleton could be useful to simplify the case that the instantiation of the type requires explicit resources
might not be accessible on use-site. So a shared singleton object need to be created before hand.

### Define the type

```dart
class MyService {
  /// Factory method that reuse same instance automatically
  factory MyService() => Singleton<MyService>().instance;

  final ApiInterface apiInterface;

  /// Constructor create and register new instance
  MyService.initialize(this.apiInterface) {
    // Register current instance
    Singleton.register(this);
  }

  /// Some method
  void doSomething() {
  }
}
```

### Register object before used

Initialize the type somewhere proper before any usage, such as in `main` function.

```dart
void main() {
  final appSettings = getAppSettings();
  final httpClient = createHttpClient(appSetting);
  final apiInterface = createApiInterface(httpClient);

  MyService.initialize(apiInterface) // Create and register the the singleton
           .doSomething();  // Use the instance
}
```

### Use pre-registered singleton

```dart
MyService().doSomething(); // Use the singleton instance
```

## Singleton depends on async resource to create

`Future`, `async`, and `await` is a great abstraction of async operations that enables developer to write async code
in a sync manner, which mitigate the pain to write and maintain async code.

But `async` and `await` is not always helpful, for example, in Flutter you can't use `await` `Widget`'s `build` method. To consume
async value in widget, you need `FutureBuilder`, which is the easiest widget to be used.

So a better idea might be prepare the async value before hand when convenient, and consume it as sync resource. If the resource is used globally,
hold it in a singleton could be a good idea.

### Define the type

```dart
Future<AppSettings> loadAppSettings() {
}
HttpClient createHttpClient(AppSettings appSettings){
}
Future<ApiInterface> createApiInterface(HttpClient) {
}

class MyService {
  /// Factory method that reuse same instance automatically
  factory MyService() => Singleton<MyService>().value;

  static Future<MyService> createInstance() async {
    AppSettings settings = await Singleton<AppSettings>().ensuredInstance(); // Use AppSettingSingleton is properly resolved

    final httpClient = createHttpClient(appSetting);
    final apiInterface = await createApiInterface(httpClient);

    return _(apiInterface);
  }

  final ApiInterface apiInterface;

  MyService._(this.apiInterface);

  /// Some method
  void doSomething() {
  }
}
```

### Register future as singleton

`Singleton.register` understands future, it register value of future as singleton rather than register future itself

```dart
void main() {
  // Register AppSettings settings as a future singleton
  Singleton.register(loadAppSettings());

  // Create and register the the MyService as singleton
  Singleton.register(MyService.createInstance());
}
```

### Use future singleton

For sure you still can use this approach to consume future singleton.

```dart
MyService().doSomething();
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
await Singleton.ensureInstanceFor([AppSettings, MyService]); // call will be blocked until AppSettings and MyServices are resolved
```

Then use future singleton in normal way

```dart
MyService().doSomething();
```