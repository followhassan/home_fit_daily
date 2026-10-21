import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen on during active exercise when the user allows it.
abstract interface class ScreenAwake {
  Future<void> set(bool enabled);
}

class WakelockScreenAwake implements ScreenAwake {
  bool? _current;

  @override
  Future<void> set(bool enabled) async {
    if (_current == enabled) return;
    _current = enabled;
    try {
      await WakelockPlus.toggle(enable: enabled);
    } catch (e) {
      debugPrint('Wakelock unavailable: $e');
    }
  }
}

class NoopScreenAwake implements ScreenAwake {
  bool enabled = false;

  @override
  Future<void> set(bool enabled) async => this.enabled = enabled;
}
