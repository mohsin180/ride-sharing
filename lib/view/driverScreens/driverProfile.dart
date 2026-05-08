import 'package:flutter/material.dart';
import 'package:ride_sharing/view/passengerScreens/profile.dart';

/// Driver "Profile" tab — reuses the [DriverProfile] widget defined
/// in `passengerScreens/profile.dart` (which already contains both
/// passenger and driver layouts) so we don't duplicate the design.
class Driverprofile extends StatelessWidget {
  const Driverprofile({super.key});

  @override
  Widget build(BuildContext context) => const DriverProfile();
}
