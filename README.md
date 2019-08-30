# Gigantier Flutter 

> SDK to connect your Flutter app to Giganter API.

[API reference](https://docs.gigantier.com/?flutter)

## Installation

Add this to your package's pubspec.yaml file:

```bash
dependencies:
  gigantier_sdk: ^1.0.11
```

Then install the package with `pub get` or `flutter pub get`.

## Usage

To get started, instantiate a new Gigantier client with your credentials.

> **Note:** This requires a [Gigantier](http://gigantier.com) account.

```dart
import 'package:gigantier_sdk/gigantier.dart';

...

final client = Gigantier(
  hostname, 
  clientId, 
  clientSecret, 
  scope, 
  appName
);
```

Check out the [API reference](https://docs.gigantier.com/?flutter) to learn more about authenticating and the available endpoints.

## Contributing

Thank you for considering contributing to Gigantier Flutter SDK.
