import 'package:flutter_riverpod/legacy.dart';
import 'package:ride_sharing/controller/authService.dart';
import 'package:ride_sharing/model/login.dart';
import 'package:ride_sharing/model/register.dart';
import 'package:ride_sharing/provider/providers.dart';

final authControllerProvider = StateNotifierProvider<Authprovider, AuthState>((
  ref,
) {
  final authservice = ref.read(authServiceProvider);
  return Authprovider(authservice);
});

class Authprovider extends StateNotifier<AuthState> {
  final Authservice authservice;
  Authprovider(this.authservice)
    : super(AuthState(isloading: false, error: null, isSuccess: false));

  Future<LoginResponse> loginProvider(LoginRequest request) async {
    state = state.copyWith(isloading: true, error: null, isSuccess: false);
    try {
      final response = await authservice.login(request);
      state = state.copyWith(isloading: false, error: null, isSuccess: true);
      return response;
    } catch (e) {
      state = state.copyWith(
        isloading: false,
        error: e.toString(),
        isSuccess: false,
      );
      rethrow;
    }
  }

  Future<RegisterResponse> registerProvider(RegisterRequest request) async {
    state = state.copyWith(isloading: true, error: null, isSuccess: false);
    try {
      final response = await authservice.register(request);
      state = state.copyWith(isloading: false, error: null, isSuccess: true);
      return response;
    } catch (e) {
      state = state.copyWith(
        isloading: false,
        error: e.toString(),
        isSuccess: false,
      );
      rethrow;
    }
  }
}

class AuthState {
  final bool isloading;
  final String? error;
  final bool isSuccess;

  AuthState({required this.isloading, this.error, required this.isSuccess});

  AuthState copyWith({bool? isloading, String? error, bool? isSuccess}) {
    return AuthState(
      isloading: isloading ?? this.isloading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

final genderProvider = StateNotifierProvider<GenderNotifier, String?>((ref) {
  return GenderNotifier();
});

class GenderNotifier extends StateNotifier<String?> {
  GenderNotifier() : super(null);

  void selectMale() {
    if (state == "MALE") {
      state = null;
    } else {
      state = "MALE";
    }
  }

  void selectFemale() {
    if (state == "FEMALE") {
      state = null;
    } else {
      state = "FEMALE";
    }
  }
}
