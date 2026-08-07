import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/provider/authProvider.dart' show selectedRoleProvider;
import 'package:ride_sharing/provider/profileProvider.dart';
import 'package:ride_sharing/provider/providers.dart';

/// Decide where an authenticated user (already carrying a valid JWT role)
/// should land, and sync that role into the bottom-navbar selector. Shared by
/// the login screen and the splash auto-login so both route identically:
///   • role + profile + verified identity → the app (bottom navbar)
///   • role + profile, not yet verified   → finish KYC
///   • role, no profile                   → finish profile creation
///
/// Identity verification is mandatory, so an unverified user is sent back to
/// the KYC screen on every launch until they pass. The backend enforces the
/// same rule on the ride endpoints — this only saves them a failed request.
///
/// Caller is responsible for the no-role case (send them to login / role
/// selection) — this only handles DRIVER / PASSENGER.
Future<String> resolveHomeRouteForRole(WidgetRef ref, String role) async {
  ref.read(selectedRoleProvider.notifier).setRole(role);

  bool hasProfile;
  try {
    hasProfile = await _hasProfileForRole(ref, role)
        .timeout(const Duration(seconds: 8));
  } catch (_) {
    // Timeout / network blip — assume onboarded; the navbar surfaces any gap.
    hasProfile = true;
  }

  if (!hasProfile) {
    return role == "PASSENGER"
        ? Approutes.passengerProfileData
        : Approutes.driverProfileData;
  }

  if (!await _isKycApproved(ref)) {
    return role == "PASSENGER"
        ? Approutes.passengerKyc
        : Approutes.driverKyc;
  }
  return Approutes.bottomNavbar;
}

/// True when the backend reports a populated profile for the given role.
Future<bool> _hasProfileForRole(WidgetRef ref, String role) async {
  try {
    if (role == "PASSENGER") {
      final p = await ref.read(passengerProfileProvider.future);
      return p.fullName.trim().isNotEmpty;
    } else {
      final p = await ref.read(driverProfileProvider.future);
      return p.fullName.trim().isNotEmpty;
    }
  } catch (_) {
    return false;
  }
}

/// True when identity verification has been approved. A failed lookup counts
/// as approved on purpose: a network blip shouldn't strand an already-verified
/// user on the KYC screen, and the backend still blocks the ride endpoints.
Future<bool> _isKycApproved(WidgetRef ref) async {
  try {
    final kyc = await ref
        .read(kycServiceProvider)
        .getStatus()
        .timeout(const Duration(seconds: 8));
    return kyc.isApproved;
  } catch (_) {
    return true;
  }
}
