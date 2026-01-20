import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/view/newPassword.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

class Forgotpassword extends StatelessWidget {
  const Forgotpassword({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: Column(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomWidgets.customText(
                  "Reset Your Password",
                  20.sp,
                  Consonants.boldTextColor,
                  FontWeight.w700,
                ),
                SizedBox(height: 10.h),
                CustomWidgets.customText(
                  "Please enter your email address to receive a\nlink to create a new password via email",
                  10.sp,
                  Consonants.greyColor,
                  FontWeight.w400,
                ),
                SizedBox(height: 20.h),
                AuthFields(
                  text: 'Email Address',
                  suffixIcon: Icon(Icons.email_rounded, size: 10.sp),
                ),
              ],
            ),
          ),
          ResetPassword(onPressed: () {}),
        ],
      ),
    );
  }
}

class ResetPassword extends StatelessWidget {
  final VoidCallback onPressed;
  const ResetPassword({super.key, required this.onPressed});

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
          CustomWidgets.customButton("Send Reset Link", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: ((context) => Newpassword())),
            );
          }),
          SizedBox(height: 10.h),
          GestureDetector(
            onTap: () {},
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
