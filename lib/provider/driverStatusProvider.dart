import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ride_sharing/provider/providers.dart';

/// Driver online/offline state, persisted on the backend
/// (`/api/v1/rides/driver/{status,online,offline}`) and shared across the
/// driver shell.
///
/// Exposes a plain [bool] (online?) so widgets can `ref.watch` it directly.
/// The toggle is optimistic: the flag flips immediately, the change is
/// persisted, and it reverts if the request fails so the UI never lies
/// about the server state. On first read it syncs from the backend so the
/// toggle survives app restarts.
class DriverOnlineNotifier extends Notifier<bool> {
  @override
  bool build() {
    _loadFromBackend();
    return false;
  }

  Future<void> _loadFromBackend() async {
    try {
      state = await ref.read(rideServiceProvider).getDriverStatus();
    } catch (_) {
      // Keep the offline default if the status can't be fetched.
    }
  }

  Future<void> toggle() => _setOnline(!state);
  Future<void> goOnline() => _setOnline(true);
  Future<void> goOffline() => _setOnline(false);

  Future<void> _setOnline(bool target) async {
    final previous = state;
    state = target; // optimistic
    try {
      final service = ref.read(rideServiceProvider);
      state = target ? await service.goOnline() : await service.goOffline();
    } catch (_) {
      state = previous; // revert on failure
    }
  }
}

final driverOnlineProvider =
    NotifierProvider<DriverOnlineNotifier, bool>(DriverOnlineNotifier.new);
