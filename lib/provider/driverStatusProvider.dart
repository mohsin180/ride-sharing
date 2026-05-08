import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Driver online/offline state, shared across the driver shell.
///
/// The home tab owns the toggle UI; the rides tab reads this to decide
/// whether to show ride requests or an offline placeholder. Default is
/// `false` (offline) so a freshly-signed-in driver explicitly opts in.
class DriverOnlineNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void goOnline() => state = true;
  void goOffline() => state = false;
}

final driverOnlineProvider =
    NotifierProvider<DriverOnlineNotifier, bool>(DriverOnlineNotifier.new);
