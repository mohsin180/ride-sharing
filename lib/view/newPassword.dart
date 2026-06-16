import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/model/authModels.dart';
import 'package:ride_sharing/provider/authProvider.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';
import 'package:ride_sharing/widgets/custom/responsive.dart';

class Newpassword extends ConsumerStatefulWidget {
  final String? token;
  const Newpassword(this.token, {super.key});

  @override
  ConsumerState<Newpassword> createState() => _NewpasswordState();
}

class _NewpasswordState extends ConsumerState<Newpassword> {
  final formKey = GlobalKey<FormState>();
  final newpassword = TextEditingController();
  final confirmPassword = TextEditingController();

  @override
  void dispose() {
    newpassword.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!formKey.currentState!.validate()) return;

    final request = ResetPasswordDto(
      token: widget.token!,
      newPassword: newpassword.text.trim(),
    );

    try {
      await ref.read(authControllerProvider.notifier).resetPassword(request);
    } catch (_) {
      // Surfaced via state.error → ref.listen.
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      return _MessageScaffold(
        message: "Invalid or missing reset token.",
        showLogin: true,
      );
    }

    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ErrorHandler.show(context, next.error);
      } else if (next.isSuccess == true && prev?.isSuccess != true) {
        ErrorHandler.success(
          context,
          "Password updated. You can now log in.",
        );
        context.go(Approutes.login);
      }
    });

    final tokenStatus = ref.watch(resetTokenStatusProvider(token));
    final authState = ref.watch(authControllerProvider);

    return tokenStatus.when(
      loading: () => const _LoadingScaffold(message: "Verifying reset link…"),
      error: (e, _) => _MessageScaffold(
        message: ErrorHandler.message(e),
        showLogin: true,
      ),
      data: (isValid) {
        if (!isValid) {
          return _MessageScaffold(
            message:
                "This reset link has expired or is no longer valid. Please request a new one.",
            showLogin: true,
          );
        }
        return ResponsiveAuthScaffold(
          formKey: formKey,
          body: [
            CustomWidgets.customText(
              "Create New Password",
              20.sp,
              Consonants.boldTextColor,
              FontWeight.w700,
            ),
            SizedBox(height: 10.h),
            PasswordField(
              text: "New Password",
              controller: newpassword,
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
            SizedBox(height: 10.h),
            PasswordField(
              text: "Confirm Password",
              controller: confirmPassword,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                if (value != newpassword.text) {
                  return "Passwords do not match";
                }
                return null;
              },
            ),
          ],
          bottomBar: UpdatePassword(
            isLoading: authState.isloading,
            onPressed: authState.isloading ? null : _submit,
          ),
        );
      },
    );
  }
}

class UpdatePassword extends StatelessWidget {
  final Future<void> Function()? onPressed;
  final bool isLoading;

  const UpdatePassword({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
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
          SizedBox(height: 20.h),
          CustomWidgets.customButton(
            "Update Password",
            onPressed,
            isLoading: isLoading,
          ),
          SizedBox(height: 20.h),
          GestureDetector(
            onTap: () => context.go(Approutes.login),
            child: CustomWidgets.customText(
              'Back to Login',
              10.sp,
              Consonants.greyColor,
              FontWeight.w400,
            ),
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  final String message;
  const _LoadingScaffold({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Consonants.primaryColor),
            SizedBox(height: 16.h),
            CustomWidgets.customText(
              message,
              12.sp,
              Consonants.greyColor,
              FontWeight.w500,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageScaffold extends StatelessWidget {
  final String message;
  final bool showLogin;
  const _MessageScaffold({required this.message, this.showLogin = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 48.sp,
                  color: Consonants.primaryColor,
                ),
                SizedBox(height: 16.h),
                CustomWidgets.customText(
                  message,
                  14.sp,
                  Consonants.boldTextColor,
                  FontWeight.w600,
                  textAlign: TextAlign.center,
                ),
                if (showLogin) ...[
                  SizedBox(height: 24.h),
                  GestureDetector(
                    onTap: () => context.go(Approutes.login),
                    child: CustomWidgets.customText(
                      'Back to Login',
                      12.sp,
                      Consonants.primaryColor,
                      FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
