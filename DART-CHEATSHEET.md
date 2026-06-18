# Dart Cheat Sheet

## Project Commands

```bash
# Install dependencies
flutter pub get

# Update to latest compatible versions
flutter pub upgrade

# Check for outdated packages
flutter pub outdated

# Run code generation (Drift, Riverpod, etc.)
dart run build_runner build
dart run build_runner build --delete-conflicting-outputs
dart run build_runner clean

# Watch mode — regenerates on file changes
dart run build_runner watch

# Static analysis
flutter analyze

# Format all Dart files
dart format lib/ test/

# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run a single test file
flutter test test/data/repositories/session_repository_test.dart

# Run a single test case
flutter test --name "test name" test/data/repositories/session_repository_test.dart
```

## Flutter Run

```bash
# Run in Chrome (web)
flutter run -d chrome

# Run on Android emulator
flutter run -d emulator

# Run with hot reload debug
flutter run --debug

# List available devices
flutter devices

# List emulators
flutter emulators

# Create/specify emulator
flutter emulators --create --name pixel_8
```

## Language Quick Reference

### Variables
```dart
var name = 'foo';          // inferred String
final name = 'foo';        // runtime constant, can set once
const name = 'foo';        // compile-time constant
late String name;          // initialized before first use
String? name;              // nullable
```

### Functions
```dart
String greet(String name) => 'Hello $name';

String greet(String name, [String? title]) => '...';  // optional positional
String greet(String name, {String? title}) => '...';  // optional named
String greet(String name, {required String title}) => '...';
```

### Null safety
```dart
String? maybeString;
String definitely = maybeString ?? 'default';    // null-coalescing
String? value = maybeString?.toUpperCase();       // null-aware access
String definitely = maybeString!;                 // assertion (throws if null)
```

### Collections
```dart
final list = [1, 2, 3];
final set = {1, 2, 3};
final map = {'a': 1, 'b': 2};

final squares = list.map((n) => n * n).toList();
final evens = list.where((n) => n.isEven).toList();
```

### Classes
```dart
class Point {
  final double x;
  final double y;
  const Point(this.x, this.y);
  double get distance => sqrt(x * x + y * y);
}
```

### Async
```dart
Future<String> fetch() async {
  final response = await http.get(url);
  return response.body;
}

Stream<int> count() async* {
  for (var i = 0; i < 10; i++) {
    yield i;
  }
}
```

### Cascade operator (..)
```dart
// Instead of:
var list = [];
list.add(1);
list.add(2);

// Write:
var list = []
  ..add(1)
  ..add(2);
```

## Flutter Quick Reference

### Common Widgets
```dart
Text('label')
TextButton(onPressed: () {}, child: Text('Click'))
ElevatedButton(onPressed: () {}, child: Text('Submit'))
TextField(controller: myController, decoration: InputDecoration(labelText: 'Name'))
SizedBox(width: 16, height: 16)  // spacing
Expanded(child: widget)            // fill space in Row/Column
Flexible(child: widget)            // fill available space
Padding(padding: EdgeInsets.all(16), child: widget)
Center(child: widget)
ListView(children: [...])
Column(children: [...])
Row(children: [...])
Stack(children: [...])
Card(child: Padding(padding: EdgeInsets.all(16), child: widget))
```

### Styling
```dart
// Text styling
Text('Hello', style: Theme.of(context).textTheme.headlineMedium)

// Padding
EdgeInsets.all(16)
EdgeInsets.symmetric(horizontal: 16, vertical: 8)
EdgeInsets.only(left: 8, top: 16)

// Border radius
BorderRadius.circular(8)
RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
```

### Widget Testing
```dart
testWidgets('renders correctly', (tester) async {
  await tester.pumpWidget(MyWidget());
  expect(find.text('Hello'), findsOneWidget);
  await tester.tap(find.byIcon(Icons.add));
  await tester.pump();  // rebuild after state change
});
```

### Provider Override in Tests
```dart
ProviderScope(
  overrides: [
    myProvider.overrideWithValue(fakeValue),
  ],
  child: MyWidget(),
);
```
