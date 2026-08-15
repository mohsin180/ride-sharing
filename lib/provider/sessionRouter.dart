import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/model/authModels.dart';
import 'package:ride_sharing/provider/authProvider.dart' show selectedRoleProvider;
import 'package:ride_sharing/provider/providers.dart';
import 'package:ride_sharing/widgets/consonants/jwtUtils.dart';
import 'package:ride_sharing/widgets/consonants/tokenStorage.dart';

/// How long a single onboarding lookup may take before it's retried. Phones on
/// mobile data reaching the backend through a tunnel routinely need more than a
/// couple of seconds on the first call of a cold start.
const Duration _lookupTimeout = Duration(seconds: 12);

/// Where a user belongs, decided in one place for every entry point — splash,
/// login, and the end of role selection alike.
///
/// The rule is now a single fact rather than a series of guesses: **a session
/// token means the account is finished**. It cannot mean anything else, because
/// the backend only issues one at the moment identity verification passes, and
/// creates the account in that same instant. Nothing here has to check for a
/// missing profile or an unverified identity — those states have no session to
/// arrive with.
///
/// Anyone without a session is mid-signup, and the server says which step they
/// stopped at. The app never infers it. That inference is exactly what used to
/// send a KYC-less user to the home screen: login checked for a profile, found
/// one, and asked no further.
Future<String> resolveStartRoute(WidgetRef ref) async {
  final token = await Tokenstorage.getToken();
  if (token != null && token.isNotEmpty && !JwtUtils.isExpired(token)) {
    final role = JwtUtils.extractRole(token);
    if (role == "DRIVER" || role == "PASSENGER") {
      ref.read(selectedRoleProvider.notifier).setRole(role!);
      return Approutes.bottomNavbar;
    }
    // A token with no role can't have come from promotion; treat it as junk
    // rather than letting it stand in for a session.
    await Tokenstorage.deleteToken();
  }
  return resumeSignupOrLogin(ref);
}

/// Picks up an interrupted signup, or falls back to the login screen.
///
/// Asks the backend where the signup stands rather than trusting anything
/// cached: the user may have clicked the verification link, or finished KYC in
/// a browser, since this device last looked.
Future<String> resumeSignupOrLogin(WidgetRef ref) async {
  final onboardingToken = await Tokenstorage.getOnboardingToken();
  if (onboardingToken == null || onboardingToken.isEmpty) {
    return Approutes.login;
  }
  try {
    final state = await ref
        .read(authServiceProvider)
        .onboardingState(onboardingToken)
        .timeout(_lookupTimeout);
    await Tokenstorage.saveOnboardingToken(state.onboardingToken);
    return routeForStage(ref, state.stage, state.role);
  } catch (_) {
    // Expired or unreachable — logging in re-issues an onboarding token and
    // reports the stage again, so this is a detour and never a dead end.
    return Approutes.login;
  }
}

/// The screen that owns a given onboarding step.
///
/// [role] may be null before it has been chosen, which is fine: every stage
/// that needs it comes after the choice.
String routeForStage(WidgetRef ref, OnboardingStage stage, String? role) {
  if (role == "DRIVER" || role == "PASSENGER") {
    ref.read(selectedRoleProvider.notifier).setRole(role!);
  }
  final isPassenger = role != "DRIVER";
  switch (stage) {
    case OnboardingStage.emailVerification:
      return Approutes.verification;
    case OnboardingStage.role:
      return Approutes.roleSection;
    case OnboardingStage.profile:
      return isPassenger
          ? Approutes.passengerProfileData
          : Approutes.driverProfileData;
    case OnboardingStage.vehicle:
      return Approutes.driverVehicleDetails;
    case OnboardingStage.kyc:
      return isPassenger ? Approutes.passengerKyc : Approutes.driverKyc;
    case OnboardingStage.complete:
      return Approutes.bottomNavbar;
  }
}
