import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/provider/authProvider.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/consonants/tokenStorage.dart';
import 'package:ride_sharing/widgets/custom/appComponents.dart';
import 'package:ride_sharing/widgets/custom/responsive.dart';

/// Polls the backend every [_pollInterval] for email-verification status.
/// On verified=true, advances to role selection.
class Verificationscreen extends ConsumerStatefulWidget {
  const Verificationscreen({super.key});

  @override
  ConsumerState<Verificationscreen> createState() => _VerificationscreenState();
}

class _VerificationscreenState extends ConsumerState<Verificationscreen> {
  static const _pollInterval = Duration(seconds: 5);

  Timer? _timer;
  bool _checkInFlight = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Kick off the first check on the next frame so the build has settled
    // and we have access to ref + context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkOnce();
      _timer = Timer.periodic(_pollInterval, (_) => _checkOnce());
    });
  }

  Future<void> _checkOnce() async {
    if (!mounted || _navigated || _checkInFlight) return;
    // Fall back to the persisted id: after a cold start (common here, since
    // the user leaves the app to open their email) the in-memory one is gone.
    final userId = ref.read(authControllerProvider).userId ??
        await Tokenstorage.getPendingUserId();
    if (userId == null || userId.isEmpty || !mounted) return;

    _checkInFlight = true;
    try {
      final verified = await ref
          .read(authControllerProvider.notifier)
          .isEmailVerified(userId);
      if (!mounted || _navigated) return;
      if (verified) {
        _navigated = true;
        _timer?.cancel();
        ErrorHandler.success(context, "Email verified");
        context.go(Approutes.roleSection);
      }
    } catch (_) {
      // Polling errors are intentionally swallowed — surfaced through
      // state.error → ref.listen below; the timer keeps trying.
    } finally {
      _checkInFlight = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ErrorHandler.show(context, next.error);
      }
    });

    final email = ref.watch(
      authControllerProvider.select((s) => s.email),
    );

    return PopScope(
      // The hardware back key gets the same treatment as the on-screen one:
      // leaving here has to tidy up, so it can't be a plain pop.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmStartOver();
      },
      child: ResponsiveAuthScaffold(
      header: Padding(
        padding: EdgeInsets.fromLTRB(Consonants.gutter.w, 8.h, Consonants.gutter.w, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AppIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: _confirmStartOver,
          ),
        ),
      ),
      bodyPadding: EdgeInsets.symmetric(vertical: 28.h),
      body: [
        // The illustration is the focal point; it sits on a lifted white card
        // rather than a Material Card so it matches every other surface.
        const _MailCard(),
        SizedBox(height: 32.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
          child: Text(
            'Verify Your Email',
            textAlign: TextAlign.center,
            style: AppText.displayXs().copyWith(fontSize: 32.sp),
          ),
        ),
        SizedBox(height: 10.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
          child: Text(
            'Click the link sent to',
            textAlign: TextAlign.center,
            style: AppText.paragraph().copyWith(fontSize: 15.5.sp),
          ),
        ),
        SizedBox(height: 12.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
          child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 9.h),
              decoration: BoxDecoration(
                color: Consonants.chipBg,
                borderRadius: BorderRadius.circular(Consonants.rPill.r),
              ),
              child: Text(
                email ?? 'your email',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.rowLabel(color: Consonants.headingInk)
                    .copyWith(fontSize: 15.sp, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        SizedBox(height: 26.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
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
            Text(
              'Waiting for verification…',
              style: AppText.caption().copyWith(fontSize: 13.sp),
            ),
          ],
        ),
      ],
      bottomBar: const VerificationContainer(),
      ),
    );
  }

  /// Leaving this screen means abandoning the sign-up, so it asks first and
  /// then clears up after itself.
  ///
  /// Just navigating away wouldn't be enough: registration persists a pending
  /// user id and onboarding token, and the splash screen resumes from those —
  /// so the next launch would drop the user straight back here, still waiting
  /// on the address they were trying to escape.
  Future<void> _confirmStartOver() async {
    _timer?.cancel();
    final startOver = await showDialog<bool>(
      context: context,
      barrierColor: Consonants.scrim,
      builder: (ctx) => Dialog(
        backgroundColor: Consonants.surface,
        insetPadding: EdgeInsets.symmetric(horizontal: 32.w),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Consonants.rHero.r),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(22.w, 26.h, 22.w, 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60.w,
                height: 60.w,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Consonants.indigoWash,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.alternate_email_rounded,
                  size: 26.sp,
                  color: Consonants.indigo,
                ),
              ),
              SizedBox(height: 18.h),
              Text(
                'Use a different email?',
                style: AppText.sectionHeading().copyWith(fontSize: 19.sp),
              ),
              SizedBox(height: 8.h),
              Text(
                "You'll go back and sign up again with the right address.",
                textAlign: TextAlign.center,
                style: AppText.paragraph().copyWith(fontSize: 15.sp),
              ),
              SizedBox(height: 24.h),
              // Stacked, not side by side: at the button's 24px horizontal
              // padding these labels don't fit two-up in a dialog and were
              // being ellipsed to "Keep ..." / "Sign u...".
              AppButton(
                label: 'Sign up again',
                onPressed: () => Navigator.pop(ctx, true),
              ),
              SizedBox(height: 10.h),
              AppButton(
                label: 'Keep waiting',
                kind: AppButtonKind.neutral,
                onPressed: () => Navigator.pop(ctx, false),
              ),
            ],
          ),
        ),
      ),
    );

    if (startOver != true) {
      // Resume polling — they're still waiting on the original address.
      if (mounted && !_navigated) {
        _timer = Timer.periodic(_pollInterval, (_) => _checkOnce());
      }
      return;
    }

    _navigated = true;
    await Tokenstorage.clearOnboarding();
    if (!mounted) return;
    context.go(Approutes.register);
  }
}

/// The inbox illustration on a lifted white card — the focal point of both
/// verification states.
class _MailCard extends StatelessWidget {
  const _MailCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 216.w,
      height: 216.w,
      alignment: Alignment.center,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Consonants.surface,
        borderRadius: BorderRadius.circular(Consonants.rHero.r),
        boxShadow: Consonants.cardLift,
      ),
      child: Image.asset("assets/gmail.png", fit: BoxFit.contain),
    );
  }
}

class VerificationContainer extends ConsumerWidget {
  const VerificationContainer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      authControllerProvider.select((s) => s.isloading),
    );
    // Nothing on this screen is a primary action — the user finishes in their
    // inbox — so the resend sits as an outline button, no gradient.
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
          AppButton(
            label: isLoading ? 'Sending…' : 'Resend Code',
            kind: AppButtonKind.secondary,
            isLoading: isLoading,
            onPressed: () async {
              await ref
                  .read(authControllerProvider.notifier)
                  .resendVerification();
              if (!context.mounted) return;
              // Errors surface via the parent's ref.listen; only the
              // success path needs a confirmation here.
              if (ref.read(authControllerProvider).error == null) {
                ErrorHandler.success(
                  context,
                  "Verification email re-sent. Check your inbox.",
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Deep-link handler for the email-verification link. The user lands here
/// from the email; we hit the backend with the token, then show success.
class VerificationSucceed extends ConsumerStatefulWidget {
  final String? token;

  const VerificationSucceed({super.key, required this.token});

  @override
  ConsumerState<VerificationSucceed> createState() =>
      _VerificationSucceedState();
}

class _VerificationSucceedState extends ConsumerState<VerificationSucceed> {
  @override
  void initState() {
    super.initState();
    final token = widget.token;
    if (token != null && token.isNotEmpty) {
      Future.microtask(() {
        if (!mounted) return;
        ref.read(authControllerProvider.notifier).verifyEmail(token);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      return Scaffold(
        backgroundColor: Consonants.canvas,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
              child: Text(
                "Invalid or missing verification token.",
                textAlign: TextAlign.center,
                style: AppText.sectionHeading().copyWith(fontSize: 18.sp),
              ),
            ),
          ),
        ),
      );
    }

    final authState = ref.watch(authControllerProvider);

    return ResponsiveAuthScaffold(
      bodyPadding: EdgeInsets.symmetric(vertical: 28.h),
      body: [
        const _MailCard(),
        SizedBox(height: 32.h),
        if (authState.isloading) ...[
          SizedBox(
            width: 26.w,
            height: 26.w,
            child: const CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Consonants.violet,
            ),
          ),
          SizedBox(height: 18.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
            child: Text(
              "Verifying your email…",
              textAlign: TextAlign.center,
              style: AppText.paragraph().copyWith(fontSize: 15.5.sp),
            ),
          ),
        ] else if (authState.error != null) ...[
          Container(
            width: 56.w,
            height: 56.w,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Consonants.dangerWash,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 27.sp,
              color: Consonants.danger,
            ),
          ),
          SizedBox(height: 18.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
            child: Text(
              authState.error!,
              textAlign: TextAlign.center,
              style: AppText.sectionHeading().copyWith(fontSize: 18.sp),
            ),
          ),
        ] else ...[
          Container(
            width: 56.w,
            height: 56.w,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Consonants.indigoWash,
            ),
            child: Icon(
              Icons.check_rounded,
              size: 28.sp,
              color: Consonants.indigo,
            ),
          ),
          SizedBox(height: 18.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
            child: Text(
              "Your email was verified successfully.",
              textAlign: TextAlign.center,
              style: AppText.sectionHeading().copyWith(fontSize: 18.sp),
            ),
          ),
        ],
      ],
    );
  }
}
