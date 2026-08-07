import 'package:ride_sharing/controller/apiClient.dart';
import 'package:ride_sharing/model/kycModels.dart';
import 'package:ride_sharing/widgets/consonants/apiConsonants.dart';

class Kycservice {
  final Apiclient apiclient;

  Kycservice({required this.apiclient});

  /// Starts (or restarts) a Didit verification session for the
  /// authenticated driver. The returned [KycStatusResponse.verificationUrl]
  /// is the hosted page to open in the browser.
  Future<KycStatusResponse> startVerification() async {
    final json = await apiclient.post(Apiconsonants.kycStartEndpoint, {});
    return KycStatusResponse.fromJson(json as Map<String, dynamic>);
  }

  /// The driver's current KYC status. While a session is live the backend
  /// polls Didit on every call, so this is safe to poll every few seconds.
  Future<KycStatusResponse> getStatus() async {
    final json = await apiclient.get(Apiconsonants.kycStatusEndpoint);
    return KycStatusResponse.fromJson(json as Map<String, dynamic>);
  }
}
