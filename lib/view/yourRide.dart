import 'package:flutter/material.dart';
import 'package:ride_sharing/view/passengerScreens/passengerYourRide.dart';

/// Passenger "Your Ride" tab — thin wrapper that delegates to
/// [Passengeryourride] (which lives under `passengerScreens/` alongside
/// the other rider-specific screens). Kept here so the bottom navbar
/// import path stays unchanged.
class Yourride extends StatelessWidget {
  const Yourride({super.key});

  @override
  Widget build(BuildContext context) => const Passengeryourride();
}
