import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ride_sharing/controller/profileService.dart';
import 'package:ride_sharing/model/profileModels.dart';
import 'package:ride_sharing/provider/providers.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';

/// Fetches the currently-authenticated passenger's profile. Auto-cached
/// by Riverpod, so multiple widgets reading it share one network call.
/// Force a refetch with `ref.invalidate(passengerProfileProvider)`
/// (e.g. from a pull-to-refresh or after editing the profile).
final passengerProfileProvider = FutureProvider<PassengerProfileResponse>((
  ref,
) {
  return ref.read(profileServiceProvider).getPassengerProfile();
});

/// Driver counterpart of [passengerProfileProvider]. Same caching /
/// invalidation pattern.
final driverProfileProvider = FutureProvider<DriverProfileResponse>((ref) {
  return ref.read(profileServiceProvider).getDriverProfile();
});

class ProfileState {
  final bool isloading;
  final String? error;
  final bool isSuccess;
  final PassengerProfileResponse? passenger;
  final DriverProfileResponse? driver;

  const ProfileState({
    this.isloading = false,
    this.error,
    this.isSuccess = false,
    this.passenger,
    this.driver,
  });

  /// `clearError: true` resets [error] to null (the only way to clear it
  /// since we want copyWith() to default to *preserving* prior fields).
  ProfileState copyWith({
    bool? isloading,
    String? error,
    bool clearError = false,
    bool? isSuccess,
    PassengerProfileResponse? passenger,
    DriverProfileResponse? driver,
  }) {
    return ProfileState(
      isloading: isloading ?? this.isloading,
      error: clearError ? null : (error ?? this.error),
      isSuccess: isSuccess ?? this.isSuccess,
      passenger: passenger ?? this.passenger,
      driver: driver ?? this.driver,
    );
  }
}

final profileControllerProvider =
    StateNotifierProvider<Profileprovider, ProfileState>((ref) {
      final profileservice = ref.read(profileServiceProvider);
      return Profileprovider(profileservice);
    });

class Profileprovider extends StateNotifier<ProfileState> {
  final Profileservice profileservice;
  Profileprovider(this.profileservice) : super(const ProfileState());

  Future<PassengerProfileResponse> createPassengerProfile(
    PassengerProfileRequest request,
  ) async {
    state = state.copyWith(
      isloading: true,
      isSuccess: false,
      clearError: true,
    );
    try {
      final response = await profileservice.createPassengerProfile(request);
      state = state.copyWith(
        isloading: false,
        isSuccess: true,
        passenger: response,
      );
      return response;
    } catch (e) {
      state = state.copyWith(
        isloading: false,
        isSuccess: false,
        error: ErrorHandler.message(e),
      );
      rethrow;
    }
  }

  Future<PassengerProfileResponse> updatePassengerProfile(
    PassengerProfileRequest request,
  ) async {
    state = state.copyWith(
      isloading: true,
      isSuccess: false,
      clearError: true,
    );
    try {
      final response = await profileservice.updatePassengerProfile(request);
      state = state.copyWith(
        isloading: false,
        isSuccess: true,
        passenger: response,
      );
      return response;
    } catch (e) {
      state = state.copyWith(
        isloading: false,
        isSuccess: false,
        error: ErrorHandler.message(e),
      );
      rethrow;
    }
  }

  Future<DriverProfileResponse> createDriverProfile(
    DriverProfileRequest request,
  ) async {
    state = state.copyWith(
      isloading: true,
      isSuccess: false,
      clearError: true,
    );
    try {
      final response = await profileservice.createDriverProfile(request);
      state = state.copyWith(
        isloading: false,
        isSuccess: true,
        driver: response,
      );
      return response;
    } catch (e) {
      state = state.copyWith(
        isloading: false,
        isSuccess: false,
        error: ErrorHandler.message(e),
      );
      rethrow;
    }
  }

  Future<DriverProfileResponse> updateDriverProfile(
    DriverProfileRequest request,
  ) async {
    state = state.copyWith(
      isloading: true,
      isSuccess: false,
      clearError: true,
    );
    try {
      final response = await profileservice.updateDriverProfile(request);
      state = state.copyWith(
        isloading: false,
        isSuccess: true,
        driver: response,
      );
      return response;
    } catch (e) {
      state = state.copyWith(
        isloading: false,
        isSuccess: false,
        error: ErrorHandler.message(e),
      );
      rethrow;
    }
  }

  /// Resets the transient flags (`isSuccess`, `error`) so a screen
  /// re-entering the flow doesn't see stale state from a prior attempt.
  void reset() {
    state = const ProfileState();
  }
}

/// Holds the partially-filled driver onboarding form between step 1
/// (`driverProfileData`) and step 2 (`driverVehicleDetails`). The combined
/// `POST /api/v1/profile/driver` is fired only on step 2, so step 1 stashes
/// personal details here and step 2 reads them back.
class DriverOnboardingPersonal {
  final String fullName;
  final String phoneNo;
  final String cnic;

  const DriverOnboardingPersonal({
    required this.fullName,
    required this.phoneNo,
    required this.cnic,
  });
}

class DriverOnboardingNotifier
    extends StateNotifier<DriverOnboardingPersonal?> {
  DriverOnboardingNotifier() : super(null);

  void savePersonal(DriverOnboardingPersonal personal) => state = personal;
  void clear() => state = null;
}

final driverOnboardingProvider =
    StateNotifierProvider<DriverOnboardingNotifier, DriverOnboardingPersonal?>(
      (ref) => DriverOnboardingNotifier(),
    );
