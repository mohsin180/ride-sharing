/// Backend contract for KYC (Didit identity verification), shared by
/// drivers and passengers — the backend picks the profile from the JWT role.
///
/// `POST /api/v1/kyc/session` → starts a verification session; the response
/// carries a [sessionToken] for Didit's native SDK plus a [verificationUrl]
/// as the browser fallback.
/// `GET /api/v1/kyc/status` → the current status; the backend polls Didit
/// server-side while a session is live.
class KycStatusResponse {
  /// NOT_STARTED / IN_PROGRESS / IN_REVIEW / APPROVED / DECLINED.
  final String status;

  /// Token for `DiditSdk.startVerification` — only set right after starting
  /// a session.
  final String? sessionToken;

  /// Didit's hosted flow URL — the fallback when the native SDK can't run.
  final String? verificationUrl;

  /// When the user was approved (ISO string), null otherwise.
  final String? verifiedAt;

  /// Why verification was refused — set when the scanned CNIC contradicts the
  /// account (gender, CNIC number, age, expiry). Null for a plain decline
  /// from Didit itself.
  final String? rejectionReason;

  const KycStatusResponse({
    required this.status,
    this.sessionToken,
    this.verificationUrl,
    this.verifiedAt,
    this.rejectionReason,
  });

  factory KycStatusResponse.fromJson(Map<String, dynamic> json) {
    return KycStatusResponse(
      status: (json['status'] as String?) ?? 'NOT_STARTED',
      sessionToken: json['sessionToken'] as String?,
      verificationUrl: json['verificationUrl'] as String?,
      verifiedAt: json['verifiedAt'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
    );
  }

  bool get isApproved => status == 'APPROVED';
  bool get isDeclined => status == 'DECLINED';
  bool get isInReview => status == 'IN_REVIEW';
  bool get isInProgress => status == 'IN_PROGRESS';
}
