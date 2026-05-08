import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ride_sharing/controller/authService.dart';
import 'package:ride_sharing/model/authModels.dart';
import 'package:ride_sharing/provider/providers.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/consonants/tokenStorage.dart';

final authControllerProvider = StateNotifierProvider<Authprovider, AuthState>((
  ref,
) {
  final authservice = ref.read(authServiceProvider);
  return Authprovider(authservice);
});

// This provider holds the JWT access token

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
          email: null,
        ),
      );

  Future<LoginResponse> loginProvider(LoginRequest request) async {
    state = state.copyWith(isloading: true, error: null, isLoggedIn: false);
    try {
      final response = await authservice.login(request);
      await Tokenstorage.saveToken(response.token);
      state = state.copyWith(isloading: false, error: null, isLoggedIn: true);
      return response;
    } catch (e) {
      state = state.copyWith(
        isloading: false,
        error: ErrorHandler.message(e),
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
        userId: response.id,
        email: response.email,
      );
      return response;
    } catch (e) {
      state = state.copyWith(
        isloading: false,
        error: ErrorHandler.message(e),
        isRegistered: false,
      );
      rethrow;
    }
  }

  Future<void> verifyEmail(String token) async {
    state = state.copyWith(isloading: true, error: null);
    try {
      await authservice.verifyEmail(token);
      state = state.copyWith(isloading: false);
    } catch (e) {
      state = state.copyWith(isloading: false, error: ErrorHandler.message(e));
    }
  }

  Future<bool> isEmailVerified(String userId) async {
    state = state.copyWith(isloading: true, error: null, emailVerified: false);
    try {
      final verified = await authservice.isEmailVerified(userId);
      state = state.copyWith(isloading: false, emailVerified: verified);
      return verified;
    } catch (e) {
      state = state.copyWith(isloading: false, error: ErrorHandler.message(e));
      rethrow;
    }
  }

  Future<void> forgotpassword(ForgotPassword request) async {
    state = state.copyWith(isloading: true, error: null, isSuccess: false);
    try {
      await authservice.forgotPassword(request);
      state = state.copyWith(isloading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isloading: false, error: ErrorHandler.message(e));
      rethrow;
    }
  }

  Future<void> resetPassword(ResetPasswordDto request) async {
    state = state.copyWith(isloading: true, error: null, isSuccess: false);
    try {
      await authservice.resetPassword(request);
      state = state.copyWith(isloading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isloading: false, error: ErrorHandler.message(e));
      rethrow;
    }
  }

  Future<void> logout() async {
    await Tokenstorage.deleteToken();
    state = AuthState(
      isloading: false,
      error: null,
      isLoggedIn: false,
      isRegistered: false,
    );
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
  final String? email;

  AuthState({
    required this.isloading,
    this.error,
    required this.isLoggedIn,
    required this.isRegistered,
    this.emailVerified,
    this.userId,
    this.isSuccess,
    this.email,
  });

  AuthState copyWith({
    bool? isloading,
    String? error,
    bool? isLoggedIn,
    bool? isRegistered,
    bool? emailVerified,
    String? userId,
    bool? isSuccess,
    String? email,
  }) {
    return AuthState(
      isloading: isloading ?? this.isloading,
      error: error,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isRegistered: isRegistered ?? this.isRegistered,

      emailVerified: emailVerified ?? this.emailVerified,
      userId: userId ?? this.userId,
      isSuccess: isSuccess ?? this.isSuccess,
      email: email ?? this.email,
    );
  }
}

/// Validates a password-reset token against the backend on demand.
/// Used by [Newpassword] to gate the form behind a valid token. Family
/// param is the token string from the deep link.
final resetTokenStatusProvider = FutureProvider.family<bool, String>((
  ref,
  token,
) {
  return ref.read(authServiceProvider).checkResetStatus(token);
});

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

class RoleState {
  final bool isLoading;
  final String? error;
  final LoginResponse? response;
  RoleState({this.isLoading = false, this.error, this.response});

  RoleState copyWith({
    bool? isLoading,
    String? error,
    LoginResponse? response,
  }) {
    return RoleState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      response: response ?? this.response,
    );
  }
}

class RoleNotifier extends StateNotifier<RoleState> {
  final Authservice authservice;
  RoleNotifier({required this.authservice}) : super(RoleState());

  Future<void> selectRole(String userId, String role) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final response = await authservice.assignRole(userId, role);
      await Tokenstorage.saveToken(response.token);
      state = state.copyWith(isLoading: false, response: response);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: ErrorHandler.message(e));
    }
  }
}

final roleProvider = StateNotifierProvider<RoleNotifier, RoleState>((ref) {
  final authservice = ref.read(authServiceProvider);
  return RoleNotifier(authservice: authservice);
});

final selectedRoleProvider =
    StateNotifierProvider<RoleSelectionNotifier, String?>(
      (ref) => RoleSelectionNotifier(),
    );

class RoleSelectionNotifier extends StateNotifier<String?> {
  RoleSelectionNotifier() : super(null);

  /// Select passenger
  void selectPassenger() {
    state = state == "PASSENGER" ? null : "PASSENGER";
  }

  /// Select driver
  void selectDriver() {
    state = state == "DRIVER" ? null : "DRIVER";
  }

  /// Generic setter
  void selectRole(String role) {
    state = state == role ? null : role;
  }
}
