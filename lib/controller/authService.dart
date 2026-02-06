import 'package:ride_sharing/controller/apiClient.dart';
import 'package:ride_sharing/model/login.dart';
import 'package:ride_sharing/model/register.dart';
import 'package:ride_sharing/widgets/consonants/apiConsonants.dart';

class Authservice {
  final Apiclient apiclient;
  Authservice({required this.apiclient});

  Future<LoginResponse> login(LoginRequest request) async {
    final json = await apiclient.post(
      Apiconsonants.loginEndpoint,
      request.toJson(),
    );
    return LoginResponse.fromJson(json);
  }

  Future<RegisterResponse> register(RegisterRequest request) async {
    final json = await apiclient.post(
      Apiconsonants.registerEndpoint,
      request.toJson(),
    );
    return RegisterResponse.fromJson(json);
  }

  Future<bool> isEmailVerified(String userId) async {
    final isEmailVerifiedEndpoint =
        "http://localhost:8080/api/v1/user/$userId/is-Email-Verified";
    final result = await apiclient.get(isEmailVerifiedEndpoint);
    return result;
  }
}
