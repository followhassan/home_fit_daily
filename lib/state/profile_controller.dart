import 'package:flutter/foundation.dart';

import '../core/utils/app_clock.dart';
import '../core/utils/ids.dart';
import '../data/models/user_profile.dart';
import '../data/repositories/repositories.dart';

/// Owns the user's profile and onboarding state.
class ProfileController extends ChangeNotifier {
  ProfileController(this._repo, {this._clock = const AppClock()}) {
    _load();
  }

  final ProfileRepository _repo;
  final AppClock _clock;
  late UserProfile _profile;

  UserProfile get profile => _profile;
  bool get onboardingCompleted => _profile.onboardingCompleted;

  void _load() {
    _profile = _repo.load() ?? UserProfile.initial(id: Ids.profile(), now: _clock.nowUtc());
  }

  /// Saves the preferences chosen during onboarding.
  Future<void> completeOnboarding(UserProfile chosen) async {
    final updated = chosen.copyWith(onboardingCompleted: true, updatedAt: _clock.nowUtc());
    await _repo.save(updated);
    _profile = updated;
    notifyListeners();
  }

  /// Skips onboarding, keeping conservative defaults.
  Future<void> skipOnboarding() => completeOnboarding(_profile);

  Future<void> update(UserProfile Function(UserProfile) change) async {
    final updated = change(_profile).copyWith(updatedAt: _clock.nowUtc());
    await _repo.save(updated);
    _profile = updated;
    notifyListeners();
  }

  /// Re-reads storage after a backup import or data reset.
  void reload() {
    _load();
    notifyListeners();
  }
}
