import 'package:flutter/foundation.dart';

import '../data/models/active_session.dart';
import '../data/repositories/repositories.dart';

enum RecoveryState { none, available, incompatible }

/// Detects a workout that was interrupted by the app closing, so the user
/// can resume or discard it.
class RecoveryController extends ChangeNotifier {
  RecoveryController(this._active, this._sessions) {
    _check();
  }

  final ActiveSessionRepository _active;
  final SessionRepository _sessions;
  ActiveSessionCheckpoint? _pending;
  RecoveryState _state = RecoveryState.none;

  RecoveryState get state => _state;
  ActiveSessionCheckpoint? get pending => _pending;

  void _check() {
    final checkpoint = _active.load();
    if (checkpoint == null) {
      // An unreadable checkpoint cannot be resumed; it is cleaned up by
      // discard() when the user acknowledges it.
      _state = _active.hasUnreadableCheckpoint ? RecoveryState.incompatible : RecoveryState.none;
      _pending = null;
      return;
    }
    if (_sessions.contains(checkpoint.sessionId)) {
      // Already saved; the app closed before the checkpoint was cleared.
      _pending = null;
      _state = RecoveryState.none;
      _active.clear();
      return;
    }
    _pending = checkpoint;
    _state = checkpoint.isCompatible ? RecoveryState.available : RecoveryState.incompatible;
  }

  /// Re-checks storage (e.g. when returning to the home screen).
  void refresh() {
    _check();
    notifyListeners();
  }

  /// Drops the interrupted session without saving it.
  Future<void> discard() async {
    await _active.clear();
    await _active.docs.removeUnreadable();
    _pending = null;
    _state = RecoveryState.none;
    notifyListeners();
  }

  /// Called when the player takes over the pending session.
  void markResumed() {
    _pending = null;
    _state = RecoveryState.none;
    notifyListeners();
  }
}
