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
import 'package:ride_sharing/widgets/custom/customWidgets.dart';
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

    return ResponsiveAuthScaffold(
      body: [
        CustomWidgets.customText(
          'Verify Your Email',
          17.sp,
          Colors.black,
          FontWeight.bold,
        ),
        SizedBox(height: 5.h),
        CustomWidgets.customText(
          'Click the link sent to',
          10.sp,
          Consonants.greyColor,
          FontWeight.normal,
        ),
        SizedBox(height: 2.h),
        CustomWidgets.customText(
          email ?? 'your email',
          10.sp,
          Consonants.boldTextColor,
          FontWeight.bold,
          maxLines: 1,
        ),
        SizedBox(height: 30.h),
        Card(
          color: Consonants.whiteColor,
          elevation: 10,
          shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Image.asset(
            "assets/gmail.png",
            fit: BoxFit.contain,
            height: 200.h,
            width: 200.w,
          ),
        ),
        SizedBox(height: 16.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 12.w,
              height: 12.w,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Consonants.primaryColor,
              ),
            ),
            SizedBox(width: 8.w),
            CustomWidgets.customText(
              'Waiting for verification…',
              10.sp,
              Consonants.greyColor,
              FontWeight.w500,
            ),
          ],
        ),
      ],
      bottomBar: const VerificationContainer(),
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: 40.h),
          GestureDetector(
            onTap: isLoading
                ? null
                : () async {
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
            child: CustomWidgets.customText(
              isLoading ? 'Sending…' : 'Resend Code',
              10.sp,
              Consonants.primaryColor,
              FontWeight.w600,
            ),
          ),
          SizedBox(height: 20.h),
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
        backgroundColor: Consonants.scaffoldBackgroundColor,
        body: SafeArea(
          child: Center(
            child: CustomWidgets.customText(
              "Invalid or missing verification token.",
              14.sp,
              Consonants.boldTextColor,
              FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final authState = ref.watch(authControllerProvider);

    return ResponsiveAuthScaffold(
      body: [
        Card(
          color: Consonants.whiteColor,
          elevation: 10,
          shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Image.asset(
            "assets/gmail.png",
            fit: BoxFit.contain,
            height: 200.h,
            width: 200.w,
          ),
        ),
        SizedBox(height: 10.h),
        if (authState.isloading) ...[
          CircularProgressIndicator(color: Consonants.primaryColor),
          SizedBox(height: 12.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: CustomWidgets.customText(
              "Verifying your email…",
              12.sp,
              Consonants.greyColor,
              FontWeight.w500,
              textAlign: TextAlign.center,
            ),
          ),
        ] else if (authState.error != null) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: CustomWidgets.customText(
              authState.error!,
              12.sp,
              Consonants.boldTextColor,
              FontWeight.w600,
              textAlign: TextAlign.center,
            ),
          ),
        ] else ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: CustomWidgets.customText(
              "Your email was verified successfully.",
              12.sp,
              Consonants.boldTextColor,
              FontWeight.w600,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }
}
