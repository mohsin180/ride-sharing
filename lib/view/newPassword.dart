import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/model/authModels.dart';
import 'package:ride_sharing/provider/authProvider.dart';
import 'package:ride_sharing/view/loginScreen.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

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
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(CustomWidgets.customErrorSnackBar(next.error!));
      }
    });
    if (widget.token == null || widget.token!.isEmpty) {
      return Scaffold(
        body: Center(
          child: CustomWidgets.customText(
            "Invalid or Missing reset Token",
            14.sp,
            Colors.black,
            FontWeight.bold,
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomWidgets.customText(
                    "Create New Password",
                    20.sp,
                    Consonants.boldTextColor,
                    FontWeight.w700,
                  ),
                  SizedBox(height: 10.h),
                  AuthFields(
                    text: "New Password",
                    obscure: true,
                    suffixIcon: Icon(Icons.remove_red_eye_rounded, size: 10.sp),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 8) {
                        return 'Password must be at least 8 characters long';
                      }
                      return null;
                    },
                    controller: newpassword,
                  ),
                  SizedBox(height: 10.h),
                  AuthFields(
                    text: "Confirm Password",
                    obscure: true,
                    suffixIcon: Icon(Icons.remove_red_eye_rounded, size: 10.sp),
                    validator: (value) {
                      if (value != newpassword.text) {
                        return "Password doesnot matched";
                      }
                      return null;
                    },
                    controller: confirmPassword,
                  ),
                ],
              ),
            ),
          ),
          UpdatePassword(
            onPressed: authState.isloading
                ? null
                : () async {
                    final request = ResetPasswordDto(
                      token: widget.token!,
                      newPassword: newpassword.text.trim(),
                    );
                    if (formKey.currentState!.validate()) {
                      await ref
                          .read(authControllerProvider.notifier)
                          .resetPassword(request);
                    }
                  },
          ),
        ],
      ),
    );
  }
}

class UpdatePassword extends StatelessWidget {
  final Future<void> Function()? onPressed;
  const UpdatePassword({super.key, required this.onPressed});

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
          CustomWidgets.customButton("Update Password", onPressed),

          SizedBox(height: 20.h),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: ((context) => Loginscreen())),
            ),
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
