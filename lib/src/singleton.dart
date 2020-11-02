import 'dart:async';

import 'package:async/async.dart';
import 'package:meta/meta.dart';

/// Factory to create singleton
typedef T SingletonFactory<T>();

/// A helper class makes singleton less hassle
///
/// For value type singleton
/// ```dart
/// Singleton.register(MyService());
///
/// class MyService {
///   static MyService get instance => Singleton<MyService>().get();
///
///    MyService() {
///      // constructor
///    }
/// }
/// ```
///
/// For future type singleton
/// ```dart
/// Singleton.register(MyService.createAsync());
///
/// class MyService {
///   static MyService get instance => Singleton<MyService>().get();
///
///   static Future<MyService> createAsync() {
///     // create instance
///   }
/// }
/// ```
///
/// For lazy type singleton
/// ```dart
/// class MyService {
///   static MyService get instance => Singleton<MyService>.lazy(() => MyService._()).get();
///
///    MyService._() {
///      // private constructor
///    }
/// }
/// ```
///
/// To avoid singleton pollution in unit test
/// ```dart
/// tearDown(() {
///   Singleton.resetAllForTest();
/// });
/// ```
abstract class Singleton<T> {
  static final Map<Type, Singleton> _known = Map();

  /// Get the singleton wrapper for type [T}
  factory Singleton() => _known[T] ?? _UnknownSingleton<T>();

  /// Register a singleton [T] with given [value]
  ///
  /// [value] can be either a [Future] or value.
  factory Singleton.register(FutureOr<T> value) =>
      value is Future<T> ? _FutureSingleton(value) : _ValueSingleton(value);

  /// Register or fetch a lazy type singleton wrapper for [T]
  ///
  /// If singleton wrapper haven't been registered, a new wrapper will be created
  /// Else previously registered singleton wrapper will be returned
  factory Singleton.lazy(SingletonFactory<T> factory) => _known[T] ?? _LazySingleton<T>(factory);

  Singleton._() {
    if (_known.containsKey(T)) throw StateError("Double register for singleton $T");

    _known[T] = this;
  }

  /// Ensure all singleton instances exists
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
  static Future ensureInstanceFor(dynamic key) {
    if (key == null) throw ArgumentError.notNull(key);

    if (key is Type) {
      Singleton singleton = _known[key] ?? {throw UnimplementedError("Unknown singleton $key")};
      return singleton.ensuredInstance();
    }

    if (key is Singleton) {
      return key.ensuredInstance();
    }

    if (key is List) {
      return Future.wait(key.map((e) => ensureInstanceFor(e)));
    }

    throw ArgumentError("Invalid parameter types ${key.runtimeType}");
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

  /// Debug API to print all known singleton wrappers
  @visibleForTesting
  static void printKnownForTest() {
    print(_known);
  }

  /// Get value of singleton
  T get instance;

  /// Clear cached instance, and recreate on next use.
  ///
  /// Only supported by singleton created with [Singleton.lazy].
  /// Others throws [UnsupportedError]
  void resetValue() => throw UnsupportedError("Resetting value for $T is not supported");

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

class _UnknownSingleton<T> implements Singleton<T> {
  // ignore: sdk_version_never
  Never _complains() => throw UnimplementedError("Unknown singleton $T");

  @override
  T get instance => _complains();

  @override
  void resetValue() {
    // Do thing
  }

  @override
  Future<T> ensuredInstance() => _complains();
}

class _ValueSingleton<T> extends Singleton<T> {
  final T instance;

  _ValueSingleton(this.instance)
      : assert(instance != null),
        super._();
}

class _FutureSingleton<T> extends Singleton<T> {
  Result<T> _result;
  Future _future;

  _FutureSingleton(Future<T> unresolved)
      : assert(unresolved != null),
        super._() {
    _future = _resolve(unresolved);
  }

  Future _resolve(Future<T> unresolved) async {
    _future = Result.capture(unresolved);

    _result = await _future;
  }

  @override
  T get instance {
    if (_result == null) throw StateError("Singleton $T is used before being resolved");

    if (_result.isError) throw _result.asError.error;

    return _result.asValue.value;
  }

  @override
  Future<T> ensuredInstance() async {
    await _future;

    return instance;
  }
}

class _LazySingleton<T> extends Singleton<T> {
  final SingletonFactory<T> factory;
  T _value;

  _LazySingleton(this.factory)
      : assert(factory != null),
        super._();

  @override
  T get instance => _value ?? (_value = factory());

  @override
  void resetValue() {
    _value = null;
  }
}
