import 'dart:async';

import 'package:async/async.dart';
import 'package:meta/meta.dart';

/// Factory to create singleton
typedef T SingletonFactory<T>();

abstract class Singleton<T> {
  static final Map<Type, Singleton> _known = Map();

  factory Singleton() => _known[T] ?? _UnknownSingleton<T>();

  factory Singleton.register(FutureOr<T> value) =>
      value is Future<T> ? _FutureSingleton(value) : _ValueSingleton(value);

  factory Singleton.lazy(SingletonFactory<T> factory) => _known[T] ?? _FactorySingleton<T>(factory);

  Singleton._() {
    if (_known.containsKey(T)) throw StateError("Double register for singleton $T");

    _known[T] = this;
  }

  @visibleForTesting
  static void printKnownForTest() {
    print(_known);
  }

  @visibleForTesting
  static void resetAllForTest() {
    _known.clear();
  }

  void resetValue() => throw UnsupportedError("Resetting value for $T is not supported");

  T get value;

  FutureOr<T> ensureValue() => value;
}

class _UnknownSingleton<T> implements Singleton<T> {
  // ignore: sdk_version_never
  Never _complains() => throw UnimplementedError("Unknown singleton $T");

  @override
  T get value => _complains();

  @override
  void resetValue() => _complains();

  @override
  FutureOr<T> ensureValue() => _complains();
}

class _ValueSingleton<T> extends Singleton<T> {
  final T value;

  _ValueSingleton(this.value)
      : assert(value != null),
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
  T get value {
    if (_result == null) throw StateError("Singleton $T is used before get resolved");

    if (_result.isError) throw _result.asError.error;

    return _result.asValue.value;
  }

  @override
  Future<T> ensureValue() async {
    await _future;

    return value;
  }
}

class _FactorySingleton<T> extends Singleton<T> {
  final SingletonFactory<T> factory;
  T _value;

  _FactorySingleton(this.factory)
      : assert(factory != null),
        super._();

  @override
  T get value => _value ?? (_value = factory());

  @override
  void resetValue() {
    _value = null;
  }
}
