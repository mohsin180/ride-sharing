import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/model/authModels.dart';
import 'package:ride_sharing/provider/authProvider.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/custom/appComponents.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';
import 'package:ride_sharing/widgets/custom/responsive.dart';

class Forgotpassword extends ConsumerStatefulWidget {
  const Forgotpassword({super.key});

  @override
  ConsumerState<Forgotpassword> createState() => _ForgotpasswordState();
}

class _ForgotpasswordState extends ConsumerState<Forgotpassword> {
  final emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final request = ForgotPassword(email: emailController.text.trim());
    try {
      await ref
          .read(authControllerProvider.notifier)
          .forgotpassword(request);
    } catch (_) {
      // Surfaced via state.error → ref.listen.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      // Only react to actual transitions — guards against stale state from
      // a previous flow (e.g. resetPassword setting isSuccess=true earlier).
      if (next.error != null && next.error != prev?.error) {
        ErrorHandler.show(context, next.error);
      } else if (next.isSuccess == true && prev?.isSuccess != true) {
        ErrorHandler.success(
          context,
          "Reset link sent. Check your email to continue.",
        );
      }
    });

    final authState = ref.watch(authControllerProvider);

    return ResponsiveAuthScaffold(
      formKey: _formKey,
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
                    Icons.lock_reset_outlined,
                    size: 27.sp,
                    color: Consonants.indigo,
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  "Reset Your Password",
                  style: AppText.displayXs().copyWith(fontSize: 33.sp),
                ),
              ],
            ),
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
              return 'Please enter your email address';
            }
            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
            if (!emailRegex.hasMatch(value.trim())) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
      ],
      bottomBar: ResetPassword(
        isLoading: authState.isloading,
        onPressed: authState.isloading ? null : _submit,
        onResend: authState.isloading ? null : _submit,
      ),
    );
  }
}

class ResetPassword extends StatelessWidget {
  final Future<void> Function()? onPressed;
  final Future<void> Function()? onResend;
  final bool isLoading;

  const ResetPassword({
    super.key,
    required this.onPressed,
    required this.onResend,
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
            label: "Send Reset Link",
            onPressed: onPressed,
            isLoading: isLoading,
          ),
          SizedBox(height: Consonants.gapButtons.h),
          GestureDetector(
            onTap: () => onResend?.call(),
            child: Text(
              'Resent Link',
              style: AppText.rowLabel(color: Consonants.indigo)
                  .copyWith(fontSize: 14.5.sp, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(height: 16.h),
          GestureDetector(
            onTap: () => Navigator.pop(context),
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
