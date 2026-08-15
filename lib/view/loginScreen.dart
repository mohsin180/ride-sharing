import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/model/authModels.dart';
import 'package:ride_sharing/provider/authProvider.dart';
import 'package:ride_sharing/provider/sessionReset.dart';
import 'package:ride_sharing/provider/sessionRouter.dart';
import 'package:ride_sharing/view/forgotPassword.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/custom/appComponents.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';
import 'package:ride_sharing/widgets/custom/responsive.dart';

class Loginscreen extends ConsumerStatefulWidget {
  const Loginscreen({super.key});

  @override
  ConsumerState<Loginscreen> createState() => _LoginscreenState();
}

class _LoginscreenState extends ConsumerState<Loginscreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  /// True while we're doing the post-login profile check + routing.
  /// Drives the button's loading state so the user gets visible
  /// feedback during the (sometimes >1s) check, and prevents the
  /// listener from firing `_routeAfterLogin` twice if Riverpod
  /// re-emits the same logged-in state.
  bool _isRouting = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_isRouting) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final request = LoginRequest(
      email: emailController.text.trim(),
      password: passwordController.text,
    );

    try {
      await ref.read(authControllerProvider.notifier).loginProvider(request);
      // Success snackbar + navigation handled by ref.listen below.
    } catch (_) {
      // Error already pushed onto AuthState; ref.listen surfaces it.
    }
  }

  /// Post-login routing, which is now a single fact rather than a series of
  /// lookups: a session token exists only for accounts that finished signup,
  /// because the backend issues one at the instant identity verification
  /// passes and creates the account in that same moment.
  ///
  /// So there is nothing to check here. The previous version asked whether a
  /// profile existed and, finding one, went straight to the navbar — which is
  /// exactly how users with an unverified identity reached the home screen.
  /// Unfinished signups no longer arrive here at all: they have no session,
  /// and are routed by stage in the listener below.
  Future<void> _routeAfterLogin(String? role) async {
    if (_isRouting) return; // listener might fire twice — de-dupe.
    setState(() => _isRouting = true);

    try {
      // Wipe any cached user-scoped providers left over from a previous
      // session before doing anything else. Without this, a logout that
      // skipped the standard flow (force-quit, crash, etc.) could let
      // stale profile/ride data bleed into the new user's session.
      clearUserSession(ref);

      // Sync the JWT role into the bottom-navbar's selector so it renders the
      // right tab set.
      if (role == "DRIVER" || role == "PASSENGER") {
        ref.read(selectedRoleProvider.notifier).setRole(role!);
      }

      if (!mounted) return;
      context.go(Approutes.bottomNavbar);
    } catch (e) {
      // Anything unexpected — surface it instead of silently stalling.
      if (!mounted) return;
      ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _isRouting = false);
    }
  }

  /// Full-width block on the screen's gutter — the centred column inside
  /// [ResponsiveAuthScaffold] would otherwise shrink-wrap its children.
  Widget _gutter({required Widget child}) => Padding(
        padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
        child: SizedBox(width: double.infinity, child: child),
      );

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ErrorHandler.show(context, next.error);
      } else if (next.onboardingStage != OnboardingStage.complete &&
          next.onboardingStage != previous?.onboardingStage) {
        // Right password, unfinished signup: reopen the step the server says
        // they stopped at, rather than showing an error they can do nothing
        // about. There is no account yet, so there is nothing to log in to.
        ErrorHandler.success(context, "Almost there — let's finish signing up");
        context.go(routeForStage(ref, next.onboardingStage, next.role));
      } else if (next.isLoggedIn && previous?.isLoggedIn != true) {
        ErrorHandler.success(context, "Logged in successfully");
        _routeAfterLogin(next.role);
      }
    });

    final authState = ref.watch(authControllerProvider);

    return ResponsiveAuthScaffold(
      formKey: _formKey,
      bodyPadding: EdgeInsets.symmetric(vertical: 28.h),
      body: [
        // Sign-in is an identity moment, so the headline carries Fraunces and
        // sits left with the brand mark; the gradient is spent on the CTA.
        _gutter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // One line: at 33sp the headline wrapped and dropped "Account"
              // onto its own row. FittedBox scales it down only as far as the
              // width demands, so it still fills the measure on wider screens.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Login to Your Account',
                  maxLines: 1,
                  softWrap: false,
                  style: AppText.displayXs().copyWith(fontSize: 33.sp),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 32.h),
        AuthFields(
          text: 'Email Address',
          suffixIcon: Icon(
            Icons.mail_outline_rounded,
            size: 20.sp,
            color: Consonants.iconInk,
          ),
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your email';
            }
            final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
            if (!emailRegex.hasMatch(value.trim())) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
        SizedBox(height: Consonants.gapFields.h),
        PasswordField(
          text: 'Password',
          controller: passwordController,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your password';
            }
            if (value.length < 8) {
              return 'Password must be at least 8 characters long';
            }
            return null;
          },
        ),
        SizedBox(height: 14.h),
        _gutter(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Forgotpassword()),
                ),
                child: Text(
                  'Forgot Password?',
                  style: AppText.rowLabel(color: Consonants.indigo)
                      .copyWith(fontSize: 14.5.sp, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
      // The primary action lives at the bottom of the screen, on the canvas —
      // no opaque bar between it and the form.
      bottomBar: Padding(
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
              label: "Login",
              // Loading covers both the auth HTTP and the post-login profile
              // check so the spinner doesn't briefly disappear in between.
              isLoading: authState.isloading || _isRouting,
              onPressed: _handleLogin,
            ),
            SizedBox(height: Consonants.gapButtons.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Dont have an account?',
                  style: AppText.rowLabel(color: Consonants.textMuted)
                      .copyWith(fontSize: 14.5.sp, fontWeight: FontWeight.w400),
                ),
                SizedBox(width: 6.w),
                GestureDetector(
                  onTap: () => context.go(Approutes.register),
                  child: Text(
                    'Sign Up',
                    style: AppText.rowLabel(color: Consonants.indigo).copyWith(
                      fontSize: 14.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
