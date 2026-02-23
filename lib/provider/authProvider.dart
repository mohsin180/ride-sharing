import 'package:flutter_riverpod/legacy.dart';
import 'package:ride_sharing/controller/authService.dart';
import 'package:ride_sharing/model/authModels.dart';
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
    : super(
        AuthState(
          isloading: false,
          error: null,
          isLoggedIn: false,
          isRegistered: false,
          emailVerified: null,
          userId: null,
          isSuccess: null,
        ),
      );

  Future<LoginResponse> loginProvider(LoginRequest request) async {
    state = state.copyWith(isloading: true, error: null, isLoggedIn: false);
    try {
      final response = await authservice.login(request);
      state = state.copyWith(isloading: false, error: null, isLoggedIn: true);
      return response;
    } catch (e) {
      state = state.copyWith(
        isloading: false,
        error: e.toString(),
        isLoggedIn: false,
      );
      rethrow;
    }
  }

  Future<RegisterResponse> registerProvider(RegisterRequest request) async {
    state = state.copyWith(isloading: true, error: null, isRegistered: false);
    try {
      final response = await authservice.register(request);
      state = state.copyWith(
        isloading: false,
        error: null,
        isRegistered: true,
        userId: response.userId,
      );
      return response;
    } catch (e) {
      state = state.copyWith(
        isloading: false,
        error: e.toString(),
        isRegistered: false,
      );
      rethrow;
    }
  }

  Future<bool> isEmailVerified(String userId) async {
    state = state.copyWith(isloading: true, error: null, emailVerified: false);
    try {
      final verified = await authservice.isEmailVerified(userId);
      state = state.copyWith(isloading: false, emailVerified: verified);
      return verified;
    } catch (e) {
      state = state.copyWith(isloading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> forgotpassword(ForgotPassword request) async {
    state = state.copyWith(isloading: true, error: null, isSuccess: false);
    try {
      await authservice.forgotPassword(request);
      state = state.copyWith(isloading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> resetPassword(ResetPasswordDto request) async {
    state = state.copyWith(isloading: true, error: null, isSuccess: false);
    try {
      await authservice.resetPassword(request);
      state = state.copyWith(isloading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<bool> checkResetStatus(String token) async {
    try {
      final verified = await authservice.checkResetStatus(token);
      return verified;
    } catch (e) {
      rethrow;
    }
  }
}

class AuthState {
  final bool isloading;
  final String? error;

  final bool isLoggedIn;
  final bool isRegistered;
  final bool? emailVerified;
  final String? userId; // null = not checked yet
  final bool? isSuccess;

  AuthState({
    required this.isloading,
    this.error,
    required this.isLoggedIn,
    required this.isRegistered,
    this.emailVerified,
    this.userId,
    this.isSuccess,
  });

  AuthState copyWith({
    bool? isloading,
    String? error,
    bool? isLoggedIn,
    bool? isRegistered,
    bool? emailVerified,
    String? userId,
    bool? isSuccess,
  }) {
    return AuthState(
      isloading: isloading ?? this.isloading,
      error: error,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isRegistered: isRegistered ?? this.isRegistered,

      emailVerified: emailVerified ?? this.emailVerified,
      userId: userId ?? this.userId,
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

final roleProvider = StateNotifierProvider<RoleNotifier, String?>((ref) {
  return RoleNotifier();
});

class RoleNotifier extends StateNotifier<String?> {
  RoleNotifier() : super(null);

  void selectPassenger() {
    if (state == "PASSENGER") {
      state = null;
    } else {
      state = "PASSENGER";
    }
  }

  void selectDriver() {
    if (state == "DRIVER") {
      state = null;
    } else {
      state = "DRIVER";
    }
  }
}
