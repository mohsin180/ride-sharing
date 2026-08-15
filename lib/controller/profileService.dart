import 'package:ride_sharing/controller/apiClient.dart';
import 'package:ride_sharing/model/profileModels.dart';
import 'package:ride_sharing/widgets/consonants/apiConsonants.dart';
import 'package:ride_sharing/widgets/consonants/tokenStorage.dart';

class Profileservice {
  final Apiclient apiclient;

  Profileservice({required this.apiclient});

  /// Saves the passenger's details.
  ///
  /// During signup this goes to the onboarding endpoint, because no account
  /// exists yet to hang a profile off — the details are held with the pending
  /// signup and only become a real profile row once identity verification
  /// passes. Afterwards (a re-run from an edit screen) the ordinary profile
  /// endpoint applies. The two are told apart by whether a session token
  /// exists, which during signup it never does.
  Future<PassengerProfileResponse> createPassengerProfile(
    PassengerProfileRequest request,
  ) async {
    final onboardingToken = await _onboardingTokenIfNoSession();
    if (onboardingToken != null) {
      await apiclient.post(
        Apiconsonants.onboardingPassengerProfileEndpoint,
        request.toJson(),
        token: onboardingToken,
      );
      // The onboarding reply describes the signup's stage, not a profile row
      // (there isn't one yet). Echo back what we just sent so the screens
      // that show it keep working unchanged.
      return PassengerProfileResponse(
        fullName: request.fullName,
        phoneNo: request.phoneNo,
        cnic: request.cnic,
      );
    }
    final json = await apiclient.post(
      Apiconsonants.createPassengerProfileEndpoint,
      request.toJson(),
    );
    return PassengerProfileResponse.fromJson(json as Map<String, dynamic>);
  }

  /// Saves the driver's details and vehicle. Same split as
  /// [createPassengerProfile].
  Future<DriverProfileResponse> createDriverProfile(
    DriverProfileRequest request,
  ) async {
    final onboardingToken = await _onboardingTokenIfNoSession();
    if (onboardingToken != null) {
      await apiclient.post(
        Apiconsonants.onboardingDriverProfileEndpoint,
        request.toJson(),
        token: onboardingToken,
      );
      return DriverProfileResponse(
        fullName: request.fullName,
        phoneNo: request.phoneNo,
        cnic: request.cnic,
        vehicle: VehicleResponse(
          make: request.vehicle.make,
          model: request.vehicle.model,
          number: request.vehicle.number,
          color: request.vehicle.color,
          seats: request.vehicle.seats,
          year: request.vehicle.year,
        ),
      );
    }
    final json = await apiclient.post(
      Apiconsonants.createDriverProfileEndpoint,
      request.toJson(),
    );
    return DriverProfileResponse.fromJson(json as Map<String, dynamic>);
  }

  /// The onboarding token, but only while there is no session — i.e. only
  /// while signup is genuinely still in progress. Returns null otherwise so
  /// the caller takes the ordinary authenticated path.
  Future<String?> _onboardingTokenIfNoSession() async {
    if (await Tokenstorage.hasToken()) return null;
    final onboardingToken = await Tokenstorage.getOnboardingToken();
    return (onboardingToken == null || onboardingToken.isEmpty)
        ? null
        : onboardingToken;
  }

  /// Fetches the currently-authenticated passenger's profile. The user is
  /// identified by the JWT (auto-attached by [Apiclient]); no userId in
  /// the path or body.
  ///
  /// Mid-signup there is no profile row, so the pending details are served
  /// instead — otherwise the edit screen a KYC decline sends the user to
  /// would open blank, or fail outright for want of a session.
  Future<PassengerProfileResponse> getPassengerProfile() async {
    final onboardingToken = await _onboardingTokenIfNoSession();
    if (onboardingToken != null) {
      final state = await _onboardingState(onboardingToken);
      return PassengerProfileResponse(
        fullName: (state['fullName'] ?? '').toString(),
        phoneNo: (state['phoneNo'] ?? '').toString(),
        cnic: (state['cnic'] ?? '').toString(),
        email: state['email']?.toString(),
        gender: state['gender']?.toString(),
        kycStatus: (state['kyc'] as Map<String, dynamic>?)?['status']?.toString(),
      );
    }
    final json = await apiclient.get(Apiconsonants.getPassengerProfileEndpoint);
    return PassengerProfileResponse.fromJson(json as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> _onboardingState(String onboardingToken) async {
    final json = await apiclient.get(
      Apiconsonants.onboardingStateEndpoint,
      token: onboardingToken,
    );
    return json as Map<String, dynamic>;
  }

  /// Updates the authenticated passenger's profile. Backend contract:
  /// `PUT /api/v1/profile/passenger` with the same body shape as create
  /// — `{ fullName, phoneNo, cnic }`. Email and gender are *not* edited
  /// here (email change typically requires re-verification; gender is
  /// fixed at signup).
  /// Mid-signup this is the same call as create — there is no profile row to
  /// update, only pending details to overwrite. It matters because a KYC
  /// decline sends the user straight to the edit screen to correct the CNIC
  /// or name the scanned card contradicted, and at that point they still have
  /// no account.
  Future<PassengerProfileResponse> updatePassengerProfile(
    PassengerProfileRequest request,
  ) async {
    if (await _onboardingTokenIfNoSession() != null) {
      return createPassengerProfile(request);
    }
    final json = await apiclient.put(
      Apiconsonants.updatePassengerProfileEndpoint,
      request.toJson(),
    );
    return PassengerProfileResponse.fromJson(json as Map<String, dynamic>);
  }

  /// Fetches the currently-authenticated driver's profile (incl. vehicle).
  /// Same JWT-based identification as the passenger endpoint, and the same
  /// mid-signup fallback as [getPassengerProfile].
  Future<DriverProfileResponse> getDriverProfile() async {
    final onboardingToken = await _onboardingTokenIfNoSession();
    if (onboardingToken != null) {
      final state = await _onboardingState(onboardingToken);
      final v = state['vehicle'] as Map<String, dynamic>?;
      return DriverProfileResponse(
        fullName: (state['fullName'] ?? '').toString(),
        phoneNo: (state['phoneNo'] ?? '').toString(),
        cnic: (state['cnic'] ?? '').toString(),
        email: state['email']?.toString(),
        gender: state['gender']?.toString(),
        kycStatus: (state['kyc'] as Map<String, dynamic>?)?['status']?.toString(),
        vehicle: VehicleResponse(
          make: (v?['make'] ?? '').toString(),
          model: (v?['model'] ?? '').toString(),
          number: (v?['number'] ?? '').toString(),
          color: (v?['color'] ?? '').toString(),
          seats: (v?['seats'] as num?)?.toInt() ?? 0,
          year: (v?['year'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    final json = await apiclient.get(Apiconsonants.getDriverProfileEndpoint);
    return DriverProfileResponse.fromJson(json as Map<String, dynamic>);
  }

  /// Updates the authenticated driver's profile. Backend contract:
  /// `PUT /api/v1/profile/driver` with the same body shape as create —
  /// `{ fullName, phoneNo, cnic, vehicle: {...} }`. Email and gender
  /// are intentionally not editable here.
  /// Same onboarding split as [updatePassengerProfile].
  Future<DriverProfileResponse> updateDriverProfile(
    DriverProfileRequest request,
  ) async {
    if (await _onboardingTokenIfNoSession() != null) {
      return createDriverProfile(request);
    }
    final json = await apiclient.put(
      Apiconsonants.updateDriverProfileEndpoint,
      request.toJson(),
    );
    return DriverProfileResponse.fromJson(json as Map<String, dynamic>);
  }
}
