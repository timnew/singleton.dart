import 'dart:async';

import 'package:async/async.dart';
import 'package:meta/meta.dart';

/// Factory to create singleton
typedef T SingletonFactory<T>();

/// Singleton host to make singleton implementation easier
abstract class Singleton<T> {
  static final Map<Type, Singleton> _known = Map();

  /// Get the singleton wrapper for type [T}
  factory Singleton() => _known[T] ?? _UnknownSingleton<T>();

  /// Register a singleton [T] with given [value]
  ///
  /// [value] can be either a [Future] or value.
  factory Singleton.register(FutureOr<T> value) =>
      value is Future<T> ? _FutureSingleton(value) : _EagerSingleton(value);

  /// Register or fetch a lazy type singleton wrapper for [T]
  ///
  /// If singleton wrapper haven't been registered, a new wrapper will be created
  /// Else previously registered singleton wrapper will be returned
  factory Singleton.lazy(SingletonFactory<T> factory) => _known[T] ?? _LazySingleton<T>(factory);

  Singleton._() {
    if (_known.containsKey(T)) throw StateError("Double register for singleton $T");

    _known[T] = this;
  }

  static dynamic _findSingletons(dynamic type, [bool allowList = true]) {
    if (type == null) throw ArgumentError.notNull(type);

    if (type is Type) {
      Singleton singleton = _known[type] ?? {throw ArgumentError.value(type, "type", "Unknown singleton $type")};
      return singleton;
    }

    if (type is Singleton) {
      return type;
    }

    if (type is List && allowList) {
      return type.map((e) => _findSingletons(e, false) as Singleton);
    }

    throw ArgumentError.value(type, "type", "Invalid single type $type");
  }

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

      final futures = (singleton as Iterable<Singleton>).map((e) => e.ensuredInstance());

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
  void deregister() {
    _known.remove(T);
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

class _UnknownSingleton<T> implements Singleton<T> {
  // ignore: sdk_version_never
  Never _complains() => throw UnimplementedError("Unknown singleton $T");

  @override
  T get instance => _complains();

  @override
  void deregister() {
    // Do thing
  }

  @override
  Future<T> ensuredInstance() => _complains();
}

class _EagerSingleton<T> extends Singleton<T> {
  final T instance;

  _EagerSingleton(this.instance)
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
  void deregister() {
    super.deregister();
    _value = null;
  }
}
