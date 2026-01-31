import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ride_sharing/controller/authService.dart';
import 'package:ride_sharing/model/login.dart';
import 'package:ride_sharing/model/register.dart';

class Authprovider extends StateNotifier<AsyncValue<void>> {
  final Authservice authservice;
  Authprovider(this.authservice) : super(const AsyncValue.loading());

  Future<LoginResponse> loginProvider(LoginRequest request) async {
    state = const AsyncValue.loading();
    try {
      final response = await authservice.login(request);
      state = AsyncValue.data(null);
      return response;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<RegisterResponse> registerProvider(RegisterRequest request) async {
    state = const AsyncValue.loading();
    try {
      final response = await authservice.register(request);
      state = AsyncValue.data(null);
      return response;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}
