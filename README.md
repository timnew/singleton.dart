# singleton

[![Star this Repo](https://img.shields.io/github/stars/timnew/singleton.dart.svg?style=flat-square)](https://github.com/timnew/singleton.dart)
[![Pub Package](https://img.shields.io/pub/v/singleton.svg?style=flat-square)](https://pub.dev/packages/singleton)

## Why this library

Singleton is useful pattern, it can useful on following cases:

* Provide default instance for a certain class. Check `object` declaration from Kotlin: https://kotlinlang.org/docs/reference/object-declarations.html#object-declarations
* Instantiate expensive class lazily and on demand. Check `lazy` deleted property from Kotlin: https://kotlinlang.org/docs/reference/delegated-properties.html#lazy

But singleton also comes a bunch of problems, including but not limited to:

* Implement lazy pattern time and time again in codebase is tedious, and increases the maintenance effort.
* Singleton is not friendly to UnitTest, as global object leaks across tests.

`Singleton` library is designed to make those scenario less painful. Make singleton less hassle to work with.

## Lazy instantiate

### Before

You might feel familiar with following code:

```dart
class MyService {
  static MyService _instance;
  static MyService get instance {
    if (_instance == null) {
      _instance = MyService._();
    }

    return _instance;
  }

  /// Private constructor
  MyService._() {
  }
}
```

It is the minimal implementation of lazy pattern, you would find:

* it declares 2 static instances in class
* `_instance` lives through tests, might cause unexpected test failure.

### static instance

```dart
class MyService {
  static MyService get instance => Singleton.lazy(() => MyService._()).value;

  /// Private constructor
  MyService._() {
  }
}
```

### Even better with factory method

```dart
class MyService {
  factory MyService() => Singleton.lazy(() => MyService._()).value;

  /// Private constructor
  MyService._() {
  }
}

expect(MyService(), same(MyService)); // MyService() always returns the same instance
```

### Clear cached the instance

```dart
Singleton.lazy(() => MyService._()).resetValue();
```

or

```dart
Singleton<MyService>().resetValue();
```


## Global instance

### Before

You might feel familiar with following code:

```dart
class MyService {
  static MyService _instance;
  static MyService get instance => _instance;
  static void initialize(someComplicatedParamsHere){
     _instance = MyService._(someComplicatedParamsHere);
  }

  /// Private constructor
  MyService._(someComplicatedParamsHere) {
  }
}

void main() {
   final someComplicatedParamsHere = getComplicatedParams();
   MyService.initialize(someComplicatedParamsHere);

   // more code ...
}


MyService.instance.doSomeJob()
```

### After

```dart
class MyService {
  static MyService get instance => Singleton<MyService>().value;
  static void initialize(someComplicatedParamsHere){
     Singleton<MyService>.register(MyService._(someComplicatedParamsHere));
  }

  /// Private constructor
  MyService._(someComplicatedParamsHere) {
  }
}

void main() {
   final someComplicatedParamsHere = getComplicatedParams();
   MyService.initialize(someComplicatedParamsHere);

   MyService.instance.doSomeJob();

   // more code ...
}


MyService.instance.doSomeJob();
```

### Event better

```dart
class MyService {
  factory MyService() => Singleton<MyService>().value;

  factory MyService.register(someComplicatedParamsHere) =>
    Singleton<MyService>.register(_(someComplicatedParamsHere)).value;

  /// Private constructor
  MyService._(someComplicatedParamsHere) {
  }
}

void main() {
   final someComplicatedParamsHere = getComplicatedParams();
   MyService.register(someComplicatedParamsHere).doSomeJob();

   // more code ...
}


MyService().doSomeJob();
```

## Service create quickly but in asynchronously manner

In Flutter, there are plenty objects can be created in short period of time, but in a asynchronous manner. Such as `SharedPreference`.
To use those instances, you might need to convert every usage as async function, which could be troublesome, such as the value is needed to build a widget.

### Before

```dart
Wdiget build(BuildContext context) {
  return FutureBuilder(
    future: SharedPreference.getInstance().then((prefs) => prefs.getString("userName")),
    builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
      if(snapshot.data != null) {
        return Text(snapshot.data);
      } else {
        return Center(child: CircularLoadingIndicator()); // Really needed ?!?!
      }
    }
   );
}

```

### After

```dart
void main {
  Singleton.register(SharedPreference.getInstance()); // Instance would be created way before the value get consumed
}


Wdiget build(BuildContext context) {
  final prefs = Singleton<SharedPreference>().value.;
  return Text(prefs.getString("userName"));
}
```

## License

The MIT License (MIT)