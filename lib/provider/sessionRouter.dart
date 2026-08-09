import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/provider/authProvider.dart' show selectedRoleProvider;
import 'package:ride_sharing/provider/profileProvider.dart';
import 'package:ride_sharing/provider/providers.dart';
import 'package:ride_sharing/widgets/consonants/apiException.dart';

/// How long a single onboarding lookup may take before it's retried. Phones on
/// mobile data reaching the backend through a tunnel routinely need more than a
/// couple of seconds on the first call of a cold start.
const Duration _lookupTimeout = Duration(seconds: 12);

/// A lookup answers yes, no, or — when the backend can't be reached — nothing
/// at all. Collapsing that third case into yes/no is what used to drop people
/// on the wrong screen: an unreachable profile read looked like "no profile"
/// and pushed a fully onboarded user back into profile creation.
enum _Answer { yes, no, unknown }

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

  // Only a definitive "no profile" sends someone back to profile creation.
  // Unknown falls through to the KYC check, because creating a profile that
  // already exists fails with a conflict and strands them there.
  if (await _hasProfileForRole(ref, role) == _Answer.no) {
    return role == "PASSENGER"
        ? Approutes.passengerProfileData
        : Approutes.driverProfileData;
  }

  // Anything short of a confirmed approval goes to KYC — including unknown.
  // Verification is a hard gate, so guessing has to err towards the gate; the
  // KYC screen polls and forwards an already-verified user into the app on its
  // own, so a network blip costs them a second, not access.
  if (await _isKycApproved(ref) != _Answer.yes) {
    return role == "PASSENGER" ? Approutes.passengerKyc : Approutes.driverKyc;
  }
  return Approutes.bottomNavbar;
}

/// Whether the backend reports a populated profile for the given role.
Future<_Answer> _hasProfileForRole(WidgetRef ref, String role) {
  return _ask(() async {
    // A fresh read each attempt: a provider that failed the first time holds
    // the error, so retrying the cached future would just fail again.
    if (role == "PASSENGER") {
      ref.invalidate(passengerProfileProvider);
      final p = await ref.read(passengerProfileProvider.future);
      return p.fullName.trim().isNotEmpty;
    }
    ref.invalidate(driverProfileProvider);
    final p = await ref.read(driverProfileProvider.future);
    return p.fullName.trim().isNotEmpty;
  });
}

/// Whether identity verification has been approved.
Future<_Answer> _isKycApproved(WidgetRef ref) {
  return _ask(() async {
    final kyc = await ref.read(kycServiceProvider).getStatus();
    return kyc.isApproved;
  });
}

/// Runs [lookup] with a timeout, once more on failure, and reports which of
/// the three answers came back.
///
/// A 404 is an answer — the record genuinely isn't there. A timeout, a socket
/// error or a 5xx is not, and is reported as [_Answer.unknown] so the caller
/// can pick the safe route instead of acting on a guess.
Future<_Answer> _ask(Future<bool> Function() lookup) async {
  for (var attempt = 0; attempt < 2; attempt++) {
    try {
      return await lookup().timeout(_lookupTimeout)
          ? _Answer.yes
          : _Answer.no;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return _Answer.no;
      // 401 means the session is finished; nothing here can recover it, so
      // don't burn a retry on it.
      if (e.statusCode == 401) return _Answer.unknown;
    } catch (_) {
      // Timeout / socket / decode — worth one more try.
    }
  }
  return _Answer.unknown;
}
