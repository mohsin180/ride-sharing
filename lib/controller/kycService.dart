import 'package:ride_sharing/controller/apiClient.dart';
import 'package:ride_sharing/model/authModels.dart';
import 'package:ride_sharing/model/kycModels.dart';
import 'package:ride_sharing/widgets/consonants/apiConsonants.dart';
import 'package:ride_sharing/widgets/consonants/tokenStorage.dart';

/// Identity verification, on either side of the line where an account starts
/// existing.
///
/// During signup there is no account and no session — the verification runs
/// against the pending signup, and the poll that first comes back APPROVED is
/// the one that creates the account and hands over its token. This class saves
/// that token, so callers see nothing but "approved" and carry on.
///
/// Afterwards (a re-verification from the profile screen) the ordinary
/// authenticated endpoints apply. Which pair is used is decided by whether a
/// session token exists, which during signup it never does.
class Kycservice {
  final Apiclient apiclient;

  Kycservice({required this.apiclient});

  /// Starts (or restarts) a Didit verification session. The returned
  /// [KycStatusResponse.verificationUrl] is the hosted page to open in the
  /// browser; [KycStatusResponse.sessionToken] feeds Didit's native SDK.
  Future<KycStatusResponse> startVerification() async {
    final onboardingToken = await _onboardingTokenIfNoSession();
    if (onboardingToken != null) {
      final json = await apiclient.post(
        Apiconsonants.onboardingKycStartEndpoint,
        const {},
        token: onboardingToken,
      );
      final state = OnboardingState.fromJson(json as Map<String, dynamic>);
      await Tokenstorage.saveOnboardingToken(state.onboardingToken);
      return state.kyc ??
          const KycStatusResponse(status: 'IN_PROGRESS');
    }
    final json = await apiclient.post(Apiconsonants.kycStartEndpoint, const {});
    return KycStatusResponse.fromJson(json as Map<String, dynamic>);
  }

  /// The current KYC status. While a session is live the backend polls Didit
  /// on every call, so this is safe to poll every few seconds.
  ///
  /// During signup, an APPROVED answer arrives together with the new account's
  /// token: it is stored here and the onboarding leftovers are dropped, so by
  /// the time the caller sees "approved" the app is holding a real session.
  Future<KycStatusResponse> getStatus() async {
    final onboardingToken = await _onboardingTokenIfNoSession();
    if (onboardingToken != null) {
      final json = await apiclient.get(
        Apiconsonants.onboardingKycStatusEndpoint,
        token: onboardingToken,
      );
      final state = OnboardingState.fromJson(json as Map<String, dynamic>);
      if (state.isComplete) {
        // The account exists as of this response. Save the session BEFORE
        // clearing the onboarding keys, so a crash between the two leaves a
        // usable session rather than nothing at all.
        await Tokenstorage.saveToken(state.token);
        await Tokenstorage.clearOnboarding();
        return state.kyc ?? const KycStatusResponse(status: 'APPROVED');
      }
      await Tokenstorage.saveOnboardingToken(state.onboardingToken);
      return state.kyc ?? const KycStatusResponse(status: 'NOT_STARTED');
    }
    final json = await apiclient.get(Apiconsonants.kycStatusEndpoint);
    return KycStatusResponse.fromJson(json as Map<String, dynamic>);
  }

  /// Corrects the gender picked at registration — the fix for the commonest
  /// decline, where the scanned CNIC contradicts the account.
  ///
  /// During signup this is free: nothing has been verified against the value
  /// yet, and no session token exists to reissue. On a real account the
  /// backend refuses, because by then the value carries a checked CNIC behind
  /// it.
  Future<void> changeGender(String gender) async {
    final onboardingToken = await _onboardingTokenIfNoSession();
    if (onboardingToken == null) {
      throw StateError(
        'Gender was verified against your CNIC and can no longer be changed.',
      );
    }
    final json = await apiclient.post(
      Apiconsonants.onboardingGenderEndpoint,
      {"gender": gender},
      token: onboardingToken,
    );
    final state = OnboardingState.fromJson(json as Map<String, dynamic>);
    await Tokenstorage.saveOnboardingToken(state.onboardingToken);
  }

  Future<String?> _onboardingTokenIfNoSession() async {
    if (await Tokenstorage.hasToken()) return null;
    final onboardingToken = await Tokenstorage.getOnboardingToken();
    return (onboardingToken == null || onboardingToken.isEmpty)
        ? null
        : onboardingToken;
  }
}
