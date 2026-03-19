import 'package:flutter_riverpod/legacy.dart';
import 'package:ride_sharing/controller/profileService.dart';
import 'package:ride_sharing/model/profileModels.dart';
import 'package:ride_sharing/provider/providers.dart';

class ProfileState {
  final bool isloading;
  final String? error;

  ProfileState({required this.isloading, required this.error});

  ProfileState copyWith({bool? isloading, String? error}) {
    return ProfileState(
      isloading: isloading ?? this.isloading,
      error: error ?? this.error,
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
  Profileprovider(this.profileservice)
    : super(ProfileState(isloading: false, error: null));
  // state management for creating passenger profile
  Future<PassengerProfileResponse> createPassengerProfile(
    PassengerProfileRequest request,
  ) async {
    state = state.copyWith(isloading: true);
    try {
      final response = await profileservice.createPassengerProfile(request);
      state = state.copyWith(isloading: false);
      return response;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isloading: false);
      rethrow;
    }
  }

  // state management for creating driver profile
  Future<DriverProfileResponse> createDriverProfile(
    DriverProfileRequest request,
  ) async {
    state = state.copyWith(isloading: true);
    try {
      final response = await profileservice.createDriverProfile(request);
      state = state.copyWith(isloading: false);
      return response;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isloading: false);
      rethrow;
    }
  }
}
