import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/model/authModels.dart';
import 'package:ride_sharing/provider/authProvider.dart';
import 'package:ride_sharing/provider/profileProvider.dart';
import 'package:ride_sharing/provider/sessionReset.dart';
import 'package:ride_sharing/view/forgotPassword.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
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

  /// Three-way post-login routing. The user might have:
  ///   1. No role on their JWT     → finish role selection
  ///   2. Role, but no profile yet → finish profile creation
  ///   3. Role + profile           → enter the app
  ///
  /// We hit the profile endpoint instead of trusting just the JWT
  /// because the JWT only carries role/email/gender — a user can pick
  /// a role and then log out before saving their profile, which would
  /// otherwise drop them into a broken bottom-navbar with empty data.
  Future<void> _routeAfterLogin(String? role) async {
    if (_isRouting) return; // listener might fire twice — de-dupe.
    setState(() => _isRouting = true);

    try {
      // Wipe any cached user-scoped providers left over from a previous
      // session before doing anything else. Without this, a logout that
      // skipped the standard flow (force-quit, crash, etc.) could let
      // stale profile/ride data bleed into the new user's session.
      clearUserSession(ref);

      if (role != "DRIVER" && role != "PASSENGER") {
        // No role on the token — finish role selection first.
        if (!mounted) return;
        context.go(Approutes.roleSection);
        return;
      }

      // Sync the JWT role into the bottom-navbar's selector so when we
      // eventually route there, it renders the right tab set.
      ref.read(selectedRoleProvider.notifier).setRole(role!);

      // Cap the profile check at 8s so a slow backend can't strand the
      // user on the login screen. On timeout we fall through to the
      // navbar — downstream profile-dependent screens already handle
      // their own loading/empty/error states gracefully.
      bool hasProfile;
      try {
        hasProfile = await _hasProfileForRole(role)
            .timeout(const Duration(seconds: 8));
      } on TimeoutException {
        hasProfile = true; // assume yes; navbar will surface the issue
      }

      if (!mounted) return;
      if (hasProfile) {
        context.go(Approutes.bottomNavbar);
      } else if (role == "PASSENGER") {
        context.go(Approutes.passengerProfileData);
      } else {
        context.go(Approutes.driverProfileData);
      }
    } catch (e) {
      // Anything unexpected — surface it instead of silently stalling.
      if (!mounted) return;
      ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _isRouting = false);
    }
  }

  /// Returns true when the backend reports a populated profile for the
  /// authenticated user in the given role. Treats any exception (404,
  /// network blip, etc.) as "no profile" so a transient failure sends
  /// the user to the profile screen rather than the navbar with empty
  /// data — false-negative is the safer default here.
  Future<bool> _hasProfileForRole(String role) async {
    try {
      if (role == "PASSENGER") {
        final p = await ref.read(passengerProfileProvider.future);
        return p.fullName.trim().isNotEmpty;
      } else {
        final p = await ref.read(driverProfileProvider.future);
        return p.fullName.trim().isNotEmpty;
      }
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ErrorHandler.show(context, next.error);
      } else if (next.isLoggedIn && previous?.isLoggedIn != true) {
        ErrorHandler.success(context, "Logged in successfully");
        _routeAfterLogin(next.role);
      }
    });

    final authState = ref.watch(authControllerProvider);

    return ResponsiveAuthScaffold(
      formKey: _formKey,
      body: [
        CustomWidgets.customText(
          'Login to Your Account',
          20.sp,
          Consonants.boldTextColor,
          FontWeight.bold,
        ),
        SizedBox(height: 20.h),
        AuthFields(
          text: 'Email Address',
          suffixIcon: Icon(Icons.email_rounded),
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
        SizedBox(height: 20.h),
        AuthFields(
          text: 'Password',
          obscure: true,
          suffixIcon: Icon(Icons.remove_red_eye),
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
        SizedBox(height: 5.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 33.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Forgotpassword()),
                ),
                child: CustomWidgets.customText(
                  'Forgot Password?',
                  9.sp,
                  Consonants.primaryColor,
                  FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
      bottomBar: AuthContainer(
        buttonText: "Login",
        accountText: 'Dont have an account?',
        actionText: 'Sign Up',
        // Loading covers both the auth HTTP and the post-login profile
        // check so the spinner doesn't briefly disappear in between.
        isLoading: authState.isloading || _isRouting,
        onPressed: _handleLogin,
        onTap: () => context.go(Approutes.register),
      ),
    );
  }
}
