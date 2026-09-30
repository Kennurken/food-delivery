import 'package:flutter/material.dart';

/// The app's top ScaffoldMessenger, for SnackBars raised by code that has no
/// BuildContext under a Scaffold (a push arriving while the app is open).
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();
