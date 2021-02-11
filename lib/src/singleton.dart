import 'dart:async';

import 'package:async/async.dart';
import 'package:meta/meta.dart';

/// Factory to create singleton
typedef T SingletonFactory<T>();

/// Container of singleton instance.
///
/// ## Lazy Singleton
///
/// ### Define Lazy Singleton
///
/// ```dart
/// class MyLazyService {
///   /// Factory method that reuse same instance automatically
///   factory MyLazyService() => Singleton.lazy(() => MyLazyService._()).instance;
///
///   /// Private constructor
///   MyLazyService._() {}
///
///   /// do something
///   void doSomething() {}
/// }
/// ```
///
/// ### Use Lazy Singleton
///
/// ```dart
/// MyLazyService().doSomething() // Use the singleton instance
/// ```
///
/// ## Eager Singleton
///
/// ### Define Eager Singleton
///
/// ```dart
/// class MyEagerService {
///   /// Factory method that reuse same instance automatically
///   factory MyEagerService() => Singleton<MyEagerService>().instance;
///
///   final MyApi api;
///
///   /// Constructor create and register new instance
///   MyEagerService.initialize(this.api) {
///     // Register current instance
///     Singleton.register(this);
///   }
///
///   /// do something
///   void doSomething() {}
/// }
/// ```
///
/// ### Initialize eagerly
///
/// ```dart
/// void main() {
///   final appSettings = getAppSettings();
///   final httpClient = createHttpClient(appSetting);
///   final api = createMyApi(httpClient);
///
///   MyEagerService.initialize(api) // Create and register the the singleton
///                 .doSomething();  // Use the instance
/// }
/// ```
///
/// ### Use Eager Singleton
///
/// ```dart
/// MyEagerService().doSomething(); // Use the singleton instance
/// ```
///
/// ## Future Singleton
///
/// ### Define the type
///
/// Given some other dependants declarations
///
/// ```dart
/// class AppSettings {
///   static Future<AppSettings> loadAppSettings() {
///     // load app settings from somewhere asynchronously
///   }
/// }
///
/// class HttpClient {
///   final AppSettings appSettings;
///
///   HttpClient(this.appSettings);
/// }
/// ```
///
///
/// ```dart
/// class MyFutureService {
///   /// Factory method that reuse same instance automatically
///   factory MyFutureService() => Singleton<MyFutureService>().instance;
///
///   static Future<MyFutureService> createInstance() async {
///     final appSettings = await Singleton<AppSettings>().ensuredInstance();
///
///     final httpClient = HttpClient(appSettings);
///
///     return MyFutureService._(httpClient);
///   }
///
///   final HttpClient httpClient;
///
///   MyFutureService._(this.httpClient);
///
///   /// Some method
///   void doSomething() {}
/// }
/// ```
///
/// ### Register future as singleton
///
/// `Singleton.register` understands future, it register value of future as singleton rather than register future itself
///
/// ```dart
/// void main() {
///   // Register AppSettings settings as a future singleton
///   Singleton.register(AppSettings.loadAppSettings());
///
///   // Create and register the the MyService as singleton
///   Singleton.register(MyFutureService.createInstance());
///
///   runApp();
/// }
/// ```
///
/// ### Use future singleton
///
/// For sure you still can use this approach to consume future singleton.
///
/// ```dart
/// MyFutureService().doSomething();
/// ```
///
/// It is likely to be okay if when async resource although load asynchronously but will be available fast, such as `SharedPreferences`.
/// But you might encounter `StateError` says "singleton is being used before being resolved".
///
/// ### Availability checkpoint
///
/// ```dart
/// (await Singleton<MyService>().ensuredInstance()).doSomething();
/// ```
///
/// This is a more reliable way, but it removes almost all the benefits to have a sync singleton.
///
/// So run following code before usage, such as in `main` after register all singleton types
///
/// ```dart
///
/// void main() async {
///   // Register AppSettings settings as a future singleton
///   Singleton.register(AppSettings.loadAppSettings());
///
///   // Create and register the the MyService as singleton
///   Singleton.register(MyFutureService.createInstance());
///
///   await Singleton.ensureInstanceFor([AppSettings, MyFutureService]); //  Ensure all singletons are properly initialized
///
///   runApp();
/// }
///
/// ```
///
/// Then use future singleton in normal way
///
/// ```dart
/// MyService().doSomething();
/// ```
abstract class Singleton<T> {
  static final Map<SingletonKey, Singleton> _known = Map();

  /// Get the singleton wrapper for type [T}
  factory Singleton([String? name = null]) =>
      (_known[SingletonKey(T, name)] ?? _UnknownSingleton<T>(name))
          as Singleton<T>;

  /// Register a singleton [T] with given [value]
  ///
  /// [value] can be either a [Future] or value.
  factory Singleton.register(FutureOr<T> value, {String? name = null}) =>
      value is Future<T>
          ? _FutureSingleton(name, value)
          : _EagerSingleton(name, value);

  /// Register or fetch a lazy type singleton wrapper for [T]
  ///
  /// If singleton wrapper haven't been registered, a new wrapper will be created
  /// Else previously registered singleton wrapper will be returned
  factory Singleton.registerLazy(SingletonFactory<T> factory,
          {String? name = null}) =>
      (_known[SingletonKey(T, name)] ?? _LazySingleton<T>(name, factory))
          as Singleton<T>;

  /// Register or fetch a lazy singleton for [T]
  ///
  /// If singleton wrapper haven't been registered, a new wrapper will be created
  /// Else previously registered singleton wrapper will be returned
  static T lazy<T>(SingletonFactory<T> factory, {String? name = null}) =>
      Singleton.registerLazy(factory, name: name).instance;

  /// Retrieve an pre-registered singleton For [T] via [register].
  static T get<T>({String? name = null}) => Singleton<T>(name).instance;

  final SingletonKey key;

  Singleton._(String? name) : key = SingletonKey(T, name) {
    if (_known.containsKey(key))
      throw StateError("Double register for singleton $T");

    _known[key] = this;
  }

  static dynamic _findSingletons(dynamic type, [bool allowList = true]) {
    if (type == null) throw ArgumentError.notNull(type);

    if (type is SingletonKey) {
      return _getSingleton(type);
    }

    if (type is Type) {
      return _getSingleton(SingletonKey(type));
    }

    if (type is Singleton) {
      return type;
    }

    if (type is List && allowList) {
      return type.map((e) => _findSingletons(e, false) as Singleton);
    }

    throw ArgumentError.value(type, "type", "Invalid single type $type");
  }

  static Singleton _getSingleton(SingletonKey key) =>
      _known[key] ?? key.throwNotFoundException();

  /// Ensure [type] singleton instances exists
  ///
  /// Used as availability check point for future singletons
  ///
  /// ```dart
  /// await Singleton.ensureInstanceFor(MySingleton);
  ///
  /// await Singleton.ensureInstanceFor(Singleton<MySingleton>());
  ///
  ///  await Singleton.ensureInstanceFor([MySingleton, MyAnotherSingleton]);
  /// ```
  static Future ensureInstanceFor(dynamic type) {
    final singleton = _findSingletons(type);

    if (singleton is Singleton) {
      return singleton.ensuredInstance();
    } else {
      print(singleton);

      final futures =
          (singleton as Iterable<Singleton>).map((e) => e.ensuredInstance());

      return Future.wait(futures);
    }
  }

  /// Debug API to clear all registered singleton to avoid pollution across tests caused by singleton
  ///
  /// ```dart
  /// tearDown(() {
  ///   Singleton.resetAllForTest();
  /// });
  /// ```
  @visibleForTesting
  static void resetAllForTest() {
    _known.clear();
  }

  /// Prints singletons of given [type]
  /// if [type] are omitted, all singletons are printed.
  static void debugPrintAll(dynamic type) {
    final singleton = _findSingletons(type);

    if (singleton is Iterable<Singleton>) {
      print(singleton.toList(growable: false));
    } else {
      print(singleton);
    }
  }

  /// Get value of singleton
  T get instance;

  /// Deregister singleton from registry
  ///
  /// This should be rarely used.
  void deregister([String? name = null]) {
    _known.remove(SingletonKey(T, name));
  }

  /// A [FutureOr] use to ensure the value is created.
  ///
  /// Should be only used in time sequence extremely sensitive scenario.
  ///
  /// In general, consider to change code like
  /// ```dart
  /// Singleton.register(MyService.createAsync());
  /// ```
  ///
  /// to something like
  /// ```dart
  /// final instance = await MyService.createAsync()
  /// Singleton.register(instance);
  /// ```
  Future<T> ensuredInstance() async => instance;
}

class SingletonKey {
  final Type type;
  final String? name;
  SingletonKey(this.type, [this.name = null]);

  @override
  int get hashCode => type.hashCode ^ (name?.hashCode ?? 0);

  @override
  bool operator ==(Object other) {
    if (other is! SingletonKey) return false;

    return other.type == type && other.name == name;
  }

  Never throwNotFoundException() {
    if (name == null) {
      throw ArgumentError.value(this, "key", "Unknown singleton $type");
    } else {
      throw ArgumentError.value(
          this, "key", "Unknown singleton $type with name $name");
    }
  }
}

class _UnknownSingleton<T> implements Singleton<T> {
  @override
  final SingletonKey key;

  _UnknownSingleton([String? name]) : key = SingletonKey(T, name);

  Never _complains() {
    throw UnimplementedError("Unknown singleton $T");
  }

  @override
  T get instance => _complains();

  @override
  void deregister([String? name = null]) {
    // Do thing
  }

  @override
  Future<T> ensuredInstance() => _complains();
}

class _EagerSingleton<T> extends Singleton<T> {
  final T instance;

  _EagerSingleton(String? name, this.instance)
      : assert(instance != null),
        super._(name);
}

class _FutureSingleton<T> extends Singleton<T> {
  late final Result<T> _result;
  late Future _future;

  _FutureSingleton(String? name, Future<T> unresolved) : super._(name) {
    _future = _resolve(unresolved);
  }

  Future _resolve(Future<T> unresolved) async {
    _future = Result.capture(unresolved);

    _result = await _future;
  }

  @override
  T get instance {
    try {
      _result;
    } on Error {
      // For some reason it reject to use `LateInitializationError`
      throw StateError("Singleton $T is used before being resolved");
    }

    if (_result.isError) throw _result.asError!.error;

    return _result.asValue!.value;
  }

  @override
  Future<T> ensuredInstance() async {
    await _future;

    return instance;
  }
}

class _LazySingleton<T> extends Singleton<T> {
  final SingletonFactory<T> factory;
  T? _value;

  _LazySingleton(String? name, this.factory) : super._(name);

  @override
  T get instance => _value ?? (_value = factory());

  @override
  void deregister([String? name = null]) {
    super.deregister(name);
    _value = null;
  }
}
