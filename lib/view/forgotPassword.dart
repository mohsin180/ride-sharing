import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/model/authModels.dart';
import 'package:ride_sharing/provider/authProvider.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
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
      body: [
        CustomWidgets.customText(
          "Reset Your Password",
          20.sp,
          Consonants.boldTextColor,
          FontWeight.w700,
        ),
        SizedBox(height: 10.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: CustomWidgets.customText(
            "Please enter your email address to receive a link to create a new password via email",
            10.sp,
            Consonants.greyColor,
            FontWeight.w400,
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: 20.h),
        AuthFields(
          text: 'Email Address',
          suffixIcon: Icon(Icons.email_rounded, size: 10.sp),
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
            "Send Reset Link",
            onPressed,
            isLoading: isLoading,
          ),
          SizedBox(height: 10.h),
          GestureDetector(
            onTap: () => onResend?.call(),
            child: CustomWidgets.customText(
              'Resent Link',
              10.sp,
              Consonants.primaryColor,
              FontWeight.w700,
            ),
          ),
          SizedBox(height: 20.h),
          GestureDetector(
            onTap: () => Navigator.pop(context),
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
