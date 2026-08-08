import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/model/authModels.dart';
import 'package:ride_sharing/provider/authProvider.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/custom/appComponents.dart';
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
          bodyPadding: EdgeInsets.symmetric(vertical: 28.h),
          body: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56.w,
                      height: 56.w,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Consonants.indigoWash,
                      ),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 26.sp,
                        color: Consonants.indigo,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      "Create New Password",
                      style: AppText.displayXs().copyWith(fontSize: 33.sp),
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      "Use at least 8 characters.",
                      style: AppText.paragraph().copyWith(fontSize: 15.5.sp),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 32.h),
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
            SizedBox(height: Consonants.gapFields.h),
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
            label: "Update Password",
            onPressed: onPressed,
            isLoading: isLoading,
          ),
          SizedBox(height: Consonants.gapButtons.h),
          GestureDetector(
            onTap: () => context.go(Approutes.login),
            child: Text(
              'Back to Login',
              style: AppText.rowLabel(color: Consonants.textMuted)
                  .copyWith(fontSize: 14.5.sp, fontWeight: FontWeight.w400),
            ),
          ),
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
      backgroundColor: Consonants.canvas,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 26.w,
              height: 26.w,
              child: const CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Consonants.violet,
              ),
            ),
            SizedBox(height: 18.h),
            Text(
              message,
              style: AppText.paragraph().copyWith(fontSize: 15.sp),
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
      backgroundColor: Consonants.canvas,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64.w,
                  height: 64.w,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Consonants.dangerWash,
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: 30.sp,
                    color: Consonants.danger,
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppText.sectionHeading().copyWith(fontSize: 18.sp),
                ),
                if (showLogin) ...[
                  SizedBox(height: 28.h),
                  AppButton(
                    label: 'Back to Login',
                    kind: AppButtonKind.secondary,
                    expand: false,
                    onPressed: () => context.go(Approutes.login),
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
