import 'dart:async';

import 'package:didit_sdk/sdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/controller/apiClient.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/model/kycModels.dart';
import 'package:ride_sharing/provider/providers.dart';
import 'package:ride_sharing/view/editProfile.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/custom/appComponents.dart';
import 'package:ride_sharing/widgets/custom/responsive.dart';
import 'package:url_launcher/url_launcher.dart';

/// Identity verification (KYC) — the last step of both onboarding wizards.
///
/// Tapping "Verify my identity" asks the backend to create a Didit session,
/// then runs the CNIC scan + selfie liveness through Didit's **native SDK**,
/// which presents its own full-screen flow without leaving the app. If the
/// SDK can't run (no plugin on this platform, or a native failure), we fall
/// back to opening Didit's hosted page in the browser.
///
/// Either way the SDK's own result is only a UI hint — the backend, which
/// polls Didit server-side, stays the source of truth. So after the flow
/// ends we poll `GET /api/v1/kyc/status` every [_pollInterval] (same pattern
/// as [Verificationscreen]) and advance to the app on approval.
///
/// The backend picks the driver or passenger profile from the JWT role, so
/// [isDriver] only shapes the copy — the endpoints are identical.
class KycScreen extends ConsumerStatefulWidget {
  final bool isDriver;

  const KycScreen({super.key, required this.isDriver});

  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen> {
  static const _pollInterval = Duration(seconds: 5);

  Timer? _timer;
  bool _checkInFlight = false;
  bool _navigated = false;
  bool _starting = false;

  /// Last status seen from the backend; null until the first response.
  KycStatusResponse? _kyc;

  @override
  void initState() {
    super.initState();
    // One initial status check so a user who left mid-verification resumes
    // with the right UI (and an already-approved one skips ahead).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkOnce();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startVerification() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final kyc = await ref.read(kycServiceProvider).startVerification();
      if (!mounted) return;
      setState(() => _kyc = kyc);
      if (kyc.isApproved) {
        _goToApp();
        return;
      }
      final token = kyc.sessionToken;
      if (token != null && token.isNotEmpty && await _runNativeFlow(token)) {
        return;
      }
      await _openHostedFlow(kyc.verificationUrl);
    } on ApiException catch (e) {
      if (mounted) ErrorHandler.show(context, e.message);
    } catch (_) {
      if (mounted) ErrorHandler.show(context, "Could not start verification.");
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  /// Runs Didit's native full-screen flow. Returns false when the SDK isn't
  /// usable on this platform so the caller can fall back to the browser;
  /// true means the flow ran and its outcome has been handled here.
  Future<bool> _runNativeFlow(String token) async {
    final VerificationResult result;
    try {
      result = await DiditSdk.startVerification(
        token,
        // Dismiss Didit's UI as soon as it finishes — this screen takes over
        // and waits for the backend's verdict.
        config: const DiditConfig(closeOnComplete: true),
      );
    } on MissingPluginException {
      return false; // No native side (web/desktop) — use the hosted page.
    } on PlatformException {
      return false;
    }
    if (!mounted) return true;

    switch (result) {
      case VerificationFailed(:final error):
        ErrorHandler.show(context, error.message);
      case VerificationCancelled():
      case VerificationCompleted():
        break;
    }
    // Didit's own result is advisory; confirm with our backend either way.
    // Completion can land a moment before the decision does, so keep polling.
    _ensurePolling();
    await _checkOnce();
    return true;
  }

  /// Browser fallback — Didit's hosted page, same session.
  Future<void> _openHostedFlow(String? url) async {
    if (url == null || url.isEmpty) {
      if (mounted) {
        ErrorHandler.show(context, "Verification link missing — try again.");
      }
      return;
    }
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!mounted) return;
    if (!launched) {
      ErrorHandler.show(context, "Could not open the verification page.");
      return;
    }
    // The user is now on Didit's page — watch for the result.
    _ensurePolling();
  }

  Future<void> _checkOnce() async {
    if (!mounted || _navigated || _checkInFlight) return;
    _checkInFlight = true;
    try {
      final kyc = await ref.read(kycServiceProvider).getStatus();
      if (!mounted || _navigated) return;
      setState(() => _kyc = kyc);
      if (kyc.isApproved) {
        _timer?.cancel();
        ErrorHandler.success(context, "Identity verified — you're all set!");
        _goToApp();
      } else if (kyc.isInProgress || kyc.isInReview) {
        // Both resolve on Didit's side, and with no skip button this screen
        // is the only way forward — keep watching so the user isn't stranded
        // (notably when they re-enter the app mid-review).
        _ensurePolling();
      } else {
        // DECLINED offers a retry button; NOT_STARTED has nothing to watch.
        _timer?.cancel();
      }
    } catch (_) {
      // Polling errors are intentionally swallowed; the timer keeps trying.
    } finally {
      _checkInFlight = false;
    }
  }

  /// Opens the shared edit-profile screen so a wrong CNIC or name can be
  /// corrected without leaving verification. It saves via `PUT` and pops
  /// itself, landing the user back here ready to retry.
  Future<void> _openProfileEditor() async {
    // Pause polling: a status arriving while the editor is open would push
    // this screen away underneath it.
    _timer?.cancel();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Editprofile(isPassenger: !widget.isDriver),
      ),
    );
    if (!mounted) return;
    // The saved CNIC may now match the card, so re-read where we stand.
    await _checkOnce();
  }

  /// Starts the status poll unless one is already running.
  void _ensurePolling() {
    if (_timer?.isActive ?? false) return;
    _timer = Timer.periodic(_pollInterval, (_) => _checkOnce());
  }

  void _goToApp() {
    if (_navigated) return;
    _navigated = true;
    _timer?.cancel();
    context.go(Approutes.bottomNavbar);
  }

  bool get _waiting => _timer?.isActive ?? false;

  @override
  Widget build(BuildContext context) {
    final status = _kyc?.status ?? 'NOT_STARTED';

    return ResponsiveAuthScaffold(
      bodyPadding: EdgeInsets.symmetric(
        horizontal: Consonants.gutter.w,
        vertical: 28.h,
      ),
      body: [
        SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Verify your identity",
                style: AppText.displayXs().copyWith(fontSize: 33.sp),
              ),
              SizedBox(height: 12.h),
              _stepPill(),
            ],
          ),
        ),
        SizedBox(height: 28.h),
        _steps(),
        SizedBox(height: 24.h),
        _statusIndicator(status),
      ],
      bottomBar: _bottomBar(status),
    );
  }

  // ── status area ──────────────────────────────────────────────────

  Widget _statusIndicator(String status) {
    // Review and decline carry more information than a spinner, so they win
    // even while the poll timer is running.
    if (status == 'IN_REVIEW') {
      return _statusChip(
        Icons.hourglass_empty_rounded,
        "Your verification is under review.",
        Consonants.indigo,
        Consonants.indigoWash,
      );
    }
    if (status == 'DECLINED') {
      // A mismatch reason names exactly what to fix (wrong gender on the
      // account, a CNIC that isn't yours); without one it's Didit's own
      // decline, where the usual cause is an unreadable scan.
      final reason = _kyc?.rejectionReason;
      return _statusChip(
        Icons.error_outline_rounded,
        reason != null && reason.isNotEmpty
            ? "$reason Fix that in your profile, then try again."
            : "Verification was declined. Make sure your CNIC is readable and "
                "your face is clearly visible, then try again.",
        Consonants.danger,
        Consonants.dangerWash,
      );
    }
    if (_waiting || status == 'IN_PROGRESS') {
      return Row(
        children: [
          SizedBox(
            width: 15.w,
            height: 15.w,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: Consonants.violet,
            ),
          ),
          SizedBox(width: 10.w),
          Flexible(
            child: Text(
              'Waiting for verification result…',
              style: AppText.caption().copyWith(fontSize: 13.sp),
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _statusChip(IconData icon, String text, Color colour, Color wash) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(Consonants.rCard.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19.sp, color: colour),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              text,
              maxLines: 6,
              style: AppText.rowLabel(color: Consonants.headingInk)
                  .copyWith(fontSize: 14.sp, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ── bottom bar ───────────────────────────────────────────────────

  Widget _bottomBar(String status) {
    final buttonLabel = switch (status) {
      'DECLINED' => 'Try Again',
      'IN_PROGRESS' => 'Reopen Verification',
      _ => 'Verify My Identity',
    };
    final showButton = status != 'IN_REVIEW' && status != 'APPROVED';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Consonants.gutter.w,
        12.h,
        Consonants.gutter.w,
        22.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showButton) ...[
            AppButton(
              label: buttonLabel,
              isLoading: _starting,
              onPressed: _startVerification,
            ),
            SizedBox(height: Consonants.gapButtons.h),
          ],
          // The only way out of this screen besides passing. There's no skip
          // (verification is mandatory) and no plain back button — the screens
          // behind this one create a profile and would reject a second
          // attempt, so "go back" has to mean "edit what you already saved".
          // Without this, a typo'd CNIC is unfixable and the account is stuck.
          GestureDetector(
            onTap: _openProfileEditor,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.edit_outlined,
                    size: 17.sp,
                    color: Consonants.indigo,
                  ),
                  SizedBox(width: 8.w),
                  Flexible(
                    child: Text(
                      "Wrong CNIC or name? Edit your details",
                      style: AppText.rowLabel(color: Consonants.indigo)
                          .copyWith(
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            "Verification is required before you can book or drive.",
            textAlign: TextAlign.center,
            style: AppText.caption().copyWith(fontSize: 13.sp),
          ),
        ],
      ),
    );
  }

  // ── decorative bits (visual language of the onboarding wizard) ───

  /// Drivers arrive here after two form steps; passengers after one.
  Widget _stepPill() {
    final label = widget.isDriver ? "Step 3 of 3" : "Step 2 of 2";
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: Consonants.chipBg,
          borderRadius: BorderRadius.circular(Consonants.rPill.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.badge_outlined,
              size: 15.sp,
              color: Consonants.iconInk,
            ),
            SizedBox(width: 7.w),
            Text(
              label,
              style: AppText.caption(color: Consonants.headingInk)
                  .copyWith(fontSize: 12.5.sp, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  /// What the flow asks of the user, as a plain list — three rows on the
  /// canvas divided by a rule, not a card (nothing here is tappable).
  Widget _steps() {
    return Column(
      children: [
        const AppDivider(),
        _stepRow(Icons.credit_card_outlined, "Scan your CNIC"),
        const AppDivider(),
        _stepRow(Icons.face_retouching_natural_outlined, "Take a selfie"),
        const AppDivider(),
        _stepRow(Icons.verified_outlined, "Get approved"),
        const AppDivider(),
      ],
    );
  }

  Widget _stepRow(IconData icon, String title) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Consonants.rowVertical.h),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Consonants.indigoWash,
            ),
            child: Icon(icon, size: 20.sp, color: Consonants.iconInk),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Text(
              title,
              style: AppText.rowLabel().copyWith(fontSize: 15.5.sp),
            ),
          ),
        ],
      ),
    );
  }
}
